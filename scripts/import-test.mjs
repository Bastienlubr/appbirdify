import { parse } from 'csv-parse/sync';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('🧪 Test d\'import simplifié...');
console.log('📁 __dirname:', __dirname);
console.log('🔗 import.meta.url:', import.meta.url);
console.log('📝 process.argv[1]:', process.argv[1]);

// Test de lecture CSV
try {
  const csvPath = resolve(__dirname, '../assets/data/Bank son oiseauxV1 - Bank son oiseauxV1.csv');
  console.log('📁 Chemin CSV:', csvPath);
  
  const csvContent = readFileSync(csvPath, 'utf8');
  const records = parse(csvContent, { columns: true, skip_empty_lines: true, trim: true });
  
  console.log(`📊 ${records.length} enregistrements lus`);
  console.log('📝 Premier enregistrement:', records[0]);
  
  console.log('✅ Test CSV réussi !');
} catch (error) {
  console.error('❌ Erreur CSV:', error.message);
}

console.log('�� Script terminé');
