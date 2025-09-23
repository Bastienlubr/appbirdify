#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import admin from 'firebase-admin';
import { parse as csvParse } from 'csv-parse/sync';

function parseArgs() {
  const m = new Map(process.argv.slice(2).map(a => {
    const [k, v] = a.split('=');
    const key = k.replace(/^--/, '');
    let val = v ?? true;
    if (typeof val === 'string') val = val.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
    return [key, val];
  }));
  return {
    apply: Boolean(m.get('apply')),
    imageBaseUrl: m.get('imageBaseUrl') || '',
    defaultDescription: m.get('description') || '',
    collection: m.get('collection') || 'missions',
    statut: m.get('statut') || 'approuvee',
    buildPool: Boolean(m.get('build-pool') || m.get('buildPool')),
  };
}

function slugify(name) {
  return name
    .toString()
    .normalize('NFD').replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[\u2018\u2019\u02BC'`´]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

async function listQuizCsv() {
  const dir = path.resolve('assets', 'Quiz');
  const entries = await fs.readdir(dir, { withFileTypes: true });
  return entries.filter(e => e.isFile() && e.name.toLowerCase().endsWith('.csv')).map(e => path.join(dir, e.name));
}

async function buildBankIndex() {
  const bankCsvPath = path.resolve('assets', 'data', 'Bank son oiseauxV4.csv');
  const content = await fs.readFile(bankCsvPath, 'utf8');
  const rows = csvParse(content, { columns: true, skip_empty_lines: true, trim: true });
  const indexById = new Map();
  const indexByName = new Map();
  for (const r of rows) {
    const entries = Object.entries(r);
    const id = (r.id_oiseaux || r.id || r.ID || '').toString().trim();
    let imageUrl = '';
    let audioUrl = '';
    for (const [k, vRaw] of entries) {
      const v = (vRaw || '').toString().trim();
      if (!v.startsWith('http')) continue;
      const lower = v.toLowerCase();
      if (!imageUrl && (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.includes('/photo%20'))) imageUrl = v;
      if (!audioUrl && (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.includes('/birds%2f'))) audioUrl = v;
    }
    const frName = (r['Nom_français'] || r['Nom francais'] || r['nom_francais'] || '').toString().trim();
    if (id) indexById.set(id, { urlImage: imageUrl, urlAudio: audioUrl, nomFrancais: frName });
    if (frName) indexByName.set(frName.toLowerCase(), { urlImage: imageUrl, urlAudio: audioUrl });
  }
  return { indexById, indexByName };
}

async function initFirestore() {
  const keyPath = path.resolve('serviceAccountKey.json');
  const content = await fs.readFile(keyPath, 'utf8');
  const creds = JSON.parse(content);
  if (!admin.apps?.length) admin.initializeApp({ credential: admin.credential.cert(creds) });
  return admin.firestore();
}

function buildDocFromCsvPath(csvPath, { imageBaseUrl, defaultDescription, statut }) {
  const base = path.basename(csvPath);
  const name = base.replace(/\.csv$/i, '');
  const id = slugify(name);
  const imageUrl = imageBaseUrl ? `${imageBaseUrl}/${encodeURIComponent(id)}.jpg` : '';
  return {
    id,
    name,
    description: defaultDescription,
    imageUrl,
    type: 'quiz',
    source: 'quiz_csv',
    statut,
    csvPath: path.relative(process.cwd(), csvPath).replace(/\\/g, '/'),
    updatedAt: new Date().toISOString(),
  };
}

function normalizeHeader(h) {
  return h.toString().trim().toLowerCase()
    .replace(/é|è|ê|ë/g, 'e').replace(/à|â/g, 'a').replace(/î|ï/g, 'i')
    .replace(/ô|ö/g, 'o').replace(/ù|û|ü/g, 'u').replace(/[’‘]/g, "'")
    .replace(/\s+/g, '_');
}

async function buildPoolFromCsv(csvPath, bank) {
  const content = await fs.readFile(csvPath, 'utf8');
  let records = [];
  try {
    records = csvParse(content, { columns: true, skip_empty_lines: true, trim: true });
  } catch (_) {
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').filter(l => l.trim().length > 0);
    const headers = lines[0].split(',').map(normalizeHeader);
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(',');
      const row = {}; for (let j = 0; j < headers.length && j < cols.length; j++) row[headers[j]] = cols[j].trim();
      records.push(row);
    }
  }
  if (!records.length) return null;
  const headers = Object.keys(records[0]).map(normalizeHeader);
  const findCol = (candidates) => {
    for (const h of headers) {
      if (candidates.includes(h)) return h;
    }
    return null;
  };
  const colGood = findCol(['bonne_reponse']);
  const colGoodId = findCol(['id_bonne_reponse', 'id_bonne_reponses']);
  const colAudio = findCol(['url_bonne_reponse', 'url_bonne_reponses', 'audio', 'url_audio']);
  const colWrong = findCol(['mauvaise_reponse', 'mauvaise_reponses']);
  if (!colGood) return null;

  const bonnesMap = new Map();
  for (const r of records) {
    const nom = (r[colGood] || '').toString().trim();
    if (!nom) continue;
    if (!bonnesMap.has(nom)) {
      const id = (r[colGoodId] || '').toString().trim();
      let urlAudio = (r[colAudio] || '').toString().trim();
      let urlImage = '';
      if (bank) {
        if (id && bank.indexById.has(id)) {
          const b = bank.indexById.get(id);
          urlAudio = urlAudio || b.urlAudio || '';
          urlImage = b.urlImage || '';
        } else {
          const b = bank.indexByName.get(nom.toLowerCase());
          if (b) {
            urlAudio = urlAudio || b.urlAudio || '';
            urlImage = b.urlImage || '';
          }
        }
      }
      bonnesMap.set(nom, { id, nomFrancais: nom, urlAudio, urlImage });
    }
  }
  const mauvaisesSet = new Set();
  if (colWrong) {
    for (const r of records) {
      const nom = (r[colWrong] || '').toString().trim();
      if (nom) mauvaisesSet.add(nom);
    }
  }
  return {
    bonnesDetails: Array.from(bonnesMap.values()),
    mauvaises: Array.from(mauvaisesSet.values()),
  };
}

async function main() {
  const { apply, imageBaseUrl, defaultDescription, collection, statut, buildPool } = parseArgs();
  const bank = await buildBankIndex();
  const files = await listQuizCsv();
  const docs = [];
  for (const f of files) {
    const baseDoc = buildDocFromCsvPath(f, { imageBaseUrl, defaultDescription, statut });
    if (buildPool) {
      const pool = await buildPoolFromCsv(f, bank);
      if (pool) baseDoc.pool = pool;
    }
    docs.push(baseDoc);
  }
  console.table(docs.map(d => ({ id: d.id, name: d.name, csvPath: d.csvPath })));
  if (!apply) {
    console.log('[DRY] Aucune écriture Firestore (utilisez --apply pour appliquer)');
    return;
  }
  const db = await initFirestore();
  const batch = db.batch();
  for (const d of docs) {
    const ref = db.collection(collection).doc(d.id);
    batch.set(ref, d, { merge: true });
  }
  await batch.commit();
  console.log(`[APPLY] ${docs.length} documents écrits dans '${collection}'.`);
}

main().catch(e => { console.error(e); process.exit(1); });


