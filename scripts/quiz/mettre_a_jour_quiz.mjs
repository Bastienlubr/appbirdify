#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
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
    quiz: m.get('quiz') || '',
    bonnes: m.get('bonnes') || '',
    bonnesFile: m.get('bonnes-file') || m.get('bonnesFile') || '',
    poolPlus: m.get('poolPlus') ? Number(m.get('poolPlus')) : 15,
    apply: Boolean(m.get('apply')),
    verbose: Boolean(m.get('verbose')),
  };
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

function normalizeHeader(h) {
  return h.toString().trim().toLowerCase()
    .replace(/é|è|ê|ë/g, 'e').replace(/à|â/g, 'a').replace(/î|ï/g, 'i')
    .replace(/ô|ö/g, 'o').replace(/ù|û|ü/g, 'u').replace(/[’‘]/g, "'")
    .replace(/\s+/g, '_');
}

function splitSpeciesList(raw) {
  if (!raw) return [];
  // Supporte séparateurs: '\n', '/', ',', ';', '|'
  const tokens = raw
    .toString()
    .replace(/\r\n/g, '\n')
    .split(/\n|\/|,|;|\|/g)
    .map(s => s.trim())
    .filter(Boolean);
  // Déduplique en respectant la casse d'origine mais avec clé normalisée
  const seen = new Set();
  const out = [];
  for (const t of tokens) {
    const key = norm(t);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(t);
  }
  return out;
}

function firstToken(frName) {
  const t = norm(frName).split(' ');
  return t[0] || '';
}

function scoreCandidate(target, cand) {
  let sc = 0;
  if (cand.genus && target.genus && cand.genus === target.genus) sc += 3;
  if (firstToken(cand.fr) && firstToken(target.fr) && firstToken(cand.fr) === firstToken(target.fr)) sc += 2;
  const habT = new Set([target.habitat1, target.habitat2].map(norm));
  const habC = new Set([cand.habitat1, cand.habitat2].map(norm));
  const overlap = [...habT].some(h => h && habC.has(h));
  if (overlap) sc += 1;
  if ((cand.type && target.type) && norm(cand.type) === norm(target.type)) sc += 1;
  const tf = norm(target.fr), cf = norm(cand.fr);
  if (tf && cf && (tf.includes(cf) || cf.includes(tf))) sc += 1;
  return sc;
}

function mapBankRow(r) {
  const sci = (r.Nom_scientifique || r.nom_scientifique || '').toString();
  const genus = (sci.split(' ')[0] || '').toString();
  const fr = (r['Nom_français'] || r['Nom francais'] || r['nom_francais'] || '').toString();
  return {
    id: (r.id_oiseaux || r.id || r.ID || '').toString(),
    fr,
    sci,
    genus: norm(genus),
    habitat1: r.Habitat_principal || '',
    habitat2: r.Habitat_secondaire || '',
    type: r.Type || '',
  };
}

async function readBank() {
  const bankCsvPath = path.resolve('assets', 'data', 'Bank son oiseauxV4.csv');
  const content = await fs.readFile(bankCsvPath, 'utf8');
  const rows = csvParse(content, { columns: true, skip_empty_lines: true, trim: true });
  const bank = rows.map(mapBankRow).filter(b => b.id && b.fr);
  const byNormFr = new Map(bank.map(b => [norm(b.fr), b]));
  const byId = new Map(bank.map(b => [b.id, b]));
  return { bank, byNormFr, byId };
}

