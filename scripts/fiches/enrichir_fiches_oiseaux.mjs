#!/usr/bin/env node
/**
 * Import structuré des fiches oiseaux (mixte legacy + panels sous fiches_oiseaux/{appId})
 * Usage:
 *   node tools/import_fiches_oiseaux.js --input=./data/oiseaux.json [--apply] [--verbose]
 *
 * Input JSON (extrait / 1 espèce):
 * [
 *  {
 *    "appId": "jynx_torquilla",
 *    "slug": "torcol-fourmilier",
 *    "noms": {
 *      "fr": "Torcol fourmilier",
 *      "sci": "Jynx torquilla",
 *      "en": "Eurasian Wryneck"
 *    },
 *    "wikidata_qid": "Q192452",
 *    "guilde": "passereau_insectivore_forestier",
 *    "media": { "urlImage": "https://...", "urlMp3": "https://..." },
 *    "identification": {
 *      "classification": { "ordre": "Piciformes", "famille": "Picidae" },
 *      "morphologie": "Fin picidé brun-roux finement barré, long cou torsadable...",
 *      "mesures": {
 *        "taille":    { "min": 17, "max": 17, "unite": "cm" },
 *        "envergure": { "min": 25, "max": 27, "unite": "cm" },
 *        "poids":     { "min": 30, "max": 45, "unite": "g" }
 *      },
 *      "especesRessemblantes": [
 *        {"nom": "Jynx ruficollis", "se_distingue_par": "Plus roussâtre, collier marqué, aire africaine."}
 *      ],
 *      "sources": ["Wikidata","INPN/TAXREF","IUCN (LC 2022 https://www.iucnredlist.org/)"]
 *    },
 *    "habitat": {
 *      "typeDeMilieu": "Vergers, lisières et bocage avec vieux arbres riches en fourmis.",
 *      "ouObserverFrance": "Présent en France métropolitaine surtout au nord et à l’est, plus localisé au sud-ouest.",
 *      "migration": "Migrateur au long cours: hiver en Afrique de l’Est, revient en avril et repart en septembre.",
 *      "sources": ["INPN/SINP","LPO (régionale)"]
 *    },
 *    "alimentation": {
 *      "alimentationPrincipale": ["fourmis","larves d'insectes"],
 *      "description": "Capture les fourmis avec une langue collante, fouille souches et pelouses.",
 *      "sources": ["HAL/PLOS/MDPI open-access"]
 *    },
 *    "reproduction": {
 *      "etapes": {
 *        "parade": "Balancement de la tête et vocalisations rauques.",
 *        "nidification": "Niche dans cavités existantes, souvent vieux vergers.",
 *        "ponte": "Mai-juin.",
 *        "incubation": "Incubation par les deux parents.",
 *        "nourrissage": "Apports d’insectes, surtout fourmis.",
 *        "envol": "Jeunes à l’envol vers 20-22 jours.",
 *        "accouplement": "En début de saison."
 *      },
 *      "chips": {
 *        "periodeMois": ["avril","mai","juin"],
 *        "nbOeufsParPondee": { "min": 6, "max": 10 },
 *        "incubationJours": { "min": 12, "max": 14, "unite": "j" }
 *      },
 *      "sources": ["INPN/SINP"]
 *    },
 *    "protection": {
 *      "statutMonde": { "iucn": "LC", "annee": 2022, "url": "https://www.iucnredlist.org/" },
 *      "statutFrance": "NT",
 *      "description": "Déclin local dû à la perte des vergers et du bocage; dépendance aux fourmis.",
 *      "actions": ["préserver les vergers traditionnels","poser nichoirs à cavités"],
 *      "sources": ["IUCN (catégorie/année/url)","data.gouv"]
 *    }
 *  }
 * ]
 */

import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import admin from 'firebase-admin';

// ---------------- CLI ----------------
function parseArgs() {
  const args = process.argv.slice(2);
  let input = './data/oiseaux.json';
  let apply = false;
  let verbose = false;
  for (const a of args) {
    if (a.startsWith('--input=')) input = a.split('=')[1];
    if (a === '--apply') apply = true;
    if (a === '--verbose') verbose = true;
  }
  return { input, apply, verbose };
}

// ------------- Helpers domain -------------
const MOIS_FR = ["janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre"];

function isoNow() { return new Date().toISOString(); }

