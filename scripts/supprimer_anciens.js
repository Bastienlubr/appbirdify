#!/usr/bin/env node

/**
 * Script de suppression des anciens documents
 *
 * Supprime de Firestore tous les docs de `fiches_oiseaux` dont l'ID
 * n'est pas présent dans le CSV (c'est la "liste d'avant").
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'birdify-df029'
});

const db = admin.firestore();

async function supprimerAnciens() {
  try {
    console.log('🧹 Suppression des anciens documents (liste d\'avant)...\n');

    // 1) Lire le CSV et construire l'ensemble des IDs valides
    const csvPath = path.join(__dirname, '..', 'assets', 'data', 'Bank son oiseauxV4.csv');
    if (!fs.existsSync(csvPath)) {
      console.error('❌ Fichier CSV introuvable:', csvPath);
      process.exit(1);
    }

    const csvContent = fs.readFileSync(csvPath, 'utf-8');
    const lines = csvContent.split('\n');
    if (lines.length < 2) {
      console.error('❌ CSV vide ou invalide');
      process.exit(1);
    }

    const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''));
    const allowedIds = new Set();

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      const values = [];
      let current = '';
      let inQuotes = false;
      for (let j = 0; j < line.length; j++) {
        const ch = line[j];
        if (ch === '"') inQuotes = !inQuotes;
        else if (ch === ',' && !inQuotes) { values.push(current.trim()); current = ''; }
        else current += ch;
      }
      values.push(current.trim());

      const row = {};
      headers.forEach((h, idx) => {
        if (idx < values.length) row[h] = values[idx].replace(/"/g, '');
      });

      const rawId = row.id_oiseaux || row.ID || row.o_ID;
      if (!rawId) continue;
      // Normaliser comme lors du réimport: préfixe o_ + nettoyer
      const clean = rawId.toString().replace(/[^a-zA-Z0-9_-]/g, '_');
      const docId = clean.startsWith('o_') ? clean : `o_${clean}`;
      allowedIds.add(docId);
    }

    console.log(`📋 IDs valides d'après le CSV: ${allowedIds.size}`);

    // 2) Lister la collection et supprimer les non conformes
    const snap = await db.collection('fiches_oiseaux').get();
    if (snap.empty) {
      console.log('✅ Collection vide, rien à supprimer');
      return;
    }

    const toDelete = snap.docs.filter(d => !allowedIds.has(d.id));
    console.log(`🗑️ Documents à supprimer (anciens): ${toDelete.length}`);

    if (toDelete.length === 0) {
      console.log('✅ Aucun ancien document trouvé.');
      return;
    }

    const batchSize = 500;
    for (let i = 0; i < toDelete.length; i += batchSize) {
      const batch = db.batch();
      const end = Math.min(i + batchSize, toDelete.length);
      for (let j = i; j < end; j++) batch.delete(toDelete[j].ref);
      await batch.commit();
      console.log(`✅ Suppression lot ${Math.floor(i / batchSize) + 1}/${Math.ceil(toDelete.length / batchSize)}: ${end - i}`);
    }

    console.log('🎉 Suppression des anciens documents terminée !');
  } catch (e) {
    console.error('❌ Erreur:', e);
    process.exit(1);
  }
}

if (require.main === module) {
  supprimerAnciens().then(() => process.exit(0));
}

module.exports = { supprimerAnciens };
