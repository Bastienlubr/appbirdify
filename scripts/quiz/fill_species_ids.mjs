#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import { parse } from 'csv-parse';
import admin from 'firebase-admin';

function parseArgs() {
  const m = new Map(process.argv.slice(2).map(a => {
    const [k, v] = a.split('=');
    const cleanKey = k.replace(/^--/, '');
    let cleanVal = v ?? true;
    if (typeof cleanVal === 'string') {
      cleanVal = cleanVal.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
    }
    return [cleanKey, cleanVal];
  }));
  return {
    apply: Boolean(m.get('apply')),
    limit: m.get('limit') ? Number(m.get('limit')) : null,
    file: m.get('file') || null,
    verbose: Boolean(m.get('verbose')),
    overwrite: Boolean(m.get('overwrite')),
    verifyFirestore: Boolean(m.get('verify-firestore') || m.get('verifyFirestore')),
    firestoreCollection: m.get('fs-collection') || m.get('firestoreCollection') || 'oiseaux',
  };
}

async function readCsv(filePath, { columns = true, delimiter = ',' } = {}) {
  const content = await fs.readFile(filePath, 'utf8');
  return new Promise((resolve, reject) => {
    parse(content, { columns, delimiter, skip_empty_lines: true, trim: true }, (err, records) => {
      if (err) return reject(err);
      resolve(records);
    });
  });
}

