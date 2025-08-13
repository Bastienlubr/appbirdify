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

async function cleanMissionsFinal() {
  console.log('🧹 Début du nettoyage des missions obsolètes...');
  
  try {
    // Récupérer toutes les missions existantes
    const missionsSnapshot = await db.collection('missions').get();
    
    if (missionsSnapshot.empty) {
      console.log('✅ Aucune mission à supprimer, Firestore est déjà vide');
      return;
    }
    
    console.log(`📋 ${missionsSnapshot.size} missions trouvées à supprimer`);
    
    // Supprimer toutes les missions en batch
    const batch = db.batch();
    missionsSnapshot.docs.forEach(doc => {
      console.log(`  🗑️ Suppression de la mission: ${doc.id}`);
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`✅ ${missionsSnapshot.size} missions supprimées avec succès`);
    
  } catch (error) {
    console.error('❌ Erreur lors du nettoyage:', error);
  }
}

cleanMissionsFinal();
