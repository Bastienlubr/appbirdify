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

async function cleanupFirestore() {
  try {
    console.log('🧹 Début du nettoyage complet de Firestore...');
    console.log(`📁 Projet: ${serviceAccount.project_id}`);
    
    // 1. Supprimer complètement la collection sessions
    console.log('\n🗑️ Suppression de la collection sessions...');
    const usersSnapshot = await db.collection('utilisateurs').get();
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      console.log(`   👤 Utilisateur: ${uid}`);
      
      const sessionsSnapshot = await db
        .collection('utilisateurs')
        .doc(uid)
        .collection('sessions')
        .get();
      
      if (!sessionsSnapshot.empty) {
        console.log(`      📝 Suppression de ${sessionsSnapshot.docs.length} sessions...`);
        
        // Supprimer tous les documents de sessions
        const batch = db.batch();
        sessionsSnapshot.docs.forEach(doc => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        
        console.log(`      ✅ ${sessionsSnapshot.docs.length} sessions supprimées`);
      } else {
        console.log(`      ℹ️ Aucune session à supprimer`);
      }
    }
    
    // 2. Nettoyer les champs inutiles dans progression_missions
    console.log('\n🧹 Nettoyage des champs inutiles dans progression_missions...');
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      console.log(`   👤 Utilisateur: ${uid}`);
      
      const missionsSnapshot = await db
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .get();
      
      if (!missionsSnapshot.empty) {
        console.log(`      📋 Nettoyage de ${missionsSnapshot.docs.length} missions...`);
        
        for (const missionDoc of missionsSnapshot.docs) {
          const missionId = missionDoc.id;
          const data = missionDoc.data();
          
          console.log(`         🎯 Mission: ${missionId}`);
          
          // Champs à supprimer
          const fieldsToRemove = [
            'meilleurScore',
            'reponsesCorrectes', 
            'reponsesIncorrectes',
            'tauxReussite',
            'tempsHistorique',
            'tempsMoyen',
            'derniereDuree',
            'totalQuestions'
          ];
          
          // Champs à conserver et nettoyer
          const fieldsToKeep = {
            'etoiles': 0, // Remettre à 0
            'tentatives': 0, // Remettre à 0
            'deverrouille': missionId === 'U01', // U01 déverrouillé, autres verrouillées
            'creeLe': data.creeLe || new Date(),
            'derniereMiseAJour': new Date(),
            'scoresHistorique': {}, // Map vide pour les oiseaux manqués
            'scoresPourcentagesPasses': [], // Liste vide pour les scores
            'moyenneScores': 0.0, // Moyenne à 0
          };
          
          // Ajouter des champs spécifiques pour U01
          if (missionId === 'U01') {
            fieldsToKeep.deverrouilleLe = new Date();
            fieldsToKeep.biome = 'U';
            fieldsToKeep.index = 1;
          } else {
            // Pour les autres missions, les verrouiller
            fieldsToKeep.deverrouille = false;
            fieldsToKeep.biome = missionId[0];
            fieldsToKeep.index = parseInt(missionId.substring(1));
          }
          
          // Mettre à jour le document
          await missionDoc.ref.set(fieldsToKeep);
          
          console.log(`            ✅ Nettoyée et remise à zéro`);
        }
      } else {
        console.log(`      ℹ️ Aucune mission à nettoyer`);
      }
    }
    
    console.log('\n🎉 Nettoyage terminé avec succès !');
    console.log('\n📊 Résumé des actions :');
    console.log('   ✅ Collection sessions supprimée');
    console.log('   ✅ Champs inutiles supprimés de progression_missions');
    console.log('   ✅ Statistiques remises à zéro');
    console.log('   ✅ U01 déverrouillé, autres missions verrouillées');
    console.log('   ✅ scoresHistorique converti en Map vide');
    console.log('   ✅ scoresPourcentagesPasses converti en liste vide');
    
  } catch (error) {
    console.error('❌ Erreur lors du nettoyage:', error);
  }
}

cleanupFirestore();
