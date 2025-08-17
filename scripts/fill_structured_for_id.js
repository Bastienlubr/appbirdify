#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const USER_AGENT = 'appbirdify/fill_structured_for_id (node)';

async function fetchJson(url, headers = {}) {
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

async function fetchWikipediaExtractFull(nomFr, nomSci) {
  const langs = ['fr', 'en'];
  const titles = [nomFr, nomSci].filter(Boolean);
  for (const lang of langs) {
    for (const title of titles) {
      try {
        const url = `https://${lang}.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1&redirects=1&format=json&titles=${encodeURIComponent(title)}`;
        const data = await fetchJson(url, { accept: 'application/json' });
        const pages = data?.query?.pages || {};
        const first = Object.values(pages)[0];
        const extract = first?.extract;
        if (extract && typeof extract === 'string' && extract.trim().length > 0) {
          return { lang, extract };
        }
      } catch (_) {}
    }
  }
  return null;
}

function sanitize(text) {
  if (!text) return text;
  return text.replace(/\s*\[[^\]]*\]/g, ' ').replace(/\s+/g, ' ').trim();
}

async function extractStructuredFromText({ text, nomFr, nomSci }) {
  if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY missing');
  const prompt = `Tu es un assistant qui extrait des données factuelles en FR depuis un texte source (Wikipédia). Retourne UNIQUEMENT un JSON valide correspondant EXACTEMENT au schéma ci-dessous. Pas d'autres champs ni commentaires.

Contraintes générales:
- Utilise des chaînes lisibles côté utilisateur (ex: "16–18 cm", "70–77 g", "27–30 cm").
- Pas de listes à puces. Pas de références. Pas de citations.
- Si une information est absente, mets null ou [] selon le type.
- "exemples" = 0-3 espèces proches (noms FR si possibles). "differenciation" = court conseil pour ne pas confondre.
- "zonesObservation" = où on peut l'observer (FR + pays/régions). Court texte.
- Migration.mois: renseigne les mois (texte FR, ex: "août", "septembre"). Laisse null si incertain.
- Reproduction: période (debutMois/finMois), nbOeufsParPondee (texte court), incubationJours (texte court). Laisse null si non clair.
- Protection: statutFrance/statutMonde (codes courts si disponibles: LC, NT, VU, EN, CR), actions (court texte) ou null.

Schéma JSON:
{
  "identification": {
    "mesures": { "poids": string|null, "taille": string|null, "envergure": string|null },
    "especesRessemblantes": { "exemples": [string], "differenciation": string|null },
    "morphologie": string|null
  },
  "habitat": {
    "milieux": [string],               // Catégories génériques (ex: lac, rivière, étang, marais, forêt, urbain, montagne, rochers, landes, champs, littoral, etc.)
    "zonesObservation": string|null,   // Lieux précis (FR d'abord, puis étranger)
    "migration": { "description": string|null, "mois": { "debut": string|null, "fin": string|null } }
  },
  "reproduction": {
    "periode": { "debutMois": string|null, "finMois": string|null },
    "nbOeufsParPondee": string|null,
    "incubationJours": string|null
  },
  "protectionEtatActuel": {
    "statutFrance": string|null,
    "statutMonde": string|null,
    "actions": string|null
  }
}

Texte (espèce: ${nomFr} - ${nomSci}):\n\n${text}`;

  const body = {
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: 'Tu réponds strictement en JSON valide pour être parsé côté serveur.' },
      { role: 'user', content: prompt },
    ],
    temperature: 0.4,
    max_tokens: 900,
    response_format: { type: 'json_object' },
  };
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
      'User-Agent': USER_AGENT,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`OpenAI HTTP ${res.status}`);
  const j = await res.json();
  const content = (j.choices?.[0]?.message?.content || '').trim();
  try {
    return JSON.parse(content);
  } catch (e) {
    // Fallback: extraire le premier objet JSON plausible
    const start = content.indexOf('{');
    const end = content.lastIndexOf('}');
    if (start !== -1 && end !== -1 && end > start) {
      const sub = content.slice(start, end + 1);
      return JSON.parse(sub);
    }
    throw new Error('Invalid JSON from OpenAI');
  }
}

