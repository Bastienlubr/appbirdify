#!/usr/bin/env node

/**
 * nettoyer_fiches_firestore.mjs
 * Script pour supprimer complètement des fiches d'oiseaux de Firestore
 * Réutilisable pour nettoyer toute espèce avant ré-enrichissement
 */

import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import admin from 'firebase-admin';

/**
 * Parse arguments ligne de commande
 */
function parseArgs() {
  const args = process.argv.slice(2);
  let nomFrancais = null;
  let nomScientifique = null;
  let idOiseau = null;
  let apply = false;
  let verbose = false;
  let all = false;

  for (const arg of args) {
    if (arg.startsWith('--nom-francais=')) nomFrancais = arg.split('=')[1];
    if (arg.startsWith('--nom-scientifique=')) nomScientifique = arg.split('=')[1];
    if (arg.startsWith('--id=')) idOiseau = arg.split('=')[1];
    if (arg === '--apply') apply = true;
    if (arg === '--verbose') verbose = true;
    if (arg === '--all') all = true;
  }

  return { nomFrancais, nomScientifique, idOiseau, apply, verbose, all };
}

/**
 * Affiche l'aide
 */
function afficherAide() {
  console.log(`
🧹 NETTOYAGE FICHES FIRESTORE

Usage:
  node scripts/fiches/nettoyer_fiches_firestore.mjs [OPTIONS]

Options de ciblage:
  --nom-francais="Torcol fourmilier"     Supprime par nom français
  --nom-scientifique="Jynx torquilla"    Supprime par nom scientifique  
  --id="o_123"                           Supprime par ID document
  --all                                  ⚠️ Supprime TOUTES les fiches

Options d'exécution:
  --apply                                Exécute vraiment (sinon dry-run)
  --verbose                              Mode détaillé

Exemples:
  # Dry-run Torcol fourmilier
  node scripts/fiches/nettoyer_fiches_firestore.mjs --nom-francais="Torcol fourmilier"
  
  # Suppression réelle
  node scripts/fiches/nettoyer_fiches_firestore.mjs --nom-francais="Torcol fourmilier" --apply
  
  # Par nom scientifique
  node scripts/fiches/nettoyer_fiches_firestore.mjs --nom-scientifique="Jynx torquilla" --apply

⚠️ ATTENTION: Les suppressions sont DÉFINITIVES !
  `);
}

/**
 * Initialisation Firebase
 */
async function initFirebase() {
  try {
    const serviceAccount = JSON.parse(await readFile(resolve('serviceAccountKey.json'), 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: `https://${serviceAccount.project_id}-default-rtdb.firebaseio.com/`
    });
    return admin.firestore();
  } catch (error) {
    console.error('❌ Erreur Firebase:', error.message);
    process.exit(1);
  }
}

/**
 * Recherche de fiches par critères
 */
async function rechercherFiches(db, criteres, verbose) {
  const { nomFrancais, nomScientifique, idOiseau, all } = criteres;
  
  try {
    const collection = db.collection('fiches_oiseaux');
    let query;
    let fiches = [];
    
    if (all) {
      // TOUTES les fiches (DANGEREUX)
      if (verbose) console.log('🔍 Recherche de TOUTES les fiches...');
      const snapshot = await collection.get();
      snapshot.forEach(doc => {
        fiches.push({
          id: doc.id,
          data: doc.data()
        });
      });
      
    } else if (idOiseau) {
      // Par ID direct
      if (verbose) console.log(`🔍 Recherche par ID: ${idOiseau}`);
      const doc = await collection.doc(idOiseau).get();
      if (doc.exists) {
        fiches.push({
          id: doc.id,
          data: doc.data()
        });
      }
      
    } else if (nomScientifique) {
      // Par nom scientifique
      if (verbose) console.log(`🔍 Recherche par nom scientifique: ${nomScientifique}`);
      const snapshot = await collection
        .where('nomScientifique', '==', nomScientifique)
        .get();
      
      snapshot.forEach(doc => {
        fiches.push({
          id: doc.id,
          data: doc.data()
        });
      });
      
    } else if (nomFrancais) {
      // Par nom français
      if (verbose) console.log(`🔍 Recherche par nom français: ${nomFrancais}`);
      const snapshot = await collection
        .where('nomFrancais', '==', nomFrancais)
        .get();
      
      snapshot.forEach(doc => {
        fiches.push({
          id: doc.id,
          data: doc.data()
        });
      });
    }
    
    return fiches;
    
  } catch (error) {
    console.error('❌ Erreur recherche:', error.message);
    return [];
  }
}