async function readCsvFlexible(csvPath) {
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
  return records;
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

async function resolveBonnesList({ bonnes, bonnesFile }) {
  let items = [];
  if (bonnesFile) {
    const p = path.isAbsolute(bonnesFile) ? bonnesFile : path.resolve(bonnesFile);
    const content = await fs.readFile(p, 'utf8');
    items = splitSpeciesList(content);
  } else if (bonnes) {
    items = splitSpeciesList(bonnes);
  }
  return items;
}

function pickPlausibles({ bank, byNormFr }, bonnesDetails, count) {
  const goodSetNorm = new Set(bonnesDetails.map(b => norm(b.nomFrancais)));
  const agg = new Map(); // key -> { cand, score }
  for (const target of bonnesDetails) {
    const base = byNormFr.get(norm(target.nomFrancais));
    if (!base) continue;
    for (const cand of bank) {
      if (cand.id === base.id) continue;
      if (goodSetNorm.has(norm(cand.fr))) continue;
      const s = scoreCandidate(base, cand);
      if (s <= 0) continue;
      const k = norm(cand.fr);
      const prev = agg.get(k);
      const newScore = (prev?.score || 0) + s;
      if (!prev || newScore > prev.score) agg.set(k, { cand, score: newScore });
    }
  }
  const scored = Array.from(agg.values()).sort((a, b) => b.score - a.score);
  const out = [];
  const used = new Set();
  for (const x of scored) {
    const key = norm(x.cand.fr);
    if (used.has(key)) continue;
    used.add(key);
    out.push(x.cand.fr);
    if (out.length >= count) break;
  }
  return out;
}

async function main() {
  const { quiz, bonnes, bonnesFile, poolPlus, apply, verbose } = parseArgs();
  if (!quiz) {
    console.error("⚠️ Veuillez fournir --quiz=Chemin/ou/Nom.csv");
    process.exit(1);
  }
  const quizPath = path.isAbsolute(quiz) ? quiz : path.resolve('assets', 'Quiz', quiz);
  const exists = await fs.access(quizPath).then(() => true).catch(() => false);
  if (!exists) {
    console.error('❌ Fichier introuvable:', quizPath);
    process.exit(1);
  }

  const bonnesList = await resolveBonnesList({ bonnes, bonnesFile });
  if (bonnesList.length === 0) {
    console.error('⚠️ Liste des nouvelles bonnes réponses vide (utilisez --bonnes ou --bonnes-file)');
    process.exit(1);
  }

  const records = await readCsvFlexible(quizPath);
  if (!records.length) {
    console.error('❌ CSV vide:', quizPath);
    process.exit(1);
  }
  const rawHeaders = Object.keys(records[0]);
  const headers = rawHeaders.map(normalizeHeader);
  const headerMap = new Map(rawHeaders.map(h => [normalizeHeader(h), h]));

  // Colonnes canoniques de sortie
  const COL_ID = 'id_mission';
  const COL_DESC = 'Description';
  const COL_IMG = 'ImageURL';
  const COL_GOOD = 'bonne_reponse';
  const COL_ID_OIS = 'id_oiseaux';
  const COL_BAD = 'mauvaise_reponse';

  // Récupération des valeurs meta depuis la première ligne (si présentes)
  const firstRow = records[0];
  const idMissionVal = headerMap.has('id_mission') ? (firstRow[headerMap.get('id_mission')] || '') : '';
  const descVal = headerMap.has('description') ? (firstRow[headerMap.get('description')] || '') : (firstRow['Description'] || '');
  const imageVal = headerMap.has('imageurl') ? (firstRow[headerMap.get('imageurl')] || '') : (headerMap.has('image_url') ? (firstRow[headerMap.get('image_url')] || '') : (firstRow['ImageURL'] || ''));

  const { bank, byNormFr } = await readBank();

  // Résoudre IDs pour les bonnes réponses
  const bonnesDetails = bonnesList.map(n => {
    const b = byNormFr.get(norm(n));
    return {
      id: b?.id || '',
      nomFrancais: n,
      sci: b?.sci || '',
      genus: b?.genus || '',
      habitat1: b?.habitat1 || '',
      habitat2: b?.habitat2 || '',
      type: b?.type || '',
      found: Boolean(b),
    };
  });

  const unresolved = bonnesDetails.filter(b => !b.found).map(b => b.nomFrancais);
  if (unresolved.length && verbose) {
    console.warn('⚠️ IDs introuvables pour:', unresolved.join(', '));
  }

  // Construire pool: 15 bonnes + N plausibles
  const uniqueBonnes = [];
  const seenB = new Set();
  for (const b of bonnesDetails) {
    const k = norm(b.nomFrancais);
    if (seenB.has(k)) continue;
    seenB.add(k);
    uniqueBonnes.push(b);
  }
  const plausibles = pickPlausibles({ bank, byNormFr }, uniqueBonnes, poolPlus);
  const pool = [...uniqueBonnes.map(b => b.nomFrancais), ...plausibles];

  // Colonnes de sortie fixes
  const outCols = [COL_ID, COL_DESC, COL_IMG, COL_GOOD, COL_ID_OIS, COL_BAD];

  const outRows = [];
  // Lignes "bonnes réponses"
  for (const b of uniqueBonnes) {
    const row = {};
    row[COL_ID] = idMissionVal;
    row[COL_DESC] = descVal;
    row[COL_IMG] = imageVal;
    row[COL_GOOD] = b.nomFrancais;
    row[COL_ID_OIS] = b.id;
    row[COL_BAD] = '';
    outRows.push(row);
  }
  // Lignes du pool (mauvaises)
  for (const name of pool) {
    const row = {};
    row[COL_ID] = '';
    row[COL_DESC] = '';
    row[COL_IMG] = '';
    row[COL_GOOD] = '';
    row[COL_ID_OIS] = '';
    row[COL_BAD] = name;
    outRows.push(row);
  }

  if (!apply) {
    console.log('[DRY] Prévisualisation (aucune écriture). Exemples:');
    console.log('- Bonnes (avec IDs):');
    for (const b of uniqueBonnes) console.log(`  ${b.nomFrancais}${b.id ? ' [' + b.id + ']' : ''}`);
    console.log('- Pool (taille=' + pool.length + '):');
    console.log('  ' + pool.join(', '));
    return;
  }

  await writeCsv(quizPath, outRows, outCols);
  console.log(`[APPLY] Fichier mis à jour: ${quizPath}`);
  console.log(`  Bonnes: ${uniqueBonnes.length} | Pool total: ${pool.length} (15 bonnes + ${plausibles.length} plausibles)`);
}

main().catch(err => { console.error(err); process.exit(1); });