async function buildMorphologieFromText({ text, nomFr, nomSci }) {
  if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY missing');
  const prompt = `À partir du texte source ci-dessous (espèce: ${nomFr} - ${nomSci}), rédige un paragraphe "morphologie" en français:
- uniquement des indices visuels (plumage, couleurs, motifs, silhouette, allure, bec, queue, pattes, ailes)
- pas de nombres ni plages chiffrées
- 3–6 phrases, sans listes, sans citations, sans références

Texte:\n\n${text}`;

  const body = {
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: 'Tu réponds en JSON strict.' },
      { role: 'user', content: `Retourne uniquement: {"morphologie": "..."}\n\n${prompt}` },
    ],
    temperature: 0.5,
    max_tokens: 400,
    response_format: { type: 'json_object' },
  };
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
      'User-Agent': USER_AGENT,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`OpenAI HTTP ${res.status}`);
  const j = await res.json();
  const content = (j.choices?.[0]?.message?.content || '').trim();
  try {
    const parsed = JSON.parse(content);
    const m = (parsed && typeof parsed.morphologie === 'string') ? parsed.morphologie.trim() : '';
    return m || null;
  } catch (_) {
    return null;
  }
}

async function main() {
  if (typeof fetch !== 'function') {
    global.fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args));
  }
  const args = process.argv.slice(2);
  const idArg = args.find(a => a.startsWith('--id='));
  if (!idArg) {
    console.log('Usage: node scripts/fill_structured_for_id.js --id=o_XXX');
    process.exit(1);
  }
  const docId = idArg.split('=')[1];
  const doc = await db.collection('fiches_oiseaux').doc(docId).get();
  if (!doc.exists) {
    console.log('❌ Doc introuvable:', docId);
    process.exit(1);
  }
  const data = doc.data();
  const nomFr = data.nomFrancais || '';
  const nomSci = data.nomScientifique || '';

  const full = await fetchWikipediaExtractFull(nomFr, nomSci);
  if (!full) {
    console.log('❌ Aucun extrait complet Wikipédia');
    process.exit(0);
  }

  const clean = sanitize(full.extract).slice(0, 8000);
  let structured;
  try {
    structured = await extractStructuredFromText({ text: clean, nomFr, nomSci });
  } catch (e) {
    console.error('❌ Extraction structurée échouée:', e.message);
    process.exit(1);
  }

  // Compléter explicitement morphologie si absente
  if (!structured?.identification?.morphologie) {
    try {
      const morpho = await buildMorphologieFromText({ text: clean, nomFr, nomSci });
      if (morpho) {
        structured.identification = structured.identification || {};
        structured.identification.morphologie = morpho;
      }
    } catch (_) {}
  }

  const updates = {};
  if (structured?.identification) {
    updates.identification = {
      ...(data.identification || {}),
      ...(structured.identification.mesures ? { mesures: structured.identification.mesures } : {}),
      ...(structured.identification.especesRessemblantes ? { especesRessemblantes: structured.identification.especesRessemblantes } : {}),
      ...(structured.identification.morphologie ? { morphologie: structured.identification.morphologie } : {}),
    };
  }
  if (structured?.habitat) {
    updates.habitat = {
      ...(data.habitat || {}),
      ...(Array.isArray(structured.habitat.milieux) ? { milieux: structured.habitat.milieux } : {}),
      ...(structured.habitat.zonesObservation ? { zonesObservation: structured.habitat.zonesObservation } : {}),
      ...(structured.habitat.migration ? { migration: structured.habitat.migration } : {}),
    };
  }
  if (structured?.reproduction) {
    updates.reproduction = {
      ...(data.reproduction || {}),
      ...(structured.reproduction.periode ? { periode: structured.reproduction.periode } : {}),
      ...(structured.reproduction.nbOeufsParPondee ? { nbOeufsParPondee: structured.reproduction.nbOeufsParPondee } : {}),
      ...(structured.reproduction.incubationJours ? { incubationJours: structured.reproduction.incubationJours } : {}),
    };
  }
  if (structured?.protectionEtatActuel) {
    updates.protectionEtatActuel = {
      ...(data.protectionEtatActuel || {}),
      ...(structured.protectionEtatActuel.statutFrance ? { statutFrance: structured.protectionEtatActuel.statutFrance } : {}),
      ...(structured.protectionEtatActuel.statutMonde ? { statutMonde: structured.protectionEtatActuel.statutMonde } : {}),
      ...(structured.protectionEtatActuel.actions ? { actions: structured.protectionEtatActuel.actions } : {}),
    };
  }

  if (Object.keys(updates).length === 0) {
    console.log('↷ Aucune donnée structurée détectée');
    process.exit(0);
  }

  await doc.ref.set(updates, { merge: true });
  console.log('✅ Sous-champs structurés mis à jour pour', docId, Object.keys(updates));
}

if (require.main === module) {
  main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
}


