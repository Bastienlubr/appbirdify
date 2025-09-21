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
    missionId: m.get('missionId') || m.get('mission') || '',
    csv: m.get('csv') || '',
    collection: m.get('collection') || 'missions',
    apply: Boolean(m.get('apply')),
    verbose: Boolean(m.get('verbose')),
  };
}

function normalizeHeader(h) {
  return h.toString().trim().toLowerCase()
    .replace(/é|è|ê|ë/g, 'e').replace(/à|â/g, 'a').replace(/î|ï/g, 'i')
    .replace(/ô|ö/g, 'o').replace(/ù|û|ü/g, 'u').replace(/[’‘]/g, "'")
    .replace(/\s+/g, '_');
}

function norm(s) {
  return (s || '')
    .toString()
    .replace(/œ/gi, 'oe').replace(/æ/gi, 'ae')
    .normalize('NFD').replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[’‘`']/g, ' ')
    .replace(/[-]/g, ' ')
    .replace(/[^a-z\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

async function initFirestore() {
  const keyPath = path.resolve('serviceAccountKey.json');
  const content = await fs.readFile(keyPath, 'utf8');
  const creds = JSON.parse(content);
  if (!admin.apps?.length) admin.initializeApp({ credential: admin.credential.cert(creds) });
  return admin.firestore();
}

async function readCsvFlexible(csvPath) {
  const content = await fs.readFile(csvPath, 'utf8');
  try {
    return csvParse(content, { columns: true, skip_empty_lines: true, trim: true });
  } catch (_) {
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').filter(l => l.trim().length > 0);
    const headers = lines[0].split(',').map(normalizeHeader);
    const rows = [];
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(',');
      const row = {}; for (let j = 0; j < headers.length && j < cols.length; j++) row[headers[j]] = cols[j].trim();
      rows.push(row);
    }
    return rows;
  }
}

async function buildBankIndex() {
  const bankCsvPath = path.resolve('assets', 'data', 'Bank son oiseauxV4.csv');
  const content = await fs.readFile(bankCsvPath, 'utf8');
  const rows = csvParse(content, { columns: true, skip_empty_lines: true, trim: true });
  const indexById = new Map();
  const indexByName = new Map();
  for (const r of rows) {
    const id = (r.id_oiseaux || r.id || r.ID || '').toString().trim();
    let imageUrl = '';
    let audioUrl = '';
    for (const [k, vRaw] of Object.entries(r)) {
      const v = (vRaw || '').toString().trim();
      if (!v.startsWith('http')) continue;
      const lower = v.toLowerCase();
      if (!imageUrl && (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.includes('/photo%20'))) imageUrl = v;
      if (!audioUrl && (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.includes('/birds%2f'))) audioUrl = v;
    }
    const frName = (r['Nom_français'] || r['Nom francais'] || r['nom_francais'] || '').toString().trim();
    if (id) indexById.set(id, { urlImage: imageUrl, urlAudio: audioUrl, nomFrancais: frName });
    if (frName) indexByName.set(norm(frName), { urlImage: imageUrl, urlAudio: audioUrl, nomFrancais: frName });
  }
  return { indexById, indexByName };
}

async function extractPoolFromMissionCsv(csvPath, { indexById, indexByName }, { verbose }) {
  const records = await readCsvFlexible(csvPath);
  if (!records.length) return null;
  const rawHeaders = Object.keys(records[0]);
  const headers = rawHeaders.map(normalizeHeader);
  const headerMap = new Map(rawHeaders.map(h => [normalizeHeader(h), h]));

  const bonnesDetails = [];
  const mauvaisesSet = new Set();

  for (const r of records) {
    const numQ = (headerMap.has('num_question') ? r[headerMap.get('num_question')] : '').toString().trim();
    const good = (headerMap.has('bonne_reponse') ? r[headerMap.get('bonne_reponse')] : '').toString().trim();
    const bad = (headerMap.has('mauvaise_reponse') ? r[headerMap.get('mauvaise_reponse')] : '').toString().trim();
    const id = (headerMap.has('id_oiseaux') ? r[headerMap.get('id_oiseaux')] : '').toString().trim();
    const urlAudioCsv = (headerMap.has('url_bonne_reponse') ? r[headerMap.get('url_bonne_reponse')] : '').toString().trim();

    if (numQ && good) {
      let urlImage = '';
      let urlAudio = urlAudioCsv;
      if (id && indexById.has(id)) {
        const b = indexById.get(id);
        urlAudio = urlAudio || b.urlAudio || '';
        urlImage = b.urlImage || '';
      } else if (good) {
        const b = indexByName.get(norm(good));
        if (b) {
          urlAudio = urlAudio || b.urlAudio || '';
          urlImage = b.urlImage || '';
        }
      }
      bonnesDetails.push({ id, nomFrancais: good, urlAudio, urlImage });
    } else if (!numQ && bad) {
      mauvaisesSet.add(bad);
    }
  }

  // Filtrer mauvaises qui sont dans bonnes
  const goodNames = new Set(bonnesDetails.map(b => b.nomFrancais));
  const mauvaises = Array.from(mauvaisesSet).filter(n => !goodNames.has(n));

  if (verbose) {
    console.log(`[POOL] bonnes=${bonnesDetails.length} mauvaises=${mauvaises.length}`);
  }
  return { bonnesDetails, mauvaises };
}

async function main() {
  const { missionId, csv, collection, apply, verbose } = parseArgs();
  if (!missionId && !csv) {
    console.error('⚠️ Fournir --missionId=L01 ou --csv=assets/Missionhome/questionMission/L01.csv');
    process.exit(1);
  }
  const csvPath = csv
    ? (path.isAbsolute(csv) ? csv : path.resolve('assets', 'Missionhome', 'questionMission', csv))
    : path.resolve('assets', 'Missionhome', 'questionMission', `${missionId}.csv`);

  const exists = await fs.access(csvPath).then(() => true).catch(() => false);
  if (!exists) {
    console.error('❌ CSV introuvable:', csvPath);
    process.exit(1);
  }

  const { indexById, indexByName } = await buildBankIndex();
  const pool = await extractPoolFromMissionCsv(csvPath, { indexById, indexByName }, { verbose });
  if (!pool) {
    console.error('❌ Impossible d\'extraire le pool');
    process.exit(1);
  }

  const id = missionId || path.basename(csvPath, '.csv');
  const doc = {
    id,
    type: 'mission',
    source: 'mission_csv',
    updatedAt: new Date().toISOString(),
    pool,
  };

  if (!apply) {
    console.log('[DRY] Document à écrire dans Firestore:');
    console.log(JSON.stringify({ collection, id, doc }, null, 2));
    return;
  }

  const db = await initFirestore();
  const ref = db.collection(collection).doc(id);
  await ref.set(doc, { merge: true });
  console.log(`[APPLY] Mission publiée: ${collection}/${id}`);
  console.log(`  bonnesDetails=${doc.pool.bonnesDetails.length} | mauvaises=${doc.pool.mauvaises.length}`);
}

main().catch(e => { console.error(e); process.exit(1); });