function clampNum(n, min, max) {
  if (typeof n !== 'number' || Number.isNaN(n)) return null;
  return Math.min(Math.max(n, min), max);
}

function validMesure(obj, min, max, unite) {
  if (!obj || typeof obj !== 'object') return null;
  const lo = clampNum(obj.min, min, max);
  const hi = clampNum(obj.max, min, max);
  const u  = (obj.unite || unite || '').trim();
  if (lo == null || hi == null || !u) return null;
  const display = (lo === hi) ? `≈ ${hi} ${u}` : `${lo}–${hi} ${u}`;
  return { min: lo, max: hi, unite: u, display };
}

function ensureAlimPrincipale(arr) {
  if (!Array.isArray(arr)) return [];
  return arr.map(s => String(s).trim()).filter(Boolean).slice(0,3);
}

function sortMoisFr(arr) {
  if (!Array.isArray(arr)) return [];
  const norm = arr.map(s => String(s).trim().toLowerCase()).filter(Boolean);
  const uniq = [...new Set(norm)].filter(m => MOIS_FR.includes(m));
  return uniq.sort((a,b) => MOIS_FR.indexOf(a) - MOIS_FR.indexOf(b));
}

function sentenceOrNull(s) {
  if (!s) return null;
  const t = String(s).trim();
  if (!t) return null;
  // ajoute un point final si absent (sans double point)
  return /[.!?…]$/.test(t) ? t : `${t}.`;
}

function nonEmptyStr(s) {
  const t = (s ?? '').toString().trim();
  return t.length ? t : null;
}

function takeListStrings(xs) {
  if (!Array.isArray(xs)) return [];
  return xs.map(x => String(x).trim()).filter(Boolean);
}

function normalizeEspecesRessemblantes(list) {
  if (!Array.isArray(list)) return [];
  return list.map(e => ({
    nom: nonEmptyStr(e?.nom),
    se_distingue_par: sentenceOrNull(e?.se_distingue_par)
  })).filter(e => e.nom && e.se_distingue_par);
}

// Détection du gabarit JSON (summary + panels)
function isGabaritEntry(entry) {
  return entry && typeof entry === 'object' && entry.summary && entry.panels && entry.summary.data;
}

// ------------- Firestore init -------------
async function initFirebase() {
  const serviceAccount = JSON.parse(
    await readFile(resolve('serviceAccountKey.json'), 'utf8')
  );
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: `https://${serviceAccount.project_id}-default-rtdb.firebaseio.com/`,
  });
  return admin.firestore();
}

// ------------- Sons Oiseaux link helper -------------
async function findSonsOiseauxId(db, { nomFrancais, nomScientifique }) {
  try {
    const col = db.collection('sons_oiseaux');
    // 1) Essai par nom français exact
    if (nomFrancais) {
      const qs = await col.where('nomFrancais', '==', nomFrancais).limit(1).get();
      if (!qs.empty) {
        return qs.docs[0].id;
      }
    }
    // 2) Essai par nom scientifique exact
    if (nomScientifique) {
      const qs2 = await col.where('nomScientifique', '==', nomScientifique).limit(1).get();
      if (!qs2.empty) {
        return qs2.docs[0].id;
      }
    }
  } catch (_) {
    // silencieux en prod
  }
  return null;
}

// ------------- Mapping principal -------------
function buildSummary(input) {
  return {
    slug: nonEmptyStr(input.slug),
    nomFrancais: nonEmptyStr(input.noms?.fr),
    nomScientifique: nonEmptyStr(input.noms?.sci),
    nomAnglais: nonEmptyStr(input.noms?.en),
    wikidata_qid: nonEmptyStr(input.wikidata_qid),
    guilde: nonEmptyStr(input.guilde),
    confiance: "moyenne",
    media: {
      urlImage: nonEmptyStr(input.media?.urlImage),
      urlMp3: nonEmptyStr(input.media?.urlMp3),
    },
    version: 1,
    updatedAt: isoNow(),
  };
}

