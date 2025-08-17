#!/usr/bin/env node

/**
 * Script de nettoyage et réimport avec les bons IDs
 * 
 * Ce script nettoie Firestore et réimporte les données
 * avec les IDs corrects du CSV
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialiser Firebase Admin
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'birdify-df029'
});

const db = admin.firestore();

/**
 * Normalise un nom d'habitat
 */
function normaliserHabitat(habitat) {
  if (!habitat) return [];
  
  const habitats = habitat.toLowerCase().split(',').map(h => h.trim());
  const mapping = {
    'milieu urbain': 'milieu urbain',
    'milieu forestier': 'milieu forestier',
    'milieu agricole': 'milieu agricole',
    'milieu humide': 'milieu humide',
    'milieu montagnard': 'milieu montagnard',
    'milieu littoral': 'milieu littoral',
    'urbain': 'milieu urbain',
    'forestier': 'milieu forestier',
    'agricole': 'milieu agricole',
    'humide': 'milieu humide',
    'montagnard': 'milieu montagnard',
    'littoral': 'milieu littoral'
  };

  return habitats
    .map(h => mapping[h] || h)
    .filter(h => h && h.length > 0)
    .filter((h, index, arr) => arr.indexOf(h) === index); // Supprimer les doublons
}

/**
 * Crée une fiche oiseau depuis une ligne CSV avec le bon ID
 */
