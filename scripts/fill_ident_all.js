#!/usr/bin/env node

/**
 * Remplit identification.description pour toutes les fiches:
 * - Récupère le résumé Wikipédia (FR, fallback EN)
 * - Paraphrase (si OPENAI_API_KEY défini)
 * - Enregistre dans Firestore (merge)
 * Options:
 *   --force  Écrase même si un texte existe
 *   --limit=N  Traite N docs (par défaut: tout)
 */

const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const USER_AGENT = 'appbirdify/fill_ident_all (node)';

async function fetchJson(url, headers = {}) {
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
  return res.json();
}

async function getWikipediaSummary(nomFr, nomSci) {
  const langs = ['fr', 'en'];
  const titles = [nomFr, nomSci].filter(Boolean);
  for (const lang of langs) {
    for (const title of titles) {
      try {
        const url = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
        const data = await fetchJson(url, { 'accept': 'application/json' });
        if (data && data.extract) {
          return data.extract;
        }
      } catch (_) {}
    }
  }
  return null;
}

function sanitize(text) {
  if (!text) return text;
  return text
    .replace(/\s*\[[^\]]*\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function paraphraseIfPossible(text) {
  if (!text || !OPENAI_API_KEY) return text;
  try {
    const body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: "Tu es un rédacteur qui REFORMULE nettement en français, sans rien ajouter ni altérer les faits. Consignes: (1) évite toute reprise mot à mot de plus de 6 mots, (2) change la structure des phrases, (3) conserve noms propres, chiffres et unités, (4) produis 1-2 paragraphes fluides, sans listes ni citations." },
        { role: 'user', content: `Réécris ce texte en respectant les consignes ci-dessus:\n\n${text}` },
      ],
      temperature: 0.6,
      max_tokens: Math.min(800, Math.ceil(text.length * 1.2)),
    };
    // Retry with exponential backoff on 429/5xx
    let attempt = 0;
    while (attempt < 5) {
      const res = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json',
          'User-Agent': USER_AGENT,
        },
        body: JSON.stringify(body),
      });
      if (res.ok) {
        const json = await res.json();
        return json.choices?.[0]?.message?.content?.trim() || text;
      }
      if (res.status === 429 || (res.status >= 500 && res.status < 600)) {
        const delay = 1000 * Math.pow(2, attempt);
        await new Promise(r => setTimeout(r, delay));
        attempt++;
        continue;
      }
      break;
    }
    return text;
  } catch (_) {
    return text;
  }
}

async function processDoc(doc, force) {
  const data = doc.data();
  const nomFr = data.nomFrancais || '';
  const nomSci = data.nomScientifique || '';
  const existing = data?.identification?.description;
  if (existing && !force) {
    return { updated: false, reason: 'exists' };
  }
  const summary = await getWikipediaSummary(nomFr, nomSci);
  if (!summary) return { updated: false, reason: 'no_summary' };
  const clean = sanitize(summary).slice(0, 2000);
  const para = await paraphraseIfPossible(clean);
  await doc.ref.set({ identification: { ...(data.identification || {}), description: para } }, { merge: true });
  return { updated: true };
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const limitArg = args.find(a => a.startsWith('--limit='));
  const delayArg = args.find(a => a.startsWith('--delayMs='));
  const limitMax = limitArg ? parseInt(limitArg.split('=')[1], 10) : Infinity;
  const delayMs = delayArg ? Math.max(0, parseInt(delayArg.split('=')[1], 10)) : 0;
  let processed = 0, ok = 0, skip = 0, miss = 0;

  let lastDoc = null;
  while (processed < limitMax) {
    let query = db.collection('fiches_oiseaux').orderBy('__name__').limit(500);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      if (processed >= limitMax) break;
      try {
        const res = await processDoc(doc, force);
        if (res.updated) { ok++; console.log(`✅ ${doc.id} ident`); }
        else { skip++; }
      } catch (e) {
        miss++; console.log(`❌ ${doc.id} ${e.message}`);
      }
      processed++;
      if (delayMs > 0) {
        await new Promise(r => setTimeout(r, delayMs));
      }
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < 500) break;
  }
  console.log(`\nRésumé ident: ${ok} mis à jour, ${skip} ignorés, ${miss} erreurs`);
}

if (require.main === module) {
  if (typeof fetch !== 'function') {
    global.fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args));
  }
  main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
}