function buildIdentification(input) {
  const id = input.identification || {};
  const taille    = validMesure(id.mesures?.taille,    5, 200, "cm");
  const envergure = validMesure(id.mesures?.envergure, 8, 350, "cm");
  const poids     = validMesure(id.mesures?.poids,     3, 16000, "g");

  // borne logique envergure.min >= taille.min si les deux existent
  if (taille && envergure && envergure.min < taille.min) {
    // on ajuste doucement l’envergure.min
    envergure.min = Math.max(envergure.min, taille.min);
    envergure.display = (envergure.min === envergure.max)
      ? `≈ ${envergure.max} ${envergure.unite}`
      : `${envergure.min}–${envergure.max} ${envergure.unite}`;
  }

  return {
    classification: {
      ordre: nonEmptyStr(id.classification?.ordre),
      famille: nonEmptyStr(id.classification?.famille),
    },
    morphologie: sentenceOrNull(id.morphologie),
    mesures: { taille, envergure, poids },
    especesRessemblantes: normalizeEspecesRessemblantes(id.especesRessemblantes),
    sources: takeListStrings(id.sources),
    confiance: "élevée",
    updatedAt: isoNow(),
  };
}

function buildHabitat(input) {
  const h = input.habitat || {};
  return {
    typeDeMilieu: sentenceOrNull(h.typeDeMilieu),
    ouObserverFrance: sentenceOrNull(h.ouObserverFrance),
    migration: sentenceOrNull(h.migration),
    sources: takeListStrings(h.sources),
    confiance: "moyenne",
    updatedAt: isoNow(),
  };
}

function buildAlimentation(input) {
  const a = input.alimentation || {};
  return {
    alimentationPrincipale: ensureAlimPrincipale(a.alimentationPrincipale),
    description: sentenceOrNull(a.description),
    sources: takeListStrings(a.sources),
    confiance: "élevée",
    updatedAt: isoNow(),
  };
}

function buildReproduction(input) {
  const r = input.reproduction || {};
  const periodeMois = sortMoisFr(r.chips?.periodeMois);
  const nbOeufs = r.chips?.nbOeufsParPondee ?? null;
  const incubation = r.chips?.incubationJours ?? null;

  const chips = {
    periodeMois,
    nbOeufsParPondee: (nbOeufs && typeof nbOeufs === 'object')
      ? {
          min: clampNum(nbOeufs.min, 1, 12),
          max: clampNum(nbOeufs.max, 1, 12)
        }
      : null,
    incubationJours: (incubation && typeof incubation === 'object')
      ? {
          min: clampNum(incubation.min, 9, 45),
          max: clampNum(incubation.max, 9, 45),
          unite: 'j'
        }
      : null,
  };

  const etapes = {};
  const allowed = ["parade","nidification","ponte","incubation","nourrissage","envol","accouplement"];
  for (const k of allowed) etapes[k] = sentenceOrNull(r.etapes?.[k]);

  return {
    etapes,
    chips,
    sources: takeListStrings(r.sources),
    confiance: "moyenne",
    updatedAt: isoNow(),
  };
}

function buildProtection(input) {
  const p = input.protection || {};
  const statutMonde = p.statutMonde || {};
  const iucn = (statutMonde.iucn || '').toString().trim().toUpperCase();
  const annee = Number.isFinite(+statutMonde.annee) ? +statutMonde.annee : null;

  return {
    statutMonde: {
      iucn: iucn || null,
      annee: annee,
      url: nonEmptyStr(statutMonde.url)
    },
    statutFrance: nonEmptyStr(p.statutFrance),
    description: sentenceOrNull(p.description),
    actions: takeListStrings(p.actions),
    sources: takeListStrings(p.sources),
    confiance: "moyenne",
    updatedAt: isoNow(),
  };
}

// Legacy minimal à conserver (pas d’infos des panels ici)
function buildLegacyMinimal(input) {
  return {
    nomFrancais: nonEmptyStr(input.noms?.fr),
    nomScientifique: nonEmptyStr(input.noms?.sci),
    nomAnglais: nonEmptyStr(input.noms?.en) || null,
    famille: nonEmptyStr(input.identification?.classification?.famille) || null,
    ordre: nonEmptyStr(input.identification?.classification?.ordre) || null,
    media: {
      urlImage: nonEmptyStr(input.media?.urlImage) || null,
      urlMp3: nonEmptyStr(input.media?.urlMp3) || null
    },
    updatedAt: isoNow(),
    version: 1
  };
}