function creerFicheOiseau(ligne) {
  // Utiliser l'ID exact du CSV pour la correspondance et s'assurer qu'il est valide pour Firestore
  let rawId = ligne.id_oiseaux || ligne.ID || ligne.o_ID;
  let idOiseau;
  
  if (rawId) {
    // Nettoyer l'ID et s'assurer qu'il commence par une lettre
    const cleanId = rawId.toString().replace(/[^a-zA-Z0-9_-]/g, '_');
    idOiseau = cleanId.startsWith('o_') ? cleanId : `o_${cleanId}`;
  } else {
    idOiseau = `o_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
  
  return {
    idOiseau: idOiseau,
    nomFrancais: ligne.Nom_français || ligne.nom_francais || 'Nom inconnu',
    nomAnglais: ligne.Nom_anglais || ligne.nom_anglais || null,
    nomScientifique: ligne.Nom_scientifique || ligne.nom_scientifique || 'Nom scientifique inconnu',
    famille: ligne.Famille || ligne.famille || 'Famille inconnue',
    ordre: ligne.Ordre || ligne.ordre || 'Ordre inconnu',
    
    // Taille
    taille: {
      longueur: ligne.longueur || null,
      envergure: ligne.envergure || null,
      description: ligne.description_taille || null
    },
    
    // Poids
    poids: {
      poidsMoyen: ligne.poids_moyen || null,
      variation: ligne.variation_poids || null,
      description: ligne.description_poids || null
    },
    
    longevite: ligne.longevite || null,
    
    // Identification
    identification: {
      description: ligne.description_identification || null,
      dimorphismeSexuel: ligne.dimorphisme_sexuel || null,
      plumageEte: ligne.plumage_ete || null,
      plumageHiver: ligne.plumage_hiver || null,
      especesSimilaires: ligne.especes_similaires || null,
      caracteristiques: ligne.caracteristiques || null
    },
    
    // Habitat
    habitat: {
      milieux: normaliserHabitat(ligne.Habitat_principal || ligne.habitat),
      altitude: ligne.altitude || null,
      vegetation: ligne.vegetation || null,
      saisonnalite: ligne.saisonnalite || null,
      description: ligne.description_habitat || null
    },
    
    // Alimentation
    alimentation: {
      regimePrincipal: ligne.regime_alimentaire || null,
      proiesPrincipales: ligne.proies_principales ? ligne.proies_principales.split(',').map(p => p.trim()) : [],
      techniquesChasse: ligne.techniques_chasse ? ligne.techniques_chasse.split(',').map(t => t.trim()) : [],
      comportementAlimentaire: ligne.comportement_alimentaire || null,
      description: ligne.description_alimentation || null
    },
    
    // Reproduction
    reproduction: {
      saisonReproduction: ligne.saison_reproduction || null,
      typeNid: ligne.type_nid || null,
      nombreOeufs: ligne.nombre_oeufs || null,
      dureeIncubation: ligne.duree_incubation || null,
      description: ligne.description_reproduction || null
    },
    
    // Répartition
    repartition: {
      statutPresence: 'Présent',
      periodes: {
        printemps: 'Présent',
        ete: 'Présent',
        automne: 'Présent',
        hiver: 'Présent'
      },
      noteMigration: ligne.note_migration || null,
      description: ligne.description_repartition || null
    },
    
    // Vocalisations
    vocalisations: {
      chantTerritorial: ligne.chant_territorial || null,
      crisAlarme: ligne.cris_alarme || null,
      crisContact: ligne.cris_contact || null,
      description: ligne.description_vocalisations || null,
      fichierAudio: ligne.LienURL || ligne.fichier_audio || null
    },
    
    // Comportement
    comportement: {
      modeVie: ligne.mode_vie || null,
      territorialite: ligne.territorialite || null,
      sociabilite: ligne.sociabilite || null,
      description: ligne.description_comportement || null
    },
    
    // Conservation
    conservation: {
      statutIUCN: ligne.statut_iucn || null,
      protectionLegale: ligne.protection_legale || null,
      menaces: ligne.menaces || null,
      actionsProtection: ligne.actions_protection || null,
      description: ligne.description_conservation || null
    },
    
    // Médias
    medias: {
      imagePrincipale: ligne.photo || ligne.image_principale || null,
      images: ligne.images ? ligne.images.split(',').map(i => i.trim()) : [],
      video: ligne.video || null,
      description: ligne.description_medias || null
    },
    
    // Sources
    sources: {
      references: ligne.references ? ligne.references.split(',').map(r => r.trim()) : [],
      dateMiseAJour: new Date().toISOString(),
      description: ligne.description_sources || null
    },
    
    // Métadonnées
    metadata: {
      dateCreation: new Date().toISOString(),
      dateModification: new Date().toISOString(),
      version: '1.0',
      statut: 'actif',
      notes: ligne.notes || null
    }
  };
}

/**
 * Nettoie et réimporte les fiches oiseaux
 */
async function nettoyerEtReimporter() {
  try {
    console.log('🧹 Début du nettoyage et réimport...\n');
    
    // 1. Nettoyer la collection fiches_oiseaux
    console.log('🗑️ Nettoyage de la collection fiches_oiseaux...');
    const fichesSnapshot = await db.collection('fiches_oiseaux').get();
    
    if (!fichesSnapshot.empty) {
      const batch = db.batch();
      fichesSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`✅ ${fichesSnapshot.docs.length} fiches supprimées`);
    } else {
      console.log('✅ Collection déjà vide');
    }
    
    // 2. Lire le fichier CSV
    console.log('\n📁 Lecture du fichier CSV...');
    const csvPath = path.join(__dirname, '..', 'assets', 'data', 'Bank son oiseauxV4.csv');
    
    if (!fs.existsSync(csvPath)) {
      console.error('❌ Fichier CSV non trouvé:', csvPath);
      return;
    }
    
    const csvContent = fs.readFileSync(csvPath, 'utf-8');
    const lines = csvContent.split('\n');
    
    if (lines.length < 2) {
      console.error('❌ CSV vide ou invalide');
      return;
    }
    
    // Parser les en-têtes
    const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''));
    console.log('📋 En-têtes détectés:', headers.length);
    
    // Parser les lignes de données
    const fiches = [];
    let ligneCount = 0;
    
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      
      try {
        // Parser la ligne CSV
        const values = [];
        let current = '';
        let inQuotes = false;
        
        for (let j = 0; j < line.length; j++) {
          const char = line[j];
          
          if (char === '"') {
            inQuotes = !inQuotes;
          } else if (char === ',' && !inQuotes) {
            values.push(current.trim());
            current = '';
          } else {
            current += char;
          }
        }
        values.push(current.trim());
        
        // Créer l'objet ligne
        const ligne = {};
        headers.forEach((header, index) => {
          if (index < values.length) {
            ligne[header] = values[index].replace(/"/g, '');
          }
        });
        
        // Créer la fiche oiseau
        const fiche = creerFicheOiseau(ligne);
        fiches.push(fiche);
        
        ligneCount++;
        if (ligneCount % 50 === 0) {
          console.log(`📊 ${ligneCount} lignes traitées...`);
        }
        
      } catch (e) {
        console.error(`❌ Erreur ligne ${i + 1}:`, e.message);
      }
    }
    
    console.log(`\n✅ ${fiches.length} fiches créées à partir du CSV`);
    
    if (fiches.length === 0) {
      console.log('❌ Aucune fiche à importer');
      return;
    }
    
    // 3. Importer dans Firestore avec les bons IDs
    console.log('\n🔥 Import dans Firestore avec les bons IDs...');
    
    const batchSize = 500;
    let successCount = 0;
    let errorCount = 0;
    
    for (let i = 0; i < fiches.length; i += batchSize) {
      const batch = db.batch();
      const endIndex = Math.min(i + batchSize, fiches.length);
      
      for (let j = i; j < endIndex; j++) {
        const fiche = fiches[j];
        const docRef = db.collection('fiches_oiseaux').doc(fiche.idOiseau);
        batch.set(docRef, fiche, { merge: true });
      }
      
      try {
        await batch.commit();
        successCount += endIndex - i;
        console.log(`✅ Lot ${Math.floor(i / batchSize) + 1}/${Math.ceil(fiches.length / batchSize)}: ${endIndex - i} fiches importées`);
      } catch (e) {
        errorCount += endIndex - i;
        console.error(`❌ Erreur lot ${Math.floor(i / batchSize) + 1}:`, e.message);
      }
    }
    
    console.log('\n🎉 Nettoyage et réimport terminés !');
    console.log(`✅ Succès: ${successCount} fiches`);
    console.log(`❌ Erreurs: ${errorCount} fiches`);
    console.log(`📊 Total traité: ${fiches.length} fiches`);
    
    // Vérifier le nombre de documents dans Firestore
    const snapshot = await db.collection('fiches_oiseaux').count().get();
    console.log(`🔥 Documents dans Firestore: ${snapshot.data().count}`);
    
    // Afficher quelques exemples d'IDs
    console.log('\n📋 Exemples d\'IDs utilisés:');
    fiches.slice(0, 5).forEach(fiche => {
      console.log(`  - ${fiche.idOiseau}: ${fiche.nomFrancais}`);
    });
    
  } catch (e) {
    console.error('❌ Erreur lors du nettoyage et réimport:', e);
  }
}

// Exécuter le script
if (require.main === module) {
  nettoyerEtReimporter()
    .then(() => {
      console.log('\n✨ Script terminé');
      process.exit(0);
    })
    .catch((e) => {
      console.error('💥 Erreur fatale:', e);
      process.exit(1);
    });
}

module.exports = { nettoyerEtReimporter, creerFicheOiseau };
