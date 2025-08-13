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

async function testViesStructure() {
  try {
    console.log('🧪 Test de la structure des vies dans Firestore...');
    console.log(`📁 Projet: ${serviceAccount.project_id}`);
    
    // 1. Vérifier la structure actuelle des vies
    console.log('\n📊 Structure actuelle des vies...');
    const usersSnapshot = await db.collection('utilisateurs').get();
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const data = userDoc.data();
      console.log(`   👤 Utilisateur: ${uid}`);
      
      // Vérifier les différents champs de vies
      const livesRemaining = data['livesRemaining'];
      const viesCompte = data['vies']?.['compte'];
      const viesMax = data['vies']?.['max'];
      const dailyResetDate = data['dailyResetDate'];
      const lastUpdated = data['lastUpdated'];
      
      console.log(`      📋 Structure des vies:`);
      console.log(`         - livesRemaining: ${livesRemaining ?? 'undefined'}`);
      console.log(`         - vies.compte: ${viesCompte ?? 'undefined'}`);
      console.log(`         - vies.max: ${viesMax ?? 'undefined'}`);
      console.log(`         - dailyResetDate: ${dailyResetDate ?? 'undefined'}`);
      console.log(`         - lastUpdated: ${lastUpdated ?? 'undefined'}`);
      
      // Identifier les incohérences
      if (livesRemaining !== undefined && viesCompte !== undefined) {
        console.log(`      ⚠️ INCOHÉRENCE: Les deux structures existent !`);
        console.log(`         - livesRemaining: ${livesRemaining}`);
        console.log(`         - vies.compte: ${viesCompte}`);
      } else if (livesRemaining !== undefined) {
        console.log(`      ✅ Structure moderne: livesRemaining`);
      } else if (viesCompte !== undefined) {
        console.log(`      ⚠️ Structure ancienne: vies.compte`);
      } else {
        console.log(`      ℹ️ Aucune structure de vies trouvée`);
      }
    }
    
    // 2. Test de restauration des vies
    console.log('\n🔄 Test de restauration des vies...');
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      console.log(`   👤 Utilisateur: ${uid}`);
      
      // Simuler la restauration des vies
      await db.collection('utilisateurs').doc(uid).set({
        'livesRemaining': 5,
        'dailyResetDate': new Date(),
        'lastUpdated': new Date(),
      }, { merge: true });
      
      console.log(`      ✅ Vies restaurées à 5 (structure harmonisée)`);
    }
    
    // 3. Vérifier la structure après restauration
    console.log('\n📊 Structure après restauration...');
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const data = userDoc.data();
      console.log(`   👤 Utilisateur: ${uid}`);
      
      const livesRemaining = data['livesRemaining'];
      const dailyResetDate = data['dailyResetDate'];
      
      console.log(`      📋 Vies actuelles:`);
      console.log(`         - livesRemaining: ${livesRemaining ?? 'undefined'}`);
      console.log(`         - dailyResetDate: ${dailyResetDate ?? 'undefined'}`);
      
      if (livesRemaining === 5) {
        console.log(`      ✅ Vies correctement restaurées à 5`);
      } else {
        console.log(`      ❌ Problème: vies = ${livesRemaining}`);
      }
    }
    
    console.log('\n🎉 Test terminé avec succès !');
    
  } catch (error) {
    console.error('❌ Erreur lors du test:', error);
  }
}

testViesStructure();
