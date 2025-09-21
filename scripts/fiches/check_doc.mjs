#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import admin from 'firebase-admin';

async function initFirebase() {
  const serviceAccount = JSON.parse(
    await readFile(resolve('serviceAccountKey.json'), 'utf8')
  );
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return { db: admin.firestore(), projectId: serviceAccount.project_id };
}

async function main() {
  const { db, projectId } = await initFirebase();
  const targets = [
    'fiches_oiseaux/torcol-fourmilier',
    'fiches_oiseaux/jynx_torquilla',
  ];
  console.log(`Project: ${projectId}`);
  for (const path of targets) {
    const snap = await db.doc(path).get();
    console.log(`Doc ${path} exists: ${snap.exists}`);
    if (snap.exists) {
      const data = snap.data() || {};
      const keys = Object.keys(data).sort();
      console.log(`  keys: ${keys.join(', ')}`);
      console.log(`  nomFrancais: ${data.nomFrancais || ''}`);
      console.log(`  appId: ${data.appId || ''}`);
      console.log(`  updatedAt: ${data.updatedAt || ''}`);
      const panels = ['identification','habitat','alimentation','reproduction','protection'];
      for (const p of panels) {
        const ps = await db.collection(`${path}/${p}`).doc('current').get();
        console.log(`  panel ${p}/current exists: ${ps.exists}`);
        if (ps.exists) {
          const pk = Object.keys(ps.data() || {}).sort();
          console.log(`    fields: ${pk.join(', ')}`);
        }
      }
    }
  }
}

main().catch(e => { console.error(e); process.exit(1); });


