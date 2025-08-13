import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('🔥 Test de connexion Firebase...');

try {
  // Configuration Firebase Admin
  const serviceAccount = JSON.parse(
    readFileSync(resolve(__dirname, '../serviceAccountKey.json'), 'utf8')
  );

  console.log('📋 Service account chargé');

  // Initialiser Firebase Admin SDK
  try {
    initializeApp({
      credential: cert(serviceAccount)
    });
    console.log('✅ Firebase Admin initialisé');
  } catch (error) {
    // Si l'app est déjà initialisée, on continue
    if (error.code !== 'app/duplicate-app') {
      throw error;
    }
    console.log('ℹ️ Firebase Admin déjà initialisé');
  }

  const db = getFirestore();
  console.log('📡 Connexion Firestore établie');

  // Test simple d'écriture
  console.log('✍️ Test d\'écriture...');
  const testRef = db.collection('test').doc('ping');
  await testRef.set({ timestamp: new Date().toISOString(), message: 'ping' });
  console.log('✅ Écriture réussie');

  // Test de lecture
  console.log('📖 Test de lecture...');
  const doc = await testRef.get();
  console.log('📄 Document lu:', doc.data());

  // Nettoyage
  await testRef.delete();
  console.log('🧹 Test document supprimé');

  console.log('🎉 Test Firebase complet réussi !');

} catch (error) {
  console.error('❌ Erreur Firebase:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
