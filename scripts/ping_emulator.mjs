#!/usr/bin/env node

import admin from 'firebase-admin';

// Configuration de l'émulateur Firestore
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  console.log(`🔧 FIRESTORE_EMULATOR_HOST défini à: ${process.env.FIRESTORE_EMULATOR_HOST}`);
}

try {
  // Initialisation de Firebase Admin
  console.log('🚀 Initialisation de Firebase Admin...');
  admin.initializeApp({ 
    projectId: "birdify-local" 
  });
  
  const db = admin.firestore();
  console.log('✅ Firebase Admin initialisé');
  
  // Test d'écriture
  console.log('📝 Écriture du document de test...');
  const docRef = db.collection('health').doc('ping');
  const now = admin.firestore.FieldValue.serverTimestamp();
  
  await docRef.set({ 
    now: now,
    test: 'ping-emulator',
    timestamp: new Date().toISOString()
  });
  console.log('✅ Document écrit avec succès');
  
  // Test de lecture
  console.log('📖 Lecture du document...');
  const doc = await docRef.get();
  
  if (doc.exists) {
    const data = doc.data();
    console.log('📄 Contenu du document:', JSON.stringify(data, null, 2));
    
    // Vérification du timestamp serveur
    if (data.now) {
      console.log('✅ Timestamp serveur présent:', data.now.toDate());
    } else {
      console.log('⚠️ Timestamp serveur manquant');
    }
  } else {
    throw new Error('Document non trouvé après écriture');
  }
  
  // Test de suppression
  console.log('🗑️ Suppression du document...');
  await docRef.delete();
  console.log('✅ Document supprimé avec succès');
  
  // Vérification de la suppression
  const deletedDoc = await docRef.get();
  if (!deletedDoc.exists) {
    console.log('✅ Suppression confirmée');
  } else {
    throw new Error('Document toujours présent après suppression');
  }
  
  // Succès
  console.log('\n🎉 ✅ Firestore emulator ping OK (write/read/delete)');
  process.exit(0);
  
} catch (error) {
  console.error('\n❌ Erreur lors du ping de l\'émulateur:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
