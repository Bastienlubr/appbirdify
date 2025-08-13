#!/usr/bin/env node

import admin from 'firebase-admin';

console.log('🔍 Vérification de l\'environnement Birdify');
console.log('==========================================');

// Vérification des dépendances
try {
  console.log('\n📦 Vérification des dépendances...');
  
  // Test d'import de firebase-admin
  console.log('✅ firebase-admin importé avec succès');
  
  // Test d'initialisation (sans connexion)
  console.log('🚀 Test d\'initialisation Firebase Admin...');
  admin.initializeApp({ 
    projectId: "birdify-local-test" 
  });
  
  console.log('✅ Firebase Admin initialisé (mode test)');
  
  // Vérification de la configuration
  console.log('\n⚙️ Configuration détectée:');
  console.log(`   - FIRESTORE_EMULATOR_HOST: ${process.env.FIRESTORE_EMULATOR_HOST || 'Non défini'}`);
  console.log(`   - NODE_ENV: ${process.env.NODE_ENV || 'Non défini'}`);
  
  // Test de création d'instance Firestore (sans connexion)
  const db = admin.firestore();
  console.log('✅ Instance Firestore créée');
  
  console.log('\n🎯 Environnement prêt pour les tests !');
  console.log('\n📋 Prochaines étapes:');
  console.log('   1. Installer Java (requis pour les emulators Firebase)');
  console.log('   2. Démarrer l\'émulateur: npm run emu:start');
  console.log('   3. Tester la connexion: npm run emu:ping');
  
  process.exit(0);
  
} catch (error) {
  console.error('\n❌ Erreur lors de la vérification:', error.message);
  process.exit(1);
}
