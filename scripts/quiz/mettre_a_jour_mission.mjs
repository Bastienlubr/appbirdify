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
    mission: m.get('mission') || '',
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
  const tokens = raw
    .toString()
    .replace(/\r\n/g, '\n')
    .split(/\n|\/|,|;|\|/g)
    .map(s => s.trim())
    .filter(Boolean);
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

function buildHeaderMapFromRecords(records) {
  if (!records || records.length === 0) return { headerMap: new Map(), headers: [] };
  const rawHeaders = Object.keys(records[0]);
  const headers = rawHeaders.map(normalizeHeader);
  const headerMap = new Map(rawHeaders.map(h => [normalizeHeader(h), h]));
  return { headerMap, headers };
}

function findCol(headerMap, candidates) {
  for (const cand of candidates) {
    const key = normalizeHeader(cand);
    if (headerMap.has(key)) return headerMap.get(key);
  }
  return null;
}

function getFieldFlexible(row, candidates) {
  const map = new Map(Object.keys(row).map(k => [normalizeHeader(k), k]));
  for (const c of candidates) {
    const key = normalizeHeader(c);
    if (map.has(key)) return (row[map.get(key)] || '').toString();
  }
  return '';
}

function mapBankRow(r) {
  // Identifier colonnes de façon flexible
  const sci = getFieldFlexible(r, ['Nom_scientifique', 'Nom scientifique', 'nom_scientifique', 'nom scientifique']);
  const fr = getFieldFlexible(r, ['Nom_français', 'Nom français', 'Nom francais', 'nom_francais', 'nom français', 'nom francais']);
  const genus = (sci.split(' ')[0] || '').toString();
  
  // Colonnes spécifiques pour les URLs (plus fiable)
  const imageUrl = getFieldFlexible(r, ['photo', 'Photo', 'image', 'Image']) || '';
  const audioUrl = getFieldFlexible(r, ['LienURL', 'lienurl', 'url_audio', 'URL_audio', 'audio', 'Audio']) || '';
  
  const habitat1 = getFieldFlexible(r, ['Habitat_principal', 'Habitat principal']);
  const habitat2 = getFieldFlexible(r, ['Habitat_secondaire', 'Habitat secondaire']);
  const type = getFieldFlexible(r, ['Type']);
  const id = getFieldFlexible(r, ['id_oiseaux', 'id', 'ID']);
  return {
    id: id.toString(),
    fr,
    sci,
    genus: norm(genus),
    habitat1,
    habitat2,
    type,
    urlImage: imageUrl,
    urlAudio: audioUrl,
  };
}

async function readBank() {
  const bankCsvPath = path.resolve('assets', 'data', 'Bank son oiseauxV4.csv');
  const content = await fs.readFile(bankCsvPath, 'utf8');
  const rows = csvParse(content, { columns: true, skip_empty_lines: true, trim: true });
  const bank = rows.map(mapBankRow).filter(b => b.id && (b.fr || b.sci));
  const byNormFr = new Map(bank.map(b => [norm(b.fr), b]));
  const byId = new Map(bank.map(b => [b.id, b]));
  const byLowerFr = new Map(bank.map(b => [String(b.fr || '').toLowerCase(), b]));
  const byNormSci = new Map(bank.map(b => [norm(b.sci), b]));
  return { bank, byNormFr, byId, byLowerFr, byNormSci };
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

async function listAllMissionCsvFiles() {
  const baseDir = path.resolve('assets', 'Missionhome', 'questionMission');
  const subDirs = ['', 'reel'];
  const files = [];
  for (const sub of subDirs) {
    const dir = sub ? path.join(baseDir, sub) : baseDir;
    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      for (const e of entries) {
        if (e.isFile() && e.name.toLowerCase().endsWith('.csv')) files.push(path.join(dir, e.name));
      }
    } catch (_) {}
  }
  return files;
}

