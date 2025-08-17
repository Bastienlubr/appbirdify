#!/usr/bin/env node

/**
 * Réinitialise la structure des documents de la collection `fiches_oiseaux`
 * en ne conservant que les champs d'identité (id/nom/appId/imagePrincipale)
 * et en remplaçant le reste par 5 rubriques normalisées:
 *  - identification
 *  - habitat
 *  - alimentation
 *  - reproduction
 *  - protectionEtatActuel
 *
 * Utilisation:
 *   node scripts/reset_fiche_structure.js --apply
 * Options:
 *   --dryRun (par défaut): n'écrit rien, affiche un aperçu
 *   --apply: applique les changements (overwrite complet des docs)
 */

const admin = require('firebase-admin');
const path = require('path');

// Chargement des credentials Firebase Admin
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'birdify-df029'
});

const db = admin.firestore();

function buildNormalizedDoc(existing, docId) {
  const idOiseau = existing.idOiseau || existing.o_ID || docId;
  const appId = existing.appId || existing.nomScientifique?.toLowerCase()?.replace(/\s+/g, '_') || null;
  const nomFrancais = existing.nomFrancais || null;
  const nomScientifique = existing.nomScientifique || null;
  const imagePrincipale = existing?.medias?.imagePrincipale || null;

  return {
    idOiseau,
    appId,
    nomFrancais,
    nomScientifique,

    // 1) Identification
    identification: {
      description: null, // description visuelle + éléments clés + vision globale
      mesures: {
        poids: null,
        taille: null,
        envergure: null
      },
      especesRessemblantes: {
        exemples: [], // noms potentiels d'espèces proches
        differenciation: null // comment les distinguer
      }
    },

    // 2) Habitat
    habitat: {
      description: null, // milieux précis (lac, forêt, champs, etc.)
      milieux: [], // liste de milieux typiques
      zonesObservation: null, // où l'observer (France, Espagne, etc.)
      migration: {
        description: null, // zone/axes de migration
        mois: {
          debut: null, // ex: 'mars'
          fin: null // ex: 'octobre'
        }
      }
    },

    // 3) Alimentation
    alimentation: {
      description: null, // régime général et variations annuelles
      variationsSaisonnieres: null, // changements selon la saison
      particularites: null // techniques, comportements notables
    },

    // 4) Reproduction
    reproduction: {
      description: null, // vue d'ensemble du cycle de reproduction
      periode: {
        debutMois: null, // ex: 'avril'
        finMois: null // ex: 'juillet'
      },
      nbPontes: null, // nombre de pontes par saison
      nbOeufsParPondee: null, // nombre d'œufs par ponte
      incubationJours: null // durée d'incubation en jours
    },

    // 5) Protection / État actuel
    protectionEtatActuel: {
      description: null, // résumé état de conservation
      statutFrance: null, // statut national
      statutMonde: null, // statut global (ex: IUCN)
      actions: null // plans, réintroductions, mesures récentes
    },

    // Médias conservés minimalement
    medias: {
      imagePrincipale: imagePrincipale
    },

    // Métadonnées minimales
    metadata: {
      dateModification: new Date().toISOString(),
      versionSchema: '2025-08-17-minimal-v1'
    }
  };
}

async function run({ apply }) {
  console.log(`\n▶️  Reset structure fiches_oiseaux (${apply ? 'APPLY' : 'DRY-RUN'})`);
  const snap = await db.collection('fiches_oiseaux').get();
  console.log(`📦 Documents à traiter: ${snap.size}`);

  let processed = 0;
  let written = 0;

  for (const doc of snap.docs) {
    const current = doc.data() || {};
    const nextDoc = buildNormalizedDoc(current, doc.id);

    if (!apply) {
      if (processed < 5) {
        console.log(`\n— Aperçu ${processed + 1}: ${doc.id}`);
        console.dir(nextDoc, { depth: 6 });
      }
    } else {
      await db.collection('fiches_oiseaux').doc(doc.id).set(nextDoc, { merge: false });
      written += 1;
    }

    processed += 1;
    if (processed % 100 === 0) {
      console.log(`… ${processed}/${snap.size} traités`);
    }
  }

  console.log(`\n✅ Traités: ${processed}`);
  if (apply) console.log(`💾 Écrits: ${written}`);
}

(async () => {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  await run({ apply });
  console.log('\n✨ Terminé');
  process.exit(0);
})().catch((e) => {
  console.error('💥 Erreur:', e);
  process.exit(1);
});


