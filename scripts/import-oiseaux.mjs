import { parse } from 'csv-parse/sync';
import { readFileSync } from 'fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
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
  if (error.code !== 'app/duplicate-app') {
    throw error;
  }
}

const db = getFirestore();

// Mapping des habitats vers biomes standardisés
const BIOME_MAPPING = {
  urbain: ['urbain', 'ville', 'urban', 'city', 'parc urbain', 'jardin urbain'],
  forestier: ['forestier', 'forêt', 'forest', 'bois', 'woodland', 'forêt mixte'],
  agricole: ['agricole', 'champ', 'field', 'prairie', 'zone agricole', 'ferme'],
  humide: ['humide', 'marais', 'marsh', 'étang', 'pond', 'zone humide', 'roselière'],
  montagnard: ['montagnard', 'montagne', 'mountain', 'alpin', 'alpine', 'haute altitude'],
  littoral: ['littoral', 'côte', 'coast', 'plage', 'beach', 'falaises', 'cliffs'],
  jardin: ['jardin', 'garden', 'parc', 'park', 'espace vert'],
  mixte: ['mixte', 'mixed', 'divers', 'various', 'multiple']
};

function mapHabitatToBiome(habitat) {
  if (!habitat) return 'mixte';
  const habitatLower = habitat.toLowerCase().trim();
  for (const [biome, keywords] of Object.entries(BIOME_MAPPING)) {
    if (keywords.some(keyword => habitatLower.includes(keyword))) {
      return biome;
    }
  }
  return 'mixte';
}

function cleanUrl(url) {
  if (!url || url.trim() === '') return null;
  const clean = url.trim();
  if (clean.startsWith('./') || clean.startsWith('../') || !clean.startsWith('http')) return clean;
  try { new URL(clean); return clean; } catch { return null; }
}

// Fonction pour traiter un oiseau (supporte V4 et fallback V1)
function processOiseau(row) {
  const rawId = row.id_oiseaux ?? row.ID; // V4 ou V1
  const id = rawId?.toString().trim();
  if (!id) {
    return null;
  }

  const habitatPrincipal = mapHabitatToBiome(row.Habitat_principal);
  const habitatSecondaire = mapHabitatToBiome(row.Habitat_secondaire);
  const biomes = [...new Set([habitatPrincipal, habitatSecondaire])].filter(b => b !== 'mixte');
  if (biomes.length === 0) biomes.push('mixte');

  const urlAudio = cleanUrl(row.LienURL);
  const urlImage = cleanUrl(row.photo);

  return {
    idOiseau: `o_${id}`,
    espece: row.Nom_scientifique?.trim() || '',
    nomFrancais: row.Nom_français?.trim() || row.Nom_francais?.trim() || '',
    nomAnglais: row.Nom_anglais?.trim() || '',
    urlAudio,
    urlImage,
    biomes,
    typeSon: row.Type?.trim()?.toLowerCase() || 'call',
    misAJourLe: new Date().toISOString()
  };
}

async function importOiseaux() {
  console.log('🦅 Début de l\'import des oiseaux...');
  try {
    // Utiliser V4 par défaut
    const csvPath = resolve(__dirname, '../assets/data/Bank son oiseauxV4.csv');
    console.log(`📖 Lecture du fichier: ${csvPath}`);

    const csvContent = readFileSync(csvPath, 'utf8');
    const records = parse(csvContent, { columns: true, skip_empty_lines: true, trim: true });
    console.log(`📊 ${records.length} oiseaux détectés dans le CSV`);

    const oiseaux = [];
    for (const record of records) {
      const oiseau = processOiseau(record);
      if (oiseau) oiseaux.push(oiseau);
    }

    console.log(`✅ ${oiseaux.length} oiseaux traités avec succès`);

    console.log('🔥 Import en cours dans Firestore...');
    const batch = db.batch();
    let successCount = 0;
    for (const oiseau of oiseaux) {
      const docRef = db.collection('sons_oiseaux').doc(oiseau.idOiseau);
      batch.set(docRef, oiseau, { merge: true });
      successCount++;
    }
    if (successCount > 0) await batch.commit();

    console.log(`🎉 Import réussi: ${successCount} oiseaux importés`);
    console.log('✅ Import des oiseaux terminé avec succès !');
    return { success: true, count: successCount };
  } catch (error) {
    console.error('❌ Erreur lors de l\'import:', error);
    throw error;
  }
}

if (import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/'))) {
  console.log('🚀 Démarrage du script d\'import des oiseaux (V4)...');
  importOiseaux()
    .then(result => { console.log('🎯 Résultat final:', result); process.exit(0); })
    .catch(error => { console.error('💥 Erreur fatale:', error); process.exit(1); });
}

export { importOiseaux };
