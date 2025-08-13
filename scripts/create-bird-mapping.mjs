import { readFileSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel pour ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Lire le fichier Bank son oiseauxV2.csv
const csvContent = readFileSync(resolve(__dirname, '../assets/data/Bank son oiseauxV2.csv'), 'utf8');

// Parser le CSV
const lines = csvContent.split('\n');
const headers = lines[0].split(',');

// Créer le dictionnaire de correspondance
const birdMapping = {};
const reverseMapping = {};

console.log('🔄 Création du dictionnaire de correspondance des oiseaux...');

for (let i = 1; i < lines.length; i++) {
  const line = lines[i];
  if (!line.trim()) continue;
  
  const values = line.split(',');
  const id = values[0];
  const nomScientifique = values[1];
  const nomAnglais = values[2];
  const nomFrancais = values[3];
  
  // Ignorer les lignes sans ID ou nom français
  if (!id || !nomFrancais || id === 'ID') continue;
  
  // Créer la correspondance : nom français -> ID
  birdMapping[nomFrancais.trim()] = {
    id: id.trim(),
    nomScientifique: nomScientifique?.trim() || '',
    nomAnglais: nomAnglais?.trim() || '',
    nomFrancais: nomFrancais.trim()
  };
  
  // Créer aussi la correspondance inverse : ID -> nom français
  reverseMapping[id.trim()] = nomFrancais.trim();
}

console.log(`✅ ${Object.keys(birdMapping).length} correspondances créées`);

// Sauvegarder le mapping dans un fichier JSON
const mappingData = {
  frenchToId: birdMapping,
  idToFrench: reverseMapping,
  totalBirds: Object.keys(birdMapping).length,
  createdAt: new Date().toISOString()
};

writeFileSync(
  resolve(__dirname, '../assets/data/bird_mapping.json'),
  JSON.stringify(mappingData, null, 2),
  'utf8'
);

console.log('💾 Mapping sauvegardé dans assets/data/bird_mapping.json');

// Afficher quelques exemples
console.log('\n📋 Exemples de correspondances :');
const examples = Object.entries(birdMapping).slice(0, 5);
examples.forEach(([frenchName, data]) => {
  console.log(`  "${frenchName}" → ID: ${data.id}`);
});

console.log('\n🎯 Le mapping est prêt pour l\'import des missions !');
