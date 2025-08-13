import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const serviceAccount = JSON.parse(
  readFileSync(resolve(__dirname, '../serviceAccountKey.json'), 'utf8')
);

const app = initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore(app);

async function cleanBirds() {
  console.log('🧹 Début du nettoyage de la collection sons_oiseaux...');
  try {
    const snap = await db.collection('sons_oiseaux').get();
    if (snap.empty) {
      console.log('✅ Aucune espèce à supprimer');
      return;
    }
    console.log(`📋 ${snap.size} documents à supprimer`);
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    console.log(`✅ ${snap.size} espèces supprimées avec succès`);
  } catch (e) {
    console.error('❌ Erreur lors du nettoyage:', e);
    process.exit(1);
  }
}

cleanBirds();
