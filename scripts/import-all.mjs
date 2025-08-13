import { importOiseaux } from './import-oiseaux.mjs';
import { importMissions } from './import-missions.mjs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration Firebase Admin
const serviceAccount = JSON.parse(
  readFileSync(resolve(__dirname, '../serviceAccountKey.json'), 'utf8')
);

// Initialiser Firebase Admin SDK
try {
  initializeApp({
    credential: cert(serviceAccount)
  });
} catch (error) {
  // Si l'app est déjà initialisée, on continue
  if (error.code !== 'app/duplicate-app') {
    throw error;
  }
}

const db = getFirestore();

// Fonction pour sauvegarder l'état actuel (pour rollback)
async function backupCurrentState() {
  console.log('💾 Sauvegarde de l\'état actuel...');
  
  try {
    const backup = {
      timestamp: new Date().toISOString(),
      oiseaux: {},
      missions: {}
    };

    // Sauvegarder les oiseaux existants
    const oiseauxSnapshot = await db.collection('sons_oiseaux').get();
    oiseauxSnapshot.docs.forEach(doc => {
      backup.oiseaux[doc.id] = doc.data();
    });

    // Sauvegarder les missions existantes
    const missionsSnapshot = await db.collection('missions').get();
    missionsSnapshot.docs.forEach(doc => {
      backup.missions[doc.id] = doc.data();
    });

    console.log(`📦 Sauvegarde créée: ${Object.keys(backup.oiseaux).length} oiseaux, ${Object.keys(backup.missions).length} missions`);
    return backup;

  } catch (error) {
    console.error('❌ Erreur lors de la sauvegarde:', error);
    throw error;
  }
}

// Fonction pour restaurer l'état précédent
async function restoreFromBackup(backup) {
  console.log('🔄 Restauration depuis la sauvegarde...');
  
  try {
    const batch = db.batch();

    // Restaurer les oiseaux
    for (const [id, data] of Object.entries(backup.oiseaux)) {
      const docRef = db.collection('sons_oiseaux').doc(id);
      batch.set(docRef, data);
    }

    // Restaurer les missions
    for (const [id, data] of Object.entries(backup.missions)) {
      const docRef = db.collection('missions').doc(id);
      batch.set(docRef, data);
    }

    await batch.commit();
    console.log('✅ Restauration terminée avec succès');

  } catch (error) {
    console.error('❌ Erreur lors de la restauration:', error);
    throw error;
  }
}

// Fonction pour nettoyer les collections (en cas d'échec)
async function clearCollections() {
  console.log('🧹 Nettoyage des collections...');
  
  try {
    // Supprimer tous les oiseaux
    const oiseauxSnapshot = await db.collection('sons_oiseaux').get();
    const batchOiseaux = db.batch();
    oiseauxSnapshot.docs.forEach(doc => {
      batchOiseaux.delete(doc.ref);
    });
    await batchOiseaux.commit();

    // Supprimer toutes les missions
    const missionsSnapshot = await db.collection('missions').get();
    const batchMissions = db.batch();
    missionsSnapshot.docs.forEach(doc => {
      batchMissions.delete(doc.ref);
    });
    await batchMissions.commit();

    console.log('✅ Collections nettoyées');

  } catch (error) {
    console.error('❌ Erreur lors du nettoyage:', error);
    throw error;
  }
}

// Fonction principale d'import orchestré
async function importAll() {
  console.log('🚀 Début de l\'import complet des données...');
  console.log('📋 Ordre: Oiseaux → Missions');
  
  let backup = null;
  let currentStep = '';

  try {
    // Étape 1: Sauvegarde
    currentStep = 'sauvegarde';
    backup = await backupCurrentState();

    // Étape 2: Import des oiseaux
    currentStep = 'oiseaux';
    console.log('\n🦅 === IMPORT DES OISEAUX ===');
    const resultOiseaux = await importOiseaux();
    
    if (!resultOiseaux.success) {
      throw new Error('Échec de l\'import des oiseaux');
    }

    // Étape 3: Import des missions
    currentStep = 'missions';
    console.log('\n🎯 === IMPORT DES MISSIONS ===');
    const resultMissions = await importMissions();
    
    if (!resultMissions.success) {
      throw new Error('Échec de l\'import des missions');
    }

    // Succès complet !
    console.log('\n🎉 === IMPORT COMPLET RÉUSSI ===');
    console.log(`📊 Résumé:`);
    console.log(`  - Oiseaux: ${resultOiseaux.count} importés`);
    console.log(`  - Missions: ${resultMissions.count} importées`);
    console.log(`  - Erreurs: ${resultOiseaux.errors + resultMissions.errors}`);

    return {
      success: true,
      oiseaux: resultOiseaux,
      missions: resultMissions
    };

  } catch (error) {
    console.error(`\n💥 === ÉCHEC À L'ÉTAPE: ${currentStep} ===`);
    console.error('Erreur:', error.message);

    // Rollback automatique
    if (backup) {
      console.log('\n🔄 === ROLLBACK EN COURS ===');
      try {
        await clearCollections();
        await restoreFromBackup(backup);
        console.log('✅ Rollback terminé avec succès');
      } catch (rollbackError) {
        console.error('❌ ÉCHEC DU ROLLBACK:', rollbackError.message);
        console.error('⚠️ ATTENTION: L\'état de la base de données est INCONNU');
        console.error('🔧 Intervention manuelle requise');
      }
    }

    throw error;
  }
}

// Fonction pour vérifier l'état final
async function verifyImport() {
  console.log('\n🔍 === VÉRIFICATION DE L\'IMPORT ===');
  
  try {
    // Compter les oiseaux
    const oiseauxSnapshot = await db.collection('sons_oiseaux').get();
    console.log(`🦅 Oiseaux dans Firestore: ${oiseauxSnapshot.size}`);

    // Compter les missions
    const missionsSnapshot = await db.collection('missions').get();
    console.log(`🎯 Missions dans Firestore: ${missionsSnapshot.size}`);

    // Vérifier quelques exemples
    if (oiseauxSnapshot.size > 0) {
      const premierOiseau = oiseauxSnapshot.docs[0].data();
      console.log(`📝 Exemple oiseau: ${premierOiseau.nomFrancais} (${premierOiseau.idOiseau})`);
    }

    if (missionsSnapshot.size > 0) {
      const premiereMission = missionsSnapshot.docs[0].data();
      console.log(`📝 Exemple mission: ${premiereMission.titre} (${premiereMission.idMission})`);
    }

    console.log('✅ Vérification terminée');

  } catch (error) {
    console.error('❌ Erreur lors de la vérification:', error);
  }
}

// Exécution si appelé directement
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  
  if (args.includes('--verify')) {
    verifyImport()
      .then(() => process.exit(0))
      .catch(error => {
        console.error('💥 Échec de la vérification:', error);
        process.exit(1);
      });
  } else {
    importAll()
      .then(async (result) => {
        console.log('\n🔍 Vérification automatique...');
        await verifyImport();
        console.log('\n🎯 Import complet terminé avec succès !');
        process.exit(0);
      })
      .catch(error => {
        console.error('\n💥 Échec de l\'import complet:', error);
        process.exit(1);
      });
  }
}

export { importAll, verifyImport };
