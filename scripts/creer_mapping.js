#!/usr/bin/env node

/**
 * Script de création du mapping entre oiseaux et fiches
 * 
 * Ce script analyse les données existantes et crée un mapping
 * entre les oiseaux de l'app et les fiches dans Firestore
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
 * Normalise un nom scientifique pour la comparaison
 */
function normaliserNomScientifique(nom) {
  if (!nom) return '';
  return nom.toLowerCase()
    .replace(/[^\w\s]/g, '') // Supprimer la ponctuation
    .replace(/\s+/g, ' ')    // Normaliser les espaces
    .trim();
}

/**
 * Normalise un nom français pour la comparaison
 */
function normaliserNomFrancais(nom) {
  if (!nom) return '';
  return nom.toLowerCase()
    .replace(/[^\w\s]/g, '') // Supprimer la ponctuation
    .replace(/\s+/g, ' ')    // Normaliser les espaces
    .trim();
}

/**
 * Trouve la meilleure correspondance entre un oiseau et une fiche
 */
function trouverCorrespondance(oiseau, fiches) {
  let meilleureCorrespondance = null;
  let meilleurScore = 0;

  for (const fiche of fiches) {
    let score = 0;

    // Correspondance par nom scientifique
    const nomSciOiseau = normaliserNomScientifique(`${oiseau.genus} ${oiseau.species}`);
    const nomSciFiche = normaliserNomScientifique(fiche.nomScientifique);
    
    if (nomSciOiseau === nomSciFiche) {
      score += 100; // Correspondance parfaite
    } else if (nomSciOiseau.includes(nomSciFiche) || nomSciFiche.includes(nomSciOiseau)) {
      score += 80; // Correspondance partielle
    }

    // Correspondance par nom français
    const nomFrOiseau = normaliserNomFrancais(oiseau.nomFr);
    const nomFrFiche = normaliserNomFrancais(fiche.nomFrancais);
    
    if (nomFrOiseau === nomFrFiche) {
      score += 90; // Correspondance parfaite
    } else if (nomFrOiseau.includes(nomFrFiche) || nomFrFiche.includes(nomFrOiseau)) {
      score += 70; // Correspondance partielle
    }

    // Correspondance par genre
    if (oiseau.genus.toLowerCase() === fiche.nomScientifique.split(' ')[0]?.toLowerCase()) {
      score += 30;
    }

    if (score > meilleurScore) {
      meilleurScore = score;
      meilleureCorrespondance = fiche;
    }
  }

  return { fiche: meilleureCorrespondance, score: meilleurScore };
}

/**
 * Crée le mapping entre oiseaux et fiches
 */
