import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('🧪 Test simple de lecture du CSV...');

try {
  const csvPath = resolve(__dirname, '../assets/data/Bank son oiseauxV1 - Bank son oiseauxV1.csv');
  console.log('📁 Chemin du fichier:', csvPath);
  
  const csvContent = readFileSync(csvPath, 'utf8');
  console.log('📄 Fichier lu, taille:', csvContent.length, 'caractères');
  
  const firstLines = csvContent.split('\n').slice(0, 3);
  console.log('📝 Premières lignes:');
  firstLines.forEach((line, index) => {
    console.log(`  ${index + 1}: ${line.substring(0, 100)}...`);
  });
  
  console.log('✅ Test de lecture réussi !');
} catch (error) {
  console.error('❌ Erreur:', error.message);
  process.exit(1);
}