async function findAudioFromAllMissions(targetName) {
  const normTarget = norm(targetName);
  const files = await listAllMissionCsvFiles();
  for (const f of files) {
    try {
      const recs = await readCsvFlexible(f);
      if (!recs.length) continue;
      const { headerMap } = buildHeaderMapFromRecords(recs);
      const cGood = findCol(headerMap, ['bonne_reponse', 'bonne reponse']);
      const cId = findCol(headerMap, ['id_oiseaux', 'id bonne reponse', 'id_bonne_reponse']);
      const cAudio = findCol(headerMap, ['url_bonne_reponse', 'url_bonne_reponses', 'audio', 'url_audio']);
      if (!cGood || !cAudio) continue;
      for (const r of recs) {
        const good = (r[cGood] || '').toString().trim();
        if (!good) continue;
        if (norm(good) !== normTarget) continue;
        const url = (r[cAudio] || '').toString().trim();
        if (!url) continue;
        const id = (cId ? (r[cId] || '').toString().trim() : '');
        return { id, urlAudio: url, displayName: good };
      }
    } catch (_) {}
  }
  return null;
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
  const goodSetNorm = new Set(bonnesDetails.map(b => norm(b.displayName)));
  const agg = new Map();
  for (const target of bonnesDetails) {
    const base = byNormFr.get(norm(target.displayName));
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
  const { mission, bonnes, bonnesFile, poolPlus, apply, verbose } = parseArgs();
  if (!mission) {
    console.error("⚠️ Veuillez fournir --mission=assets/Missionhome/questionMission/<ID>.csv");
    process.exit(1);
  }
  const missionPath = path.isAbsolute(mission) ? mission : path.resolve(mission);
  const exists = await fs.access(missionPath).then(() => true).catch(() => false);
  if (!exists) {
    console.error('❌ Fichier introuvable:', missionPath);
    process.exit(1);
  }

  const bonnesListRaw = await resolveBonnesList({ bonnes, bonnesFile });
  if (bonnesListRaw.length === 0) {
    console.error('⚠️ Liste des nouvelles bonnes réponses vide (utilisez --bonnes ou --bonnes-file)');
    process.exit(1);
  }

  const records = await readCsvFlexible(missionPath);
  if (!records.length) {
    console.error('❌ CSV vide:', missionPath);
    process.exit(1);
  }

  const { headerMap, headers } = buildHeaderMapFromRecords(records);

  const COLS_OUT = [
    'id_mission',
    'biome',
    'num_question',
    'bonne_reponse',
    'id_oiseaux',
    'URL_bonne_reponse',
    'mauvaise_reponse',
    'id_oiseaux', // (dupliqué comme dans fichier d'origine)
  ];

  // Lire meta depuis premières lignes
  let idMissionVal = '';
  let biomeVal = '';
  for (const r of records) {
    if (!idMissionVal) {
      const cId = findCol(headerMap, ['id_mission']);
      if (cId) idMissionVal = (r[cId] || '').toString().trim();
    }
    if (!biomeVal) {
      const cBiome = findCol(headerMap, ['biome']);
      if (cBiome) biomeVal = (r[cBiome] || '').toString().trim();
    }
    if (idMissionVal && biomeVal) break;
  }

  const { bank, byNormFr } = await readBank();

  // Table d'alias: clé normalisée -> libellé canonique de la banque
  const ALIASES = new Map([
    ['pluvier grand gravelot', 'Grand Gravelot'],
    ['pluvier grand-gravelot', 'Grand Gravelot'],
    ['grand-gravelot', 'Grand Gravelot'],
    ['pluvier a collier interrompu', 'Gravelot à collier interrompu'],
    ['pluvier à collier interrompu', 'Gravelot à collier interrompu'],
    ['labbe parasite', 'Labbe parasite'],
    ['guillemot de troil', 'Guillemot de Troïl'],
    ['goeland argente', 'Goéland argenté'],
    ['goeland brun', 'Goéland brun'],
    ['goeland marin', 'Goéland marin'],
    ['fou de bassan', 'Fou de Bassan'],
    ['sterne caugek', 'Sterne caugek'],
    ['mouette tridactyle', 'Mouette tridactyle'],
    ['eider a duvet', 'Eider à duvet'],
    ['macreuse noire', 'Macreuse noire'],
    ['macareux moine', 'Macareux moine'],
    ['huitrier pie', 'Huîtrier pie'],
    ['pingouin torda', 'Pingouin torda'],
    ['fulmar boreal', 'Fulmar boréal'],
    // Alias FR -> FR synonymes
    ['taleve sultane', 'Poule sultane'],
    ['talève sultane', 'Poule sultane'],
    ['faucon emerillon', 'Émerillon'],
    ['faucon émerillon', 'Émerillon'],
    // Alias FR -> noms scientifiques
    ['poule sultane', 'Porphyrio porphyrio'],
    ['talève sultane', 'Porphyrio porphyrio'],
    ['emerillon', 'Falco columbarius'],
    ['émerillon', 'Falco columbarius'],
    ['pipit rousseline', 'Anthus campestris'],
  ]);

  // Résoudre bonnes (ID + URL audio) et dédupliquer en conservant l'ordre d'entrée
  const uniqueBonnes = [];
  const seen = new Set();
  for (const name of bonnesListRaw) {
    const key = norm(name);
    if (seen.has(key)) continue;
    seen.add(key);
    const aliasCanon = ALIASES.get(key) || name;

    // Correspondance EXACTE UNIQUEMENT (pas de fallback flou)
    const { byNormFr: _byNormFr, byNormSci: _byNormSci } = await readBank();
    
    // 1. Match exact nom français normalisé
    let match = _byNormFr.get(norm(aliasCanon)) || _byNormFr.get(norm(name));
    
    // 2. Si pas trouvé, match exact nom scientifique seulement
    if (!match) {
      match = _byNormSci.get(norm(aliasCanon)) || _byNormSci.get(norm(name));
    }
    
    // 3. Aucun match approximatif - soit exact soit null

    uniqueBonnes.push({
      id: match?.id || '',
      displayName: (match?.fr || name), // écriture FR prioritaire dans le CSV
      urlAudio: match?.urlAudio || '',
      sci: match?.sci || '',
      genus: match?.genus || '',
      habitat1: match?.habitat1 || '',
      habitat2: match?.habitat2 || '',
      type: match?.type || '',
      found: Boolean(match),
    });
  }

  const unresolved = uniqueBonnes.filter(b => !b.found || !b.urlAudio || !b.id).map((b, idx) => ({ name: b.displayName, idx }));
  if (unresolved.length && verbose) {
    console.warn('⚠️ Remplacement de bonnes sans audio/ID:', unresolved.map(u => uniqueBonnes[u.idx].displayName).join(', '));
  }

  // Fallback: utiliser l'ancienne version (même CSV) puis le CSV "reel/<ID>.csv" pour remplacer les entrées sans audio/ID
  if (unresolved.length) {
    const desiredSet = new Set(uniqueBonnes.map(b => norm(b.displayName)));

    // 1) Candidats depuis le fichier actuel (avant réécriture): lignes question avec URL audio
    const oldGoodCandidates = [];
    // Localiser colonnes courantes
    const curColNum = findCol(headerMap, ['num_question']);
    const curColGood = findCol(headerMap, ['bonne_reponse', 'bonne reponse']);
    const curColId = findCol(headerMap, ['id_oiseaux', 'id bonne reponse', 'id_bonne_reponse']);
    const curColAudio = findCol(headerMap, ['url_bonne_reponse', 'url_bonne_reponses', 'audio', 'url_audio']);
    for (const r of records) {
      const numQ = curColNum ? (r[curColNum] || '').toString().trim() : '';
      const good = curColGood ? (r[curColGood] || '').toString().trim() : '';
      const idOld = curColId ? (r[curColId] || '').toString().trim() : '';
      const urlOld = curColAudio ? (r[curColAudio] || '').toString().trim() : '';
      if (numQ && good && urlOld) {
        const key = norm(good);
        if (!desiredSet.has(key)) {
          oldGoodCandidates.push({ displayName: good, id: idOld, urlAudio: urlOld });
        }
      }
    }

    // 2) Candidats depuis le fichier reel/<ID>.csv (si présent)
    const reelCandidates = [];
    try {
      const reelPath = path.resolve('assets', 'Missionhome', 'questionMission', 'reel', `${idMissionVal}.csv`);
      const reelExists = await fs.access(reelPath).then(() => true).catch(() => false);
      if (reelExists) {
        const reelRecords = await readCsvFlexible(reelPath);
        const { headerMap: reelHeaderMap } = buildHeaderMapFromRecords(reelRecords);
        const reelColNum = findCol(reelHeaderMap, ['num_question']);
        const reelColGood = findCol(reelHeaderMap, ['bonne_reponse', 'bonne reponse']);
        const reelColId = findCol(reelHeaderMap, ['id_oiseaux', 'id bonne reponse', 'id_bonne_reponse']);
        const reelColAudio = findCol(reelHeaderMap, ['url_bonne_reponse', 'url_bonne_reponses', 'audio', 'url_audio']);
        for (const r of reelRecords) {
          const numQ = reelColNum ? (r[reelColNum] || '').toString().trim() : '';
          const good = reelColGood ? (r[reelColGood] || '').toString().trim() : '';
          const idOld = reelColId ? (r[reelColId] || '').toString().trim() : '';
          const urlOld = reelColAudio ? (r[reelColAudio] || '').toString().trim() : '';
          if (numQ && good && urlOld) {
            const key = norm(good);
            if (!desiredSet.has(key)) {
              reelCandidates.push({ displayName: good, id: idOld, urlAudio: urlOld });
            }
          }
        }
      }
    } catch (_) {}

    // Priorité: reelCandidates puis oldGoodCandidates
    const mergedCandidates = [...reelCandidates, ...oldGoodCandidates];
    const usedOld = new Set();
    for (const u of unresolved) {
      const replacement = mergedCandidates.find(c => !usedOld.has(norm(c.displayName)) && !desiredSet.has(norm(c.displayName)));
      if (replacement) {
        uniqueBonnes[u.idx] = {
          id: replacement.id || '',
          displayName: replacement.displayName,
          urlAudio: replacement.urlAudio || '',
          sci: '',
          genus: '',
          habitat1: '',
          habitat2: '',
          type: '',
          found: true,
        };
        usedOld.add(norm(replacement.displayName));
        desiredSet.add(norm(replacement.displayName));
      }
    }
  }

  // Re-identifier les non résolus après fallback (pour log seulement)
  let stillUnresolved = uniqueBonnes.filter(b => !b.id || !b.urlAudio);
  if (stillUnresolved.length) {
    // Fallback global: chercher dans tous les CSV missions
    // PLUS DE FALLBACK FLOU - correspondances exactes uniquement
    // Les espèces sans match exact garderont urlAudio vide
    stillUnresolved = uniqueBonnes.filter(b => !b.id || !b.urlAudio);
  }
  if (stillUnresolved.length && verbose) {
    console.warn('⚠️ Toujours sans ID/audio après fallback:', stillUnresolved.map(b => b.displayName).join(', '));
  }

  // Générer plausibles à partir des bonnes
  const plausibles = pickPlausibles({ bank, byNormFr }, uniqueBonnes, poolPlus);
  const pool = [...uniqueBonnes.map(b => b.displayName), ...plausibles];

  // Construire lignes de sortie
  const outRows = [];
  // 15 questions numérotées
  const countQuestions = uniqueBonnes.length;
  for (let i = 0; i < countQuestions; i++) {
    const b = uniqueBonnes[i];
    const row = {};
    row['id_mission'] = idMissionVal;
    row['biome'] = biomeVal;
    row['num_question'] = String(i + 1);
    row['bonne_reponse'] = b.displayName;
    row['id_oiseaux'] = b.id;
    row['URL_bonne_reponse'] = b.urlAudio || '';
    row['mauvaise_reponse'] = '';
    // la 2e colonne id_oiseaux (dupliquée) restera vide pour les lignes "bonne"
    outRows.push(row);
  }
  // Pool de mauvaises
  for (const name of pool) {
    const row = {};
    row['id_mission'] = '';
    row['biome'] = '';
    row['num_question'] = '';
    row['bonne_reponse'] = '';
    row['id_oiseaux'] = '';
    row['URL_bonne_reponse'] = '';
    row['mauvaise_reponse'] = name;
    // 2e id_oiseaux vide
    outRows.push(row);
  }

  if (!apply) {
    console.log('[DRY] Prévisualisation (aucune écriture)');
    console.log(`- id_mission: ${idMissionVal} | biome: ${biomeVal}`);
    console.log('- Bonnes (avec IDs):');
    for (const b of uniqueBonnes) console.log(`  ${b.displayName}${b.id ? ' [' + b.id + ']' : ''}${b.urlAudio ? ' <audio>' : ''}`);
    console.log('- Pool (taille=' + pool.length + '):');
    console.log('  ' + pool.join(', '));
    return;
  }

  await writeCsv(missionPath, outRows, COLS_OUT);
  console.log(`[APPLY] Mission mise à jour: ${missionPath}`);
  console.log(`  Questions: ${countQuestions} | Pool total: ${pool.length} (15 bonnes + ${plausibles.length} plausibles)`);
}

main().catch(err => { console.error(err); process.exit(1); });