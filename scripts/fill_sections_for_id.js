#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const USER_AGENT = 'appbirdify/fill_sections_for_id (node)';

async function fetchJson(url, headers = {}) {
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

function removeAccents(text) {
  return text.normalize('NFD').replace(/\p{Diacritic}+/gu, '').toLowerCase();
}

function parseSectionsFromExtract(extract) {
  const lines = extract.split(/\r?\n/);
  const sections = [];
  let current = { title: 'intro', content: [] };
  for (const line of lines) {
    const m = line.match(/^==+\s*(.*?)\s*==+$/);
    if (m) {
      if (current.content.length) sections.push(current);
      current = { title: m[1], content: [] };
    } else {
      current.content.push(line);
    }
  }
  if (current.content.length) sections.push(current);
  const map = new Map();
  for (const s of sections) {
    const key = removeAccents((s.title || 'intro').trim());
    const text = s.content.join('\n').trim();
    if (!map.has(key)) map.set(key, text);
  }
  return map;
}

function pickSectionText(sectionMap, lang) {
  const aliases = {
    habitat: lang === 'en' ? ['habitat', 'ecology', 'environment'] : ['habitat', 'ecologie', 'milieu', 'habitat et ecologie'],
    alimentation: lang === 'en' ? ['diet', 'feeding', 'food'] : ['alimentation', 'regime alimentaire', 'se nourrit', 'nourriture'],
    reproduction: lang === 'en' ? ['breeding', 'reproduction', 'nesting'] : ['reproduction', 'nidification', 'cycle de vie'],
    protection: lang === 'en'
      ? ['conservation', 'status', 'threats', 'protection', 'population']
      : ['conservation', 'statut', 'protection', 'menaces', 'etat de conservation', 'population'],
  };
  function findFirst(keys) {
    for (const k of keys) {
      const nk = removeAccents(k);
      if (sectionMap.has(nk)) {
        const t = sectionMap.get(nk);
        if (t && t.trim()) return t.trim();
      }
      for (const candidate of sectionMap.keys()) {
        if (candidate.includes(nk)) {
          const t = sectionMap.get(candidate);
          if (t && t.trim()) return t.trim();
        }
      }
    }
    return null;
  }
  return {
    habitat: findFirst(aliases.habitat),
    alimentation: findFirst(aliases.alimentation),
    reproduction: findFirst(aliases.reproduction),
    protection: findFirst(aliases.protection),
  };
}

function extractByKeywords(text, keys) {
  if (!text) return null;
  const sentences = text.replace(/\s+/g, ' ').split(/(?<=[.!?])\s+/);
  const norm = (s) => removeAccents(s).toLowerCase();
  const out = [];
  for (const s of sentences) {
    const ns = norm(s);
    if (keys.some((k) => ns.includes(norm(k)))) {
      out.push(s.trim());
      if (out.join(' ').length > 800) break;
    }
  }
  return out.length ? out.join(' ') : null;
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

async function paraphrase(text, { maxAttempts = 6, maxSim = 0.7 } = {}) {
  if (!text) return text;
  if (!OPENAI_API_KEY) {
    console.log('❌ OPENAI_API_KEY manquante, abandon pour cette section');
    return text;
  }
  let best = null;
  let bestSim = 1;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const temperature = Math.min(0.9, 0.6 + attempt * 0.05);
    const body = {
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: "Tu es un rédacteur qui REFORMULE nettement en français, sans rien ajouter ni altérer les faits. Consignes: (1) évite toute reprise mot à mot de plus de 6 mots, (2) change la structure des phrases, (3) conserve noms propres, chiffres et unités, (4) 1-2 paragraphes fluides, sans listes ni citations." },
        { role: 'user', content: `Réécris ce texte en respectant les consignes. Modifie sensiblement la syntaxe et les transitions, sans changer les faits:\n\n${text}` },
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
        await new Promise(r => setTimeout(r, delay));
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
  return best || text; // renvoyer la meilleure variante obtenue
}

async function main() {
  if (typeof fetch !== 'function') {
    global.fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args));
  }
  const args = process.argv.slice(2);
  const idArg = args.find((a) => a.startsWith('--id='));
  const sleepArg = args.find((a) => a.startsWith('--sleepMs='));
  if (!idArg) {
    console.log('Usage: node scripts/fill_sections_for_id.js --id=o_XXX');
    process.exit(1);
  }
  const docId = idArg.split('=')[1];
  const sleepMs = sleepArg ? Math.max(0, parseInt(sleepArg.split('=')[1], 10)) : 0;
  const doc = await db.collection('fiches_oiseaux').doc(docId).get();
  if (!doc.exists) {
    console.log('❌ Doc introuvable: ' + docId);
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

  const sections = parseSectionsFromExtract(full.extract);
  const picked = pickSectionText(sections, full.lang);
  const limit = (t) => (t ? t.slice(0, 2000) : t);

  let habitat = picked.habitat || extractByKeywords(full.extract, full.lang === 'en' ? ['habitat', 'forest', 'mountain', 'wetland', 'urban'] : ['habitat', 'forêt', 'montagne', 'humide', 'urbain', 'milieu']);
  let alimentation = picked.alimentation || extractByKeywords(full.extract, full.lang === 'en' ? ['diet', 'feeds on', 'feeding', 'food'] : ['alimentation', 'régime', 'se nourrit', 'nourriture']);
  let reproduction = picked.reproduction || extractByKeywords(full.extract, full.lang === 'en' ? ['breeding', 'nest', 'egg', 'incubation'] : ['reproduction', 'nid', 'œuf', 'oeuf', 'incubation']);
  let protection = picked.protection || extractByKeywords(full.extract, full.lang === 'en' ? ['conservation', 'status', 'threat'] : ['conservation', 'statut', 'protection', 'menace']);

  habitat = limit(sanitize(habitat));
  alimentation = limit(sanitize(alimentation));
  reproduction = limit(sanitize(reproduction));
  protection = limit(sanitize(protection));

  habitat = await paraphrase(habitat, { maxAttempts: 6, maxSim: 0.7 });
  if (sleepMs) await new Promise(r => setTimeout(r, sleepMs));
  alimentation = await paraphrase(alimentation, { maxAttempts: 6, maxSim: 0.7 });
  if (sleepMs) await new Promise(r => setTimeout(r, sleepMs));
  reproduction = await paraphrase(reproduction, { maxAttempts: 6, maxSim: 0.7 });
  if (sleepMs) await new Promise(r => setTimeout(r, sleepMs));
  protection = await paraphrase(protection, { maxAttempts: 6, maxSim: 0.7 });

  const updates = {};
  if (habitat) updates.habitat = { ...(data.habitat || {}), description: habitat };
  if (alimentation) updates.alimentation = { ...(data.alimentation || {}), description: alimentation };
  if (reproduction) updates.reproduction = { ...(data.reproduction || {}), description: reproduction };
  if (protection) updates.protectionEtatActuel = { ...(data.protectionEtatActuel || {}), description: protection };

  if (Object.keys(updates).length === 0) {
    console.log('↷ Aucune section détectée');
    process.exit(0);
  }

  await doc.ref.set(updates, { merge: true });
  console.log('✅ Sections mises à jour pour', docId, Object.keys(updates));
}

if (require.main === module) {
  main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
}


