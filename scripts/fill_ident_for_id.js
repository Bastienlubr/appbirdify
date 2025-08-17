#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const USER_AGENT = 'appbirdify/fill_ident_for_id (node)';

async function fetchJson(url, headers = {}) {
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

async function getWikipediaSummary(nomFr, nomSci) {
  const langs = ['fr', 'en'];
  const titles = [nomFr, nomSci].filter(Boolean);
  for (const lang of langs) {
    for (const title of titles) {
      try {
        const url = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
        const data = await fetchJson(url, { accept: 'application/json' });
        if (data && data.extract) return data.extract;
      } catch (_) {}
    }
  }
  return null;
}

function sanitize(text) {
  if (!text) return text;
  return text.replace(/\s*\[[^\]]*\]/g, ' ').replace(/\s+/g, ' ').trim();
}

function ngramSet(s, n = 4) {
  const t = (s || '').toLowerCase().replace(/[^a-zàâäéèêëîïôöùûüç0-9\s]/gi, ' ');
  const joined = t.replace(/\s+/g, ' ').trim();
  const grams = new Set();
  for (let i = 0; i <= Math.max(0, joined.length - n); i++) {
    grams.add(joined.slice(i, i + n));
  }
  return grams;
}

function jaccardSim(a, b) {
  const A = ngramSet(a);
  const B = ngramSet(b);
  if (A.size === 0 && B.size === 0) return 1;
  let inter = 0;
  for (const g of A) if (B.has(g)) inter++;
  const uni = A.size + B.size - inter;
  return uni === 0 ? 1 : inter / uni;
}

async function paraphraseStrong(text, { maxAttempts = 6, maxSim = 0.7 } = {}) {
  if (!text) return text;
  if (!OPENAI_API_KEY) {
    console.log('❌ OPENAI_API_KEY manquante, abandon sans mise à jour');
    throw new Error('OPENAI_API_KEY missing');
  }
  let best = null;
  let bestSim = 1;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const temperature = Math.min(0.9, 0.6 + attempt * 0.05);
    const body = {
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: "Tu es un rédacteur qui REFORMULE nettement en français, sans rien ajouter ni altérer les faits. Règles: (1) ne réutilise aucune séquence de 6+ mots identique au texte source, (2) commence par une tournure différente de l'original, (3) varie la syntaxe (voix active/passive, ordre des propositions), (4) conserve les noms propres, chiffres, unités, (5) 1-2 paragraphes continus, sans listes ni citations, (6) évite les formulations: 'est une espèce', 'L'espèce est', 'Les Accenteurs mouchets', 'C\'est un migrateur partiel'." },
        { role: 'user', content: `Réécris ce texte en respectant les règles ci-dessus. Modifie sensiblement la syntaxe et les transitions, sans changer les faits:\n\n${text}` },
      ],
      temperature,
      frequency_penalty: 0.6,
      presence_penalty: 0.3,
      max_tokens: Math.min(700, Math.ceil(text.length * 1.15)),
    };
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}`, 'Content-Type': 'application/json', 'User-Agent': USER_AGENT },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      if (res.status === 429 || (res.status >= 500 && res.status < 600)) {
        const delay = 1000 * Math.pow(2, attempt);
        await new Promise((r) => setTimeout(r, delay));
        continue;
      }
      break;
    }
    const j = await res.json();
    const candidate = (j.choices?.[0]?.message?.content || '').trim();
    if (!candidate) continue;
    const sim = jaccardSim(text, candidate);
    if (sim < bestSim) { bestSim = sim; best = candidate; }
    if (sim <= (maxSim ?? 0.7)) return candidate;
  }
  if (best) return best; // le moins similaire obtenu
  throw new Error('Paraphrase failed');
}

async function main() {
  if (typeof fetch !== 'function') {
    global.fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args));
  }
  const args = process.argv.slice(2);
  const idArg = args.find((a) => a.startsWith('--id='));
  const force = args.includes('--force');
  if (!idArg) {
    console.log('Usage: node scripts/fill_ident_for_id.js --id=o_XXX [--force]');
    process.exit(1);
  }
  const docId = idArg.split('=')[1];
  const doc = await db.collection('fiches_oiseaux').doc(docId).get();
  if (!doc.exists) {
    console.log('❌ Doc introuvable:', docId);
    process.exit(1);
  }
  const data = doc.data();
  const already = data?.identification?.description;
  if (already && !force) {
    console.log('↷ Identification déjà présente, utilisez --force pour écraser');
    process.exit(0);
  }
  const nomFr = data.nomFrancais || '';
  const nomSci = data.nomScientifique || '';
  const sum = await getWikipediaSummary(nomFr, nomSci);
  if (!sum) {
    console.log('↷ Aucun résumé Wikipédia');
    process.exit(0);
  }
  const clean = sanitize(sum).slice(0, 2000);
  let para;
  try {
    para = await paraphraseStrong(clean, { maxAttempts: 6, maxSim: 0.7 });
  } catch (e) {
    console.log('❌ Paraphrase indisponible, aucune mise à jour appliquée');
    process.exit(1);
  }
  await doc.ref.set({ identification: { ...(data.identification || {}), description: para } }, { merge: true });
  console.log('✅ Identification mise à jour pour', docId);
}

if (require.main === module) {
  main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
}


