#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import { parse } from 'csv-parse';

function parseArgs() {
  const m = new Map(process.argv.slice(2).map(a => {
    const [k, v] = a.split('=');
    const ck = k.replace(/^--/, '');
    let cv = v ?? true;
    if (typeof cv === 'string') cv = cv.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
    return [ck, cv];
  }));
  return {
    quiz: m.get('quiz') || '15 plus belles voix.csv',
    par: m.get('par') ? Number(m.get('par')) : 3,
    out: m.get('out') || null,
    verbose: Boolean(m.get('verbose')),
    apply: Boolean(m.get('apply')),
    cross: Boolean(m.get('cross')),
    clean: Boolean(m.get('clean')),
    refine: Boolean(m.get('refine')),
    maxSim: m.get('maxSim') ? Number(m.get('maxSim')) : 3,
    type: m.get('type') || '',
    force: Boolean(m.get('force')),
    prefer: m.get('prefer') || '',
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

function norm(s) {
  return (s || '')
    .toString()
    .replace(/œ/gi, 'oe').replace(/æ/gi, 'ae')
    .normalize('NFD').replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/['\-]/g, ' ')
    .replace(/[^a-z\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
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
  if (norm(cand.type) && norm(target.type) && norm(cand.type) === norm(target.type)) sc += 1;
  const tf = norm(target.fr), cf = norm(cand.fr);
  if (tf && cf && (tf.includes(cf) || cf.includes(tf))) sc += 1;
  return sc;
}

function mapBankRow(r) {
  const sci = (r.Nom_scientifique || r.nom_scientifique || '').toString();
  const genus = sci.split(' ')[0] || '';
  return {
    id: (r.id_oiseaux || r.id || r.ID || '').toString(),
    fr: r.Nom_français || r.Nom_francais || r.nom_francais || '',
    sci,
    genus: norm(genus),
    habitat1: r.Habitat_principal || '',
    habitat2: r.Habitat_secondaire || '',
    type: r.Type || '',
  };
}

async function main() {
  const { quiz, par, out, verbose, apply, cross, clean, refine, maxSim, type, force, prefer } = parseArgs();
  const bankPath = path.resolve('assets', 'data', 'Bank son oiseauxV4.csv');
  const quizPath = path.isAbsolute(quiz) ? quiz : path.resolve('assets', 'Quiz', quiz);

  const bankRowsRaw = await readCsv(bankPath, { columns: true, delimiter: ',' });
  const bank = bankRowsRaw.map(mapBankRow).filter(b => b.id && b.fr);
  const byFr = new Map(bank.map(b => [norm(b.fr), b]));
  const byId = new Map(bank.map(b => [b.id, b]));

  const quizRows = await readCsv(quizPath, { columns: true, delimiter: ',' });
  if (quizRows.length === 0) {
    console.error('Quiz vide:', quizPath);
    process.exit(1);
  }

  const cols = Object.keys(quizRows[0]);
  const colGood = cols.find(c => norm(c) === 'bonne reponse') || 'bonne_reponse';
  const colGoodId = cols.find(c => norm(c) === 'id oiseaux') || 'id_oiseaux';

  const resultats = [];
  for (const row of quizRows) {
    const frName = (row[colGood] || '').toString();
    if (!frName) continue;
    const id = (row[colGoodId] || '').toString();
    let target = null;

    if (id && byId.has(id)) target = byId.get(id);
    else target = byFr.get(norm(frName)) || null;

    if (!target) {
      if (verbose) console.warn('[INCONNU]', frName);
      continue;
    }

    const scored = [];
    for (const cand of bank) {
      if (cand.id === target.id) continue;
      const s = scoreCandidate(target, cand);
      if (s > 0) scored.push({ cand, s });
    }
    scored.sort((a, b) => b.s - a.s);

    const mauvaises = scored.slice(0, par).map(x => ({
      id: x.cand.id,
      nomFrancais: x.cand.fr,
      nomScientifique: x.cand.sci,
      score: x.s,
      habitatPrincipal: x.cand.habitat1,
      habitatSecondaire: x.cand.habitat2,
      type: x.cand.type,
    }));

    resultats.push({
      bonneReponse: {
        id: target.id,
        nomFrancais: target.fr,
        nomScientifique: target.sci,
        habitatPrincipal: target.habitat1,
        habitatSecondaire: target.habitat2,
        type: target.type,
      },
      mauvaisesReponses: mauvaises,
    });
  }

  const payload = {
    quizFichier: path.basename(quizPath),
    parCible: par,
    totalCibles: resultats.length,
    genereLe: new Date().toISOString(),
    resultats,
  };

  // Option d'écriture dans le CSV
  if (apply) {
    const byIdRes = new Map();
    const byFrRes = new Map();
    for (const r of resultats) {
      const best = (r.mauvaisesReponses && r.mauvaisesReponses[0]) || null;
      if (!best) continue;
      const keyId = (r.bonneReponse.id || '').toString();
      const keyFr = norm(r.bonneReponse.nomFrancais);
      if (keyId) byIdRes.set(keyId, best);
      if (keyFr) byFrRes.set(keyFr, best);
    }

    const cols = Object.keys(quizRows[0]);
    const colGood = cols.find(c => norm(c) === 'bonne reponse') || 'bonne_reponse';
    const colGoodId = cols.find(c => norm(c) === 'id oiseaux') || 'id_oiseaux';
    let colBad = cols.find(c => norm(c) === 'mauvaise reponse');
    let colBadBis = cols.find(c => norm(c) === 'mauvaise reponse bis') || cols.find(c => c === 'mauvaise_reponse_bis');
    const finalCols = [...cols];
    if (!colBad) { colBad = 'mauvaise_reponse'; finalCols.push(colBad); }
    if (cross && !colBadBis) { colBadBis = 'mauvaise_reponse_bis'; finalCols.push(colBadBis); }

    let filled = 0;
    let filledBis = 0;

    const goodList = quizRows.map(r => (r[colGood] || '').toString()).filter(Boolean);
    const crossUseCount = new Map(goodList.map(n => [n, 0]));

    // Préférences explicites
    const preferList = (prefer ? String(prefer).split(',').map(s => s.trim()).filter(Boolean) : []).map(n => ({ raw: n, key: norm(n) }));
    let preferIndex = 0;

    // Unicité des mauvaises réponses principales
    const usedBad = new Set();

    for (let i = 0; i < quizRows.length; i++) {
      const row = quizRows[i];
      const frName = (row[colGood] || '').toString();
      const target = byFr.get(norm(frName));

      const hasBad = row[colBad] && String(row[colBad]).trim().length > 0;
      if (force || !hasBad) {
        const id = (row[colGoodId] || '').toString();
        const initial = (id && byIdRes.get(id)) || byFrRes.get(norm(frName)) || null;
        let chosen = initial ? initial.nomFrancais : '';

        // 0) Si liste de préférences fournie, tenter d'abord dans cet ordre
        if (preferList.length > 0) {
          let tried = 0;
          while (tried < preferList.length) {
            const idx = (preferIndex + tried) % preferList.length;
            const pref = preferList[idx];
            const b = byFr.get(pref.key);
            if (b && (!type || norm(b.type) === norm(type)) && (!target || b.id !== target.id)) {
              if (!usedBad.has(b.fr) && norm(b.fr) !== norm(frName)) {
                chosen = b.fr;
                preferIndex = idx + 1;
                break;
              }
            }
            tried++;
          }
        }

        // 1) Sinon, éviter doublons / appliquer contraintes
        if ((!chosen || usedBad.has(chosen)) && target) {
          const alts = [];
          for (const c of bank) {
            if (c.id === target.id) continue;
            const s = scoreCandidate(target, c);
            if (s <= 0) continue;
            if (type && norm(c.type) !== norm(type)) continue;
            if (refine) {
              if (c.genus && target.genus && c.genus === target.genus) continue;
              if (Number.isFinite(maxSim) && s > maxSim) continue;
            }
            if (usedBad.has(c.fr)) continue;
            alts.push({ c, s });
          }
          alts.sort((a, b) => (refine ? a.s - b.s : b.s - a.s));
          if (alts.length > 0) chosen = alts[0].c.fr;
        }

        if (chosen) {
          row[colBad] = chosen;
          usedBad.add(chosen);
          filled += force && hasBad ? 0 : 1;
        }
      } else {
        usedBad.add(String(row[colBad]).trim());
      }

      if (cross && colBadBis && !(row[colBadBis] && String(row[colBadBis]).trim().length > 0)) {
        const candidates = goodList.filter(n => n && n !== frName);
        let bestName = null; let bestScore = -Infinity;
        for (const candName of candidates) {
          const cand = byFr.get(norm(candName));
          if (!cand || !target) continue;
          const s = scoreCandidate(target, cand);
          const usage = crossUseCount.get(candName) ?? 0;
          const composite = s * 1000 - usage;
          if (composite > bestScore) { bestScore = composite; bestName = candName; }
        }
        if (!bestName && candidates.length > 0) {
          const offset = i % candidates.length;
          bestName = candidates[offset];
        }
        if (bestName) {
          row[colBadBis] = bestName;
          crossUseCount.set(bestName, (crossUseCount.get(bestName) ?? 0) + 1);
          filledBis++;
        }
      }
    }

    if (clean) {
      for (const row of quizRows) {
        if (row[colBad]) {
          const first = String(row[colBad]).split('|')[0].trim();
          row[colBad] = first;
        }
        if (colBadBis) delete row[colBadBis];
      }
      if (colBadBis) {
        const idx = finalCols.indexOf(colBadBis);
        if (idx >= 0) finalCols.splice(idx, 1);
      }
    }

    const dedupCols = Array.from(new Set(finalCols));
    await writeCsv(quizPath, quizRows, dedupCols);
    console.log(`[APPLY] ${path.basename(quizPath)}: mauvaise_reponse=${filled}, mauvaise_reponse_bis=${filledBis} / ${quizRows.length}${clean ? ' (nettoyé)' : ''}`);
  }

  if (out) {
    const outPath = path.isAbsolute(out) ? out : path.resolve('data', 'exports', out);
    await fs.mkdir(path.dirname(outPath), { recursive: true });
    await fs.writeFile(outPath, JSON.stringify(payload, null, 2), 'utf8');
    console.log('Export écrit:', outPath);
  } else {
    console.log(JSON.stringify(payload, null, 2));
  }
}

main().catch(err => { console.error(err); process.exit(1); });
