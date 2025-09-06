#!/usr/bin/env node
import path from 'node:path';
import process from 'node:process';
import { getFirestore, getTimestamp } from '../core/firebase_admin_init.mjs';
import { readCsv, readJson, writeJson, fileExists } from '../core/files_io.mjs';

// Usage: node scripts/missions/creer_ou_completer_progression_utilisateur.mjs --uid=<USER_ID> [--biome=...] [--apply] [--limit=20]

const args = new Map(process.argv.slice(2).map(a => {
  const [k, v] = a.split('=');
  return [k.replace(/^--/, ''), v ?? true];
}));

const dryRun = args.get('apply') ? false : true;
const biomeFilter = (args.get('biome') || '').toString().toLowerCase();
const uid = args.get('uid') || null;
const limit = args.get('limit') ? Number(args.get('limit')) : null;

function log(...m) { console.log('[missions:progression]', ...m); }
function warn(...m) { console.warn('[warn]', ...m); }

async function loadAssetsMissions() {
  const csvPath = path.resolve('assets', 'Missionhome', 'etoile mission', 'missions_data.csv');
  const jsonPath = path.resolve('assets', 'firebase-import', 'missions_data.json');
  const result = { csv: [], json: [] };
  if (await fileExists(csvPath)) {
    try { result.csv = await readCsv(csvPath, { columns: true, delimiter: ',' }); log(`CSV: ${result.csv.length}`); } catch (e) { warn('CSV erreur:', e.message); }
  }
  if (await fileExists(jsonPath)) {
    try { const data = await readJson(jsonPath); result.json = Array.isArray(data) ? data : (data.missions || []); log(`JSON: ${result.json.length}`); } catch (e) { warn('JSON erreur:', e.message); }
  }
  return result;
}

function normalizeMissionId(id) { return (id || '').toString().trim(); }
function toBiomeFromId(missionId) {
  if (!missionId) return '';
  const c = missionId[0].toUpperCase();
  const map = { U: 'urbain', F: 'forestier', L: 'littoral', M: 'montagnard', A: 'agricole', Z: 'zones-humides' };
  return map[c] || c;
}

function mergeCsvJson(csvList, jsonList) {
  const byId = new Map();
  for (const row of csvList) {
    const id = normalizeMissionId(row.id || row.ID || row.missionId);
    if (!id) continue; byId.set(id, { id, sourceCsv: row, sourceJson: null });
  }
  for (const j of jsonList) {
    const id = normalizeMissionId(j.id || j.missionId);
    if (!id) continue; const prev = byId.get(id) || { id, sourceCsv: null, sourceJson: null }; prev.sourceJson = j; byId.set(id, prev);
  }
  return [...byId.values()];
}

function toProgressDocSeed(entry) {
  const missionId = entry.id;
  const biome = (entry.sourceCsv?.biome || entry.sourceJson?.biome || toBiomeFromId(missionId) || '').toString().toLowerCase();
  const index = Number(entry.sourceCsv?.index ?? entry.sourceJson?.index ?? 0) || 0;
  const unlocked = index === 1;
  return { missionId, biome, index, deverrouille: unlocked, etoiles: 0, tentatives: 0, moyenneScores: 0, scoresHistorique: {} };
}

async function ensureUserDoc(firestore, userId) {
  const userRef = firestore.collection('utilisateurs').doc(userId);
  const snap = await userRef.get();
  if (!snap.exists && !dryRun) { await userRef.set({ profil: { creeLe: getTimestamp().now() } }, { merge: true }); }
}

async function upsertProgression(firestore, userId, seed) {
  const ref = firestore.collection('utilisateurs').doc(userId).collection('progression_missions').doc(seed.missionId);
  const doc = await ref.get();
  if (!doc.exists) {
    if (dryRun) return { action: 'would-create', id: seed.missionId };
    await ref.set({ etoiles: seed.etoiles, tentatives: seed.tentatives, deverrouille: seed.deverrouille, biome: seed.biome, index: seed.index, scoresHistorique: seed.scoresHistorique, moyenneScores: seed.moyenneScores, creeLe: getTimestamp().now(), ...(seed.deverrouille ? { deverrouilleLe: getTimestamp().now() } : {}) });
    return { action: 'created', id: seed.missionId };
  } else {
    const data = doc.data() || {}; const updates = {};
    if (data.biome == null) updates.biome = seed.biome; if (data.index == null) updates.index = seed.index;
    if (Object.keys(updates).length === 0) return { action: 'noop', id: seed.missionId };
    if (dryRun) return { action: 'would-update', id: seed.missionId, updates };
    await ref.update(updates); return { action: 'updated', id: seed.missionId };
  }
}

async function main() {
  const firestore = getFirestore();
  if (!uid) { console.error('Veuillez fournir --uid=<USER_ID>'); process.exit(1); }
  await ensureUserDoc(firestore, uid);
  const { csv, json } = await loadAssetsMissions();
  let merged = mergeCsvJson(csv, json);
  if (biomeFilter) { merged = merged.filter(e => (e.sourceCsv?.biome || e.sourceJson?.biome || toBiomeFromId(e.id) || '').toString().toLowerCase().includes(biomeFilter)); }
  if (limit != null && Number.isFinite(limit)) { merged = merged.slice(0, limit); }
  const seeds = merged.map(toProgressDocSeed);
  const results = []; for (const seed of seeds) { results.push(await upsertProgression(firestore, uid, seed)); }
  const summary = { dryRun, total: results.length, created: results.filter(r => r.action === 'created').length, updated: results.filter(r => r.action === 'updated').length, wouldCreate: results.filter(r => r.action === 'would-create').length, wouldUpdate: results.filter(r => r.action === 'would-update').length, noop: results.filter(r => r.action === 'noop').length };
  console.table(summary);
  const outPath = path.resolve('data', 'exports', `progression_seed_${uid}.json`);
  await writeJson(outPath, { uid, seeds, summary, at: new Date().toISOString() });
  log('Export écrit:', outPath);
}

main().catch(err => { console.error(err); process.exit(1); });