/**
 * Suppression des fiches
 */
async function supprimerFiches(db, fiches, apply, verbose) {
  if (fiches.length === 0) {
    console.log('ℹ️ Aucune fiche trouvée à supprimer');
    return { success: true, deleted: 0 };
  }
  
  console.log(`\n📋 Fiches trouvées (${fiches.length}):`);
  fiches.forEach((fiche, index) => {
    const data = fiche.data;
    console.log(`  ${index + 1}. ${fiche.id}`);
    console.log(`     - Nom français: ${data.nomFrancais || 'N/A'}`);
    console.log(`     - Nom scientifique: ${data.nomScientifique || 'N/A'}`);
    console.log(`     - Créé le: ${data.metadata?.dateCreation ? new Date(data.metadata.dateCreation).toLocaleDateString('fr-FR') : 'N/A'}`);
  });
  
  if (!apply) {
    console.log('\n[DRY-RUN] Suppression simulée (utilisez --apply pour exécuter)');
    return { success: true, deleted: 0 };
  }
  
  // Confirmation suppression
  console.log('\n⚠️ SUPPRESSION DÉFINITIVE EN COURS...');
  
  const collection = db.collection('fiches_oiseaux');
  const batch = db.batch();
  let deleted = 0;
  
  try {
    // Préparation batch
    fiches.forEach(fiche => {
      const docRef = collection.doc(fiche.id);
      batch.delete(docRef);
    });
    
    // Exécution
    await batch.commit();
    deleted = fiches.length;
    
    console.log(`✅ ${deleted} fiche(s) supprimée(s) avec succès`);
    
    // Vérification post-suppression
    if (verbose) {
      console.log('\n🔍 Vérification post-suppression...');
      for (const fiche of fiches) {
        const doc = await collection.doc(fiche.id).get();
        const existe = doc.exists;
        console.log(`  - ${fiche.id}: ${existe ? '❌ Encore présent' : '✅ Supprimé'}`);
      }
    }
    
    return { success: true, deleted };
    
  } catch (error) {
    console.error('❌ Erreur suppression:', error.message);
    return { success: false, deleted: 0 };
  }
}

/**
 * Script principal
 */
async function main() {
  const args = parseArgs();
  
  // Vérification arguments
  if (!args.nomFrancais && !args.nomScientifique && !args.idOiseau && !args.all) {
    afficherAide();
    process.exit(1);
  }
  
  console.log('🧹 NETTOYAGE FICHES FIRESTORE');
  console.log('===============================');
  
  // Avertissement pour --all
  if (args.all) {
    console.log('⚠️ ⚠️ ⚠️ MODE DANGEREUX: TOUTES LES FICHES ⚠️ ⚠️ ⚠️');
    if (!args.apply) {
      console.log('🛡️ Mode dry-run activé (heureusement!)');
    } else {
      console.log('💀 SUPPRESSION RÉELLE DE TOUTES LES FICHES !');
    }
  }
  
  // Récapitulatif
  console.log('\n🎯 Critères de recherche:');
  if (args.nomFrancais) console.log(`  - Nom français: "${args.nomFrancais}"`);
  if (args.nomScientifique) console.log(`  - Nom scientifique: "${args.nomScientifique}"`);
  if (args.idOiseau) console.log(`  - ID: "${args.idOiseau}"`);
  if (args.all) console.log(`  - ⚠️ TOUTES les fiches`);
  console.log(`  - Mode: ${args.apply ? '🔥 SUPPRESSION RÉELLE' : '👁️ DRY-RUN'}`);
  
  // Initialisation Firebase
  const db = await initFirebase();
  
  // Recherche des fiches
  const fiches = await rechercherFiches(db, args, args.verbose);
  
  // Suppression
  const resultat = await supprimerFiches(db, fiches, args.apply, args.verbose);
  
  // Bilan final
  console.log('\n📊 BILAN:');
  console.log(`  - Fiches trouvées: ${fiches.length}`);
  console.log(`  - Fiches supprimées: ${resultat.deleted}`);
  console.log(`  - Statut: ${resultat.success ? '✅ Succès' : '❌ Erreur'}`);
  
  if (args.apply && resultat.deleted > 0) {
    console.log('\n💡 Prochaine étape suggérée:');
    console.log('   node scripts/fiches/enrichir_hybride_wikipedia_ia.mjs --nom-francais="..." --apply');
  }
  
  process.exit(resultat.success ? 0 : 1);
}

main().catch(error => {
  console.error('❌ Erreur fatale:', error);
  process.exit(1);
});
