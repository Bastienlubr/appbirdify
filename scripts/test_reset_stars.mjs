import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const serviceAccount = JSON.parse(
  readFileSync(join(__dirname, '..', 'serviceAccountKey.json'), 'utf8')
);

const app = initializeApp({
  credential: cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = getFirestore(app);

async function testResetStars() {
  try {
    console.log('🧪 Test de la fonction resetAllStars...');
    console.log(`📁 Projet: ${serviceAccount.project_id}`);
    
    // 1. Vérifier l'état actuel des étoiles
    console.log('\n📊 État actuel des étoiles...');
    const usersSnapshot = await db.collection('utilisateurs').get();
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      console.log(`   👤 Utilisateur: ${uid}`);
      
      const missionsSnapshot = await db
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .get();
      
      if (!missionsSnapshot.empty) {
        console.log(`      📋 Missions trouvées: ${missionsSnapshot.docs.length}`);
        
        for (const missionDoc of missionsSnapshot.docs) {
          const missionId = missionDoc.id;
          const data = missionDoc.data();
          const etoiles = data['etoiles'] ?? 0;
          const tentatives = data['tentatives'] ?? 0;
          
          console.log(`         🎯 ${missionId}: ${etoiles} étoiles, ${tentatives} tentatives`);
        }
      } else {
        console.log(`      ℹ️ Aucune mission trouvée`);
      }
    }
    
    // 2. Simuler la fonction resetAllStars
    console.log('\n🔄 Simulation de resetAllStars...');
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      console.log(`   👤 Utilisateur: ${uid}`);
      
      const missionsSnapshot = await db
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .get();
      
      if (!missionsSnapshot.empty) {
        console.log(`      📋 Mise à jour de ${missionsSnapshot.docs.length} missions...`);
        
        const batch = db.batch();
        let missionsUpdated = 0;
        
        for (const missionDoc of missionsSnapshot.docs) {
          const missionId = missionDoc.id;
          
          // Remettre à zéro les statistiques
          batch.update(missionDoc.reference, {
            'etoiles': 0,
            'tentatives': 0,
            'moyenneScores': 0.0,
            'scoresHistorique': {},
            'scoresPourcentagesPasses': [],
            'derniereMiseAJour': new Date(),
          });
          
          missionsUpdated++;
          console.log(`         🎯 ${missionId}: étoiles remises à 0`);
        }
        
        await batch.commit();
        console.log(`      ✅ ${missionsUpdated} missions mises à jour`);
      }
    }
    
    // 3. Vérifier l'état après reset
    console.log('\n📊 État après reset des étoiles...');
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      console.log(`   👤 Utilisateur: ${uid}`);
      
      const missionsSnapshot = await db
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .get();
      
      if (!missionsSnapshot.empty) {
        for (const missionDoc of missionsSnapshot.docs) {
          const missionId = missionDoc.id;
          const data = missionDoc.data();
          const etoiles = data['etoiles'] ?? 0;
          const tentatives = data['tentatives'] ?? 0;
          
          console.log(`         🎯 ${missionId}: ${etoiles} étoiles, ${tentatives} tentatives`);
        }
      }
    }
    
    console.log('\n🎉 Test terminé avec succès !');
    
  } catch (error) {
    console.error('❌ Erreur lors du test:', error);
  }
}

testResetStars();