async function creerMapping() {
  try {
    console.log('🔍 Début de la création du mapping...\n');
    
    // 1. Récupérer les fiches oiseaux depuis Firestore
    console.log('📊 Récupération des fiches oiseaux depuis Firestore...');
    const fichesSnapshot = await db.collection('fiches_oiseaux').get();
    const fiches = [];
    
    for (const doc of fichesSnapshot.docs) {
      try {
        const data = doc.data();
        fiches.push({
          id: doc.id,
          nomScientifique: data.nomScientifique || '',
          nomFrancais: data.nomFrancais || '',
          ...data
        });
      } catch (e) {
        console.error(`❌ Erreur parsing fiche ${doc.id}:`, e.message);
      }
    }
    
    console.log(`✅ ${fiches.length} fiches récupérées depuis Firestore\n`);
    
    // 2. Lire les données des oiseaux depuis le CSV
    console.log('📁 Lecture des données des oiseaux depuis le CSV...');
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
    const oiseaux = [];
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
        
        // Extraire les informations de l'oiseau
        const nomScientifique = ligne.Nom_scientifique || ligne.nom_scientifique || '';
        const parts = nomScientifique.split(' ');
        const genus = parts.length > 0 ? parts[0] : '';
        const species = parts.length > 1 ? parts[1] : '';
        
        const oiseau = {
          id: ligne.id_oiseaux || ligne.ID || `o_${i}`,
          genus: genus,
          species: species,
          nomFr: ligne.Nom_français || ligne.nom_francais || '',
          nomScientifique: nomScientifique,
          urlMp3: ligne.LienURL || '',
          urlImage: ligne.photo || '',
          habitat: ligne.Habitat_principal || ligne.habitat || '',
          habitatSecondaire: ligne.Habitat_secondaire || '',
          famille: ligne.Famille || ligne.famille || '',
          ordre: ligne.Ordre || ligne.ordre || ''
        };
        
        oiseaux.push(oiseau);
        
        ligneCount++;
        if (ligneCount % 50 === 0) {
          console.log(`📊 ${ligneCount} lignes traitées...`);
        }
        
      } catch (e) {
        console.error(`❌ Erreur ligne ${i + 1}:`, e.message);
      }
    }
    
    console.log(`✅ ${oiseaux.length} oiseaux extraits du CSV\n`);
    
    // 3. Créer le mapping
    console.log('🔗 Création du mapping entre oiseaux et fiches...');
    const mapping = [];
    let correspondancesParfaites = 0;
    let correspondancesPartielles = 0;
    let sansCorrespondance = 0;
    
    for (const oiseau of oiseaux) {
      const correspondance = trouverCorrespondance(oiseau, fiches);
      
      if (correspondance.fiche) {
        if (correspondance.score >= 90) {
          correspondancesParfaites++;
        } else {
          correspondancesPartielles++;
        }
        
        mapping.push({
          oiseauId: oiseau.id,
          ficheId: correspondance.fiche.id,
          nomFrancais: oiseau.nomFr,
          nomScientifique: oiseau.nomScientifique,
          score: correspondance.score,
          type: correspondance.score >= 90 ? 'parfaite' : 'partielle',
          oiseau: {
            id: oiseau.id,
            genus: oiseau.genus,
            species: oiseau.species,
            nomFr: oiseau.nomFr,
            urlMp3: oiseau.urlMp3,
            urlImage: oiseau.urlImage,
            habitat: oiseau.habitat,
            habitatSecondaire: oiseau.habitatSecondaire,
            famille: oiseau.famille,
            ordre: oiseau.ordre
          },
          fiche: {
            id: correspondance.fiche.id,
            nomScientifique: correspondance.fiche.nomScientifique,
            nomFrancais: correspondance.fiche.nomFrancais,
            famille: correspondance.fiche.famille,
            ordre: correspondance.fiche.ordre
          }
        });
      } else {
        sansCorrespondance++;
        mapping.push({
          oiseauId: oiseau.id,
          ficheId: null,
          nomFrancais: oiseau.nomFr,
          nomScientifique: oiseau.nomScientifique,
          score: 0,
          type: 'aucune',
          oiseau: {
            id: oiseau.id,
            genus: oiseau.genus,
            species: oiseau.species,
            nomFr: oiseau.nomFr,
            urlMp3: oiseau.urlMp3,
            urlImage: oiseau.urlImage,
            habitat: oiseau.habitat,
            habitatSecondaire: oiseau.habitatSecondaire,
            famille: oiseau.famille,
            ordre: oiseau.ordre
          },
          fiche: null
        });
      }
    }
    
    console.log('\n📊 Statistiques du mapping :');
    console.log(`✅ Correspondances parfaites: ${correspondancesParfaites}`);
    console.log(`🔄 Correspondances partielles: ${correspondancesPartielles}`);
    console.log(`❌ Sans correspondance: ${sansCorrespondance}`);
    console.log(`📈 Taux de correspondance: ${((correspondancesParfaites + correspondancesPartielles) / oiseaux.length * 100).toFixed(1)}%`);
    
    // 4. Sauvegarder le mapping
    console.log('\n💾 Sauvegarde du mapping...');
    
    // Sauvegarder en JSON
    const mappingPath = path.join(__dirname, 'oiseaux_mapping.json');
    fs.writeFileSync(mappingPath, JSON.stringify(mapping, null, 2));
    console.log(`✅ Mapping sauvegardé dans: ${mappingPath}`);
    
    // Sauvegarder dans Firestore
    const mappingCollection = db.collection('oiseaux_mapping');
    const batch = db.batch();
    
    for (const item of mapping) {
      const docRef = mappingCollection.doc(item.oiseauId);
      batch.set(docRef, {
        ...item,
        dateCreation: new Date().toISOString(),
        version: '1.0'
      });
    }
    
    await batch.commit();
    console.log('✅ Mapping sauvegardé dans Firestore');
    
    // 5. Créer un fichier de mapping optimisé pour l'app
    console.log('\n📱 Création du mapping optimisé pour l\'app...');
    const mappingOptimise = {};
    
    for (const item of mapping) {
      if (item.ficheId) {
        mappingOptimise[item.oiseauId] = {
          ficheId: item.ficheId,
          score: item.score,
          type: item.type
        };
      }
    }
    
    const mappingOptimisePath = path.join(__dirname, 'oiseaux_recherche_rapide.json');
    fs.writeFileSync(mappingOptimisePath, JSON.stringify(mappingOptimise, null, 2));
    console.log(`✅ Mapping optimisé sauvegardé dans: ${mappingOptimisePath}`);
    
    console.log('\n🎉 Mapping terminé avec succès !');
    
  } catch (e) {
    console.error('❌ Erreur lors de la création du mapping:', e);
  }
}

// Exécuter le script
if (require.main === module) {
  creerMapping()
    .then(() => {
      console.log('\n✨ Script terminé');
      process.exit(0);
    })
    .catch((e) => {
      console.error('💥 Erreur fatale:', e);
      process.exit(1);
    });
}

module.exports = { creerMapping, trouverCorrespondance };