// ------------- Main import -------------
async function main() {
  const { input, apply, verbose } = parseArgs();
  const raw = JSON.parse(await readFile(resolve(input), 'utf8'));
  const entries = Array.isArray(raw) ? raw : [raw];

  const db = await initFirebase();
  let total = 0;

  for (const sp of entries) {
    const isGab = isGabaritEntry(sp);
    const appId = isGab
      ? String(sp.summary?.data?.appId || sp.summary?.data?.slug || '').trim()
      : String(sp.appId || '').trim();
    if (!appId) {
      console.warn('⚠️ Entrée sans appId, ignorée.');
      continue;
    }

    const baseRef = db.collection('fiches_oiseaux').doc(appId);

    const summary = isGab ? {
      slug: nonEmptyStr(sp.summary?.data?.slug) || appId,
      nomFrancais: nonEmptyStr(sp.summary?.data?.nomFrancais),
      nomScientifique: nonEmptyStr(sp.summary?.data?.nomScientifique),
      nomAnglais: nonEmptyStr(sp.summary?.data?.nomAnglais),
      wikidata_qid: nonEmptyStr(sp.summary?.data?.wikidata_qid),
      guilde: nonEmptyStr(sp.summary?.data?.guilde),
      media: {
        urlImage: nonEmptyStr(sp.summary?.data?.media?.urlImage),
        urlMp3: nonEmptyStr(sp.summary?.data?.media?.urlMp3),
      },
      version: 1,
      updatedAt: isoNow(),
    } : buildSummary(sp);

    const iden    = isGab ? (sp.panels?.identification?.data || {}) : buildIdentification(sp);
    const hab     = isGab ? (sp.panels?.habitat?.data || {}) : buildHabitat(sp);
    const alim    = isGab ? (sp.panels?.alimentation?.data || {}) : buildAlimentation(sp);
    const repro   = isGab ? (sp.panels?.reproduction?.data || {}) : buildReproduction(sp);
    const prot    = isGab ? (sp.panels?.protection?.data || {}) : buildProtection(sp);
    const legacy  = isGab ? buildLegacyMinimal({
      noms: { fr: sp.summary?.data?.nomFrancais, sci: sp.summary?.data?.nomScientifique, en: sp.summary?.data?.nomAnglais },
      identification: { classification: iden.classification },
      media: sp.summary?.data?.media,
    }) : buildLegacyMinimal(sp);

    if (!apply) {
      // Dry-run
      console.log(`\n[DRY] ${appId}`);
      console.log('  summary:', JSON.stringify(summary));
      console.log('  identification/current:', JSON.stringify(iden));
      console.log('  habitat/current:', JSON.stringify(hab));
      console.log('  alimentation/current:', JSON.stringify(alim));
      console.log('  reproduction/current:', JSON.stringify(repro));
      console.log('  protection/current:', JSON.stringify(prot));
      console.log('  legacy-merge:', JSON.stringify(legacy));
      total++;
      continue;
    }

    const batch = db.batch();

    // Lien avec sons_oiseaux: tenter de retrouver l'ID Firestore existant
    let idOiseau = null;
    try {
      idOiseau = await findSonsOiseauxId(db, {
        nomFrancais: summary.nomFrancais,
        nomScientifique: summary.nomScientifique,
      });
    } catch (_) {}
    // Doc parent: legacy minimal + méta publiques
    batch.set(baseRef, {
      appId: appId,
      slug: summary.slug,
      nomFrancais: summary.nomFrancais,
      nomScientifique: summary.nomScientifique,
      nomAnglais: summary.nomAnglais,
      wikidata_qid: summary.wikidata_qid,
      guilde: summary.guilde,
      media: summary.media,
      version: summary.version,
      updatedAt: summary.updatedAt,
      ...(idOiseau ? { idOiseau } : {}),
      // merge de champs legacy utiles à l’UI existante
      ...legacy
    }, { merge: true });

    // Panels
    batch.set(baseRef.collection('identification').doc('current'), iden, { merge: true });
    batch.set(baseRef.collection('habitat').doc('current'),        hab,  { merge: true });
    batch.set(baseRef.collection('alimentation').doc('current'),   alim, { merge: true });
    batch.set(baseRef.collection('reproduction').doc('current'),   repro,{ merge: true });
    batch.set(baseRef.collection('protection').doc('current'),     prot, { merge: true });

    await batch.commit();
    total++;

    if (verbose) console.log(`✅ Importé: ${appId} (${summary.nomFrancais})`);
  }

  console.log(`\n🚀 Terminé: ${total} espèces ${apply ? 'écrites' : 'prévisualisées'} (${apply ? 'APPLY' : 'DRY'})`);
}

main().catch(e => {
  console.error('❌ Erreur import:', e);
  process.exit(1);
});