async function writeCsv(filePath, rows, columnsOrder) {
  const header = columnsOrder.join(',');
  const lines = [header];
  for (const row of rows) {
    const line = columnsOrder.map(c => {
      const v = row[c] ?? '';
      const s = String(v);
      if (s.includes('"')) return '"' + s.replace(/"/g, '""') + '"';
      if (s.includes(',') || s.includes('\n')) return '"' + s + '"';
      return s;
    }).join(',');
    lines.push(line);
  }
  await fs.writeFile(filePath, lines.join('\n'), 'utf8');
}

function normalizeName(name) {
  let s = (name || '').toString();
  s = s.replace(/œ/gi, 'oe').replace(/æ/gi, 'ae');
  s = s.normalize('NFD').replace(/\p{Diacritic}/gu, '');
  s = s.toLowerCase();
  // Remplacer divers types d'apostrophes et de tirets par des espaces
  s = s
    .replace(/[\u2018\u2019\u02BC'`´]/g, ' ')
    .replace(/[\-\u2010\u2011\u2012\u2013\u2014]/g, ' ');
  s = s.replace(/[^a-z\s]/g, '');
  s = s.replace(/\s+/g, ' ').trim();
  return s;
}

const NAME_ALIASES = new Map([
  ['rougequeu noir', 'rougequeue noir'],
  ['rossignol philomel', 'rossignol philomele'],
  ['locustelle luscinoide', 'locustelle luscinioides'],
  ['hypolais polyglote', 'hypolais polyglotte'],
  ['fauvette a tete noire', 'fauvette a tete noire'],
  // Variantes courantes dans nos CSV
  ['engoulvent d europe', 'engoulevent d europe'],
  ['chouette effraie', 'effraie des clochers'],
  ['chouette cheveche', "cheveche d athena"],
  ['chevechette d europe', "chevechette d europe"],
  ['rousserolle verderolle', 'rousserolle verderolle'],
  ['torcol fourmilier', 'torcol fourmilier'],
  ['aigle royal', 'aigle royal'],
  ['gypaete barbu', 'gypaete barbu'],
  ['vautour fauve', 'vautour fauve'],
  ['vautour moine', 'vautour moine'],
  ['circaete jean le blanc', 'circaete jean le blanc'],
  ['tichodrome echelette', 'tichodrome echelette'],
  ['puffin des baleares', 'puffin des baleares'],
  ['oceanite tempete', 'oceanite tempete'],
]);

// Marqueur pour IDs introuvables
const MISSING_MARK = 'MANQUANT';

function levenshtein(a, b) {
  const la = a.length, lb = b.length;
  if (la === 0) return lb;
  if (lb === 0) return la;
  const dp = new Array(lb + 1);
  for (let j = 0; j <= lb; j++) dp[j] = j;
  for (let i = 1; i <= la; i++) {
    let prev = i - 1;
    dp[0] = i;
    for (let j = 1; j <= lb; j++) {
      const temp = dp[j];
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[j] = Math.min(dp[j] + 1, dp[j - 1] + 1, prev + cost);
      prev = temp;
    }
  }
  return dp[lb];
}

function findIdByName(rawName, index) {
  if (!rawName) return null;
  let key = normalizeName(rawName);
  const alias = NAME_ALIASES.get(key);
  if (alias) key = normalizeName(alias);
  const exact = index.get(key);
  if (exact) return exact;
  const keys = [...index.keys()];
  const subset = keys.filter(k => k.includes(key) || key.includes(k));
  const uniqueIds = new Set(subset.map(k => index.get(k)));
  if (uniqueIds.size === 1) return [...uniqueIds][0];
  let bestId = null; let bestDist = Infinity;
  for (const k of keys) {
    const d = levenshtein(key, k);
    const threshold = Math.max(1, Math.floor(Math.min(k.length, key.length) * 0.2));
    if (d <= threshold && d < bestDist) { bestDist = d; bestId = index.get(k); }
  }
  if (bestId != null && bestDist <= Math.max(1, Math.floor(key.length * 0.2))) return bestId;
  return null;
}

let firestore = null;
async function initFirestoreIfNeeded(verify) {
  if (!verify || firestore) return;
  try {
    const keyPath = path.resolve('serviceAccountKey.json');
    const keyContent = await fs.readFile(keyPath, 'utf8');
    const serviceAccount = JSON.parse(keyContent);
    if (!admin.apps?.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
    firestore = admin.firestore();
  } catch (e) {
    console.warn('[FIRESTORE] Impossible d\'initialiser Firestore, vérification désactivée:', e?.message || e);
    firestore = null;
  }
}

async function idExistsInFirestore(collectionName, id) {
  if (!firestore) return true; // si non initialisé, considérer comme existant pour ne pas bloquer
  try {
    const snap = await firestore.collection(collectionName).doc(String(id)).get();
    return snap.exists === true;
  } catch (e) {
    console.warn('[FIRESTORE] Erreur de vérification pour', id, e?.message || e);
    return true; // ne pas bloquer si erreur réseau
  }
}

async function buildSpeciesIndex(bankCsvPath) {
  const rows = await readCsv(bankCsvPath, { columns: true, delimiter: ',' });
  const index = new Map();
  for (const r of rows) {
    const id = r.id_oiseaux ?? r.id ?? r.ID;
    const fr = normalizeName(r.Nom_français ?? r.Nom_francais ?? r.nom_francais ?? '');
    const sc = normalizeName(r.Nom_scientifique ?? r.nom_scientifique ?? '');
    const en = normalizeName(r.Nom_anglais ?? r.nom_anglais ?? '');
    if (!id) continue;
    if (fr) index.set(fr, String(id));
    if (sc) index.set(sc, String(id));
    if (en) index.set(en, String(id));
  }
  return index;
}

function detectColumns(row) {
  const cols = Object.keys(row);
  const normToOriginal = new Map(cols.map(c => [normalizeName(c), c]));
  const good = normToOriginal.get('bonne reponse') ?? 'bonne_reponse';
  // Choisir l'ID de la bonne réponse uniquement
  const idBonne = normToOriginal.get('id bonne reponse')
    ?? normToOriginal.get('id bonne reponses');
  const idOiseaux = normToOriginal.get('id oiseaux')
    ?? normToOriginal.get('id oiseau');
  const goodId = idBonne ?? idOiseaux ?? 'id_oiseaux';
  // Détecter une éventuelle autre colonne d'ID (pour nettoyage uniquement, pas de propagation)
  let maybeOtherId = null;
  if (goodId === idBonne && idOiseaux) {
    maybeOtherId = idOiseaux;
  }
  return { good, goodId, maybeOtherId };
}

async function fillIdsForRow(row, cols, index, verbose, overwrite, verifyFirestore, firestoreCollection) {
  let changes = 0;
  if (row[cols.good]) {
    let id = findIdByName(row[cols.good], index);
    if (id && verifyFirestore) {
      const ok = await idExistsInFirestore(firestoreCollection, id);
      if (!ok) id = null;
    }
    const hasPreferred = row[cols.goodId] && String(row[cols.goodId]).trim() !== '';

    // 1) Si on a trouvé un id pour le nom, écrire dans la colonne préférée (et synchroniser l'autre si présente)
    if (id && (!hasPreferred || overwrite)) {
      row[cols.goodId] = id;
      changes++;
    } else if (!id) {
      // 2) Si toujours non résolu, marquer MANQUANT (sans écraser si overwrite=false et déjà présent)
      if (!id && (!hasPreferred || overwrite)) {
        row[cols.goodId] = MISSING_MARK;
        changes++;
      } else if (verbose) {
        console.warn('[UNRESOLVED]', row[cols.good]);
      }
    }
  }
  // Nettoyage: ne pas laisser 'MANQUANT' dans une éventuelle autre colonne d'ID si elle ne correspond pas à la bonne réponse
  if (cols.maybeOtherId && row[cols.maybeOtherId] === MISSING_MARK) {
    row[cols.maybeOtherId] = '';
    changes++;
  }
  return changes;
}

async function findQuizCsvFiles() {
  const quizDir = path.resolve('assets', 'Quiz');
  const entries = await fs.readdir(quizDir, { withFileTypes: true });
  return entries.filter(e => e.isFile() && e.name.toLowerCase().endsWith('.csv')).map(e => path.join(quizDir, e.name));
}

async function processFile(filePath, index, apply, verbose, overwrite, verifyFirestore, firestoreCollection) {
  const rows = await readCsv(filePath, { columns: true, delimiter: ',' });
  if (rows.length === 0) return { filePath, total: 0, filled: 0 };
  const cols = detectColumns(rows[0]);
  let filled = 0;
  for (const r of rows) filled += await fillIdsForRow(r, cols, index, verbose, overwrite, verifyFirestore, firestoreCollection);
  if (apply && filled > 0) {
    const columnsOrder = Object.keys(rows[0]);
    await writeCsv(filePath, rows, columnsOrder);
  }
  return { filePath, total: rows.length, filled };
}

async function main() {
  const { apply, limit, file, verbose, overwrite, verifyFirestore, firestoreCollection } = parseArgs();
  const bankCsvPath = path.resolve('assets', 'data', 'Bank son oiseauxV4.csv');
  await initFirestoreIfNeeded(verifyFirestore);
  const index = await buildSpeciesIndex(bankCsvPath);
  let targets;
  if (file) {
    let p = file;
    if (!path.isAbsolute(p)) {
      p = file.includes(path.sep) ? path.resolve(file) : path.resolve('assets', 'Quiz', file);
    }
    targets = [p];
  } else {
    const files = await findQuizCsvFiles();
    targets = limit ? files.slice(0, limit) : files;
  }
  const results = [];
  for (const f of targets) {
    const res = await processFile(f, index, apply, verbose, overwrite, verifyFirestore, firestoreCollection);
    results.push(res);
    console.log(`${apply ? '[APPLY]' : '[DRY]'} ${path.basename(f)}: filled=${res.filled} rows, total=${res.total}`);
  }
  const summary = {
    apply,
    files: results.length,
    totalRows: results.reduce((a, r) => a + r.total, 0),
    totalFilled: results.reduce((a, r) => a + r.filled, 0),
  };
  console.table(summary);
}

main().catch(err => { console.error(err); process.exit(1); });


