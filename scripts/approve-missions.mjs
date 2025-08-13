import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function initAdmin() {
  const keyPath = resolve(__dirname, '../serviceAccountKey.json');
  const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
  try {
    initializeApp({ credential: cert(serviceAccount) });
  } catch (e) {
    if (e.code !== 'app/duplicate-app') throw e;
  }
  return getFirestore();
}

async function approveAllMissions() {
  const db = initAdmin();
  console.log('🔒 Mise à jour du champ "statut" des missions → "approuvee"');
  const snapshot = await db.collection('missions').get();
  console.log(`📄 ${snapshot.size} documents trouvés`);

  let updated = 0;
  const batchSize = 400;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, { statut: 'approuvee', updatedAt: new Date() });
    ops += 1;
    if (ops >= batchSize) {
      await batch.commit();
      updated += ops;
      console.log(`✅ ${updated} missions mises à jour...`);
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
    updated += ops;
  }

  console.log(`🎉 Terminé. ${updated} missions approuvées.`);
}

approveAllMissions().catch((e) => {
  console.error('❌ Échec:', e);
  process.exit(1);
});


