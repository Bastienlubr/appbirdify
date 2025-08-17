#!/usr/bin/env node

/**
 * Enrichissement des fiches oiseaux:
 * - Textes par section depuis Wikipédia FR (fallback EN):
 *   identification, habitat, alimentation, reproduction, répartition
 * - Image (Wikipedia originalimage)
 * - Audio (Xeno-Canto, meilleure qualité)
 * - Paraphrase légère (si OPENAI_API_KEY présent)
 * - Sauvegarde dans Firestore (Admin SDK)
 */

const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'birdify-df029'
});

const db = admin.firestore();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';

async function fetchJson(url, headers = {}) {
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}`);
  return res.json();
}

async function fetchWikipediaSummary(nomFr, nomSci) {
  const langs = ['fr', 'en'];
  const titles = [nomFr, nomSci].filter(Boolean);
  for (const lang of langs) {
    for (const title of titles) {
      try {
        const url = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
        const data = await fetchJson(url, { 'accept': 'application/json' });
        if (data && data.extract) {
          return {
            lang,
            title: data.title || title,
            extract: data.extract,
            image: data.originalimage?.source || data.thumbnail?.source || null,
            url: data.content_urls?.desktop?.page || data.content_urls?.mobile?.page || null,
          };
        }
      } catch (e) {
        // try next
      }
    }
  }
  return null;
}

// Récupère l'extrait complet en texte brut depuis MediaWiki pour parser les sections
async function fetchWikipediaExtractFull(nomFr, nomSci) {
  const langs = ['fr', 'en'];
  const titles = [nomFr, nomSci].filter(Boolean);
  for (const lang of langs) {
    for (const title of titles) {
      try {
        const url = `https://${lang}.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1&redirects=1&format=json&titles=${encodeURIComponent(title)}`;
        const data = await fetchJson(url, { 'accept': 'application/json' });
        const pages = data?.query?.pages || {};
        const firstPage = Object.values(pages)[0];
        const extract = firstPage?.extract;
        if (extract && typeof extract === 'string' && extract.trim().length > 0) {
          return { lang, title: firstPage.title || title, extract };
        }
      } catch (e) {
        // try next
      }
    }
  }
  return null;
}

function removeAccents(text) {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}+/gu, '')
    .toLowerCase();
}

// Parse l'extrait Wikipédia en sections par titres == ... ==
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
  // Map normalisé -> texte
  const map = new Map();
  for (const s of sections) {
    const key = removeAccents((s.title || 'intro').trim());
    const text = s.content.join('\n').trim();
    if (!map.has(key)) map.set(key, text);
  }
  return map;
}

function pickSectionText(sectionMap, lang) {
  // Alias par langue
  const aliases = {
    identification: lang === 'en'
      ? ['description', 'identification', 'morphology']
      : ['description', 'identification', 'morphologie'],
    habitat: lang === 'en'
      ? ['habitat', 'ecology', 'environment']
      : ['habitat', 'ecologie', 'milieu', 'habitat et ecologie'],
    alimentation: lang === 'en'
      ? ['diet', 'feeding', 'food']
      : ['alimentation', 'regime alimentaire', 'nourriture'],
    reproduction: lang === 'en'
      ? ['breeding', 'reproduction']
      : ['reproduction', 'cycle de vie'],
    repartition: lang === 'en'
      ? ['distribution', 'range', 'geographic range']
      : ['repartition', 'aire de repartition', 'distribution', 'geographie'],
  };

  function findFirst(keys) {
    for (const k of keys) {
      const nk = removeAccents(k);
      if (sectionMap.has(nk)) {
        const t = sectionMap.get(nk);
        if (t && t.trim()) return t.trim();
      }
      // Recherche partielle sur les clés disponibles
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
    identification: findFirst(aliases.identification),
    habitat: findFirst(aliases.habitat),
    alimentation: findFirst(aliases.alimentation),
    reproduction: findFirst(aliases.reproduction),
    repartition: findFirst(aliases.repartition),
  };
}

function extractByKeywords(text, keywords) {
  if (!text) return null;
  const sentences = text
    .replace(/\s+/g, ' ')
    .split(/(?<=[.!?])\s+/);
  const norm = s => removeAccents(s).toLowerCase();
  const joined = [];
  for (const s of sentences) {
    const ns = norm(s);
    if (keywords.some(k => ns.includes(norm(k)))) {
      joined.push(s.trim());
      if (joined.join(' ').length > 800) break;
    }
  }
  return joined.length ? joined.join(' ') : null;
}

function pickBestXenoRecording(recordings) {
  if (!Array.isArray(recordings) || recordings.length === 0) return null;
  // Prioriser qualité A puis B, avec foreground "yes"
  const score = r => ((r.q === 'A') ? 2 : (r.q === 'B') ? 1 : 0) + (r.foreground === 'yes' ? 0.5 : 0);
  let best = recordings[0];
  let bestScore = score(best);
  for (const r of recordings.slice(1)) {
    const s = score(r);
    if (s > bestScore) { best = r; bestScore = s; }
  }
  // URL du fichier audio direct
  // API renvoie par ex: https://xeno-canto.org/123456/download
  // On peut aussi utiliser le champ 'file' qui est souvent un mp3 direct
  return best.file || best.url || null;
}

async function fetchXenoCanto(genus, species) {
  if (!genus || !species) return null;
  const query = `https://xeno-canto.org/api/2/recordings?query=gen:${encodeURIComponent(genus)}%20sp:${encodeURIComponent(species)}`;
  try {
    const data = await fetchJson(query, { 'accept': 'application/json' });
    const file = pickBestXenoRecording(data.recordings || []);
    if (file) {
      return {
        file,
        source: 'Xeno-Canto',
        apiUrl: query,
      };
    }
  } catch (e) {
    // ignore
  }
  return null;
}

async function paraphraseIfPossible(text) {
  if (!text || !OPENAI_API_KEY) return text;
  try {
    const body = {
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'Tu es un assistant qui reformule légèrement du contenu en français sans ajouter d\'information et sans altérer les faits.'
        },
        {
          role: 'user',
          content: `Reformule légèrement ce texte en français, sans ajouter d\'informations, sans changer le sens, en gardant un ton encyclopédique clair:\n\n${text}`
        }
      ],
      temperature: 0.2,
      max_tokens: Math.min(800, Math.ceil(text.length * 1.2)),
    };
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    if (!res.ok) throw new Error(`OpenAI HTTP ${res.status}`);
    const json = await res.json();
    const out = json.choices?.[0]?.message?.content?.trim();
    return out || text;
  } catch (e) {
    return text; // fallback
  }
}

function sanitize(text) {
  if (!text) return text;
  // Retirer les références [1], (cf. ...), multiples espaces
  return text
    .replace(/\s*\[[^\]]*\]/g, '')
    .replace(/\s*\([^)]*cf\.[^)]*\)/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

async function enrichOneDoc(doc) {
  const data = doc.data();
  const nomFr = data.nomFrancais || '';
  const nomSci = data.nomScientifique || '';
  const parts = nomSci.split(' ');
  const genus = parts.length > 0 ? parts[0] : '';
  const species = parts.length > 1 ? parts[1] : '';
  const appId = nomSci ? nomSci.toLowerCase().replace(/\s+/g, '_') : null;

  // Wikipedia
  const wiki = await fetchWikipediaSummary(nomFr, nomSci);
  const full = await fetchWikipediaExtractFull(nomFr, nomSci);
  let identificationText = wiki?.extract ? sanitize(wiki.extract) : null;
  let habitatText = null;
  let alimentationText = null;
  let reproductionText = null;
  let repartitionText = null;

  if (full?.extract) {
    const sections = parseSectionsFromExtract(full.extract);
    const picked = pickSectionText(sections, full.lang);
    // Limiter un peu la longueur pour paraphrase
    const limit = (t) => t ? t.slice(0, 2000) : t;
    identificationText = picked.identification ? sanitize(picked.identification) : identificationText;
    habitatText = picked.habitat ? sanitize(limit(picked.habitat)) : null;
    alimentationText = picked.alimentation ? sanitize(limit(picked.alimentation)) : null;
    reproductionText = picked.reproduction ? sanitize(limit(picked.reproduction)) : null;
    repartitionText = picked.repartition ? sanitize(limit(picked.repartition)) : null;
  }

  // Fallback par mots-clés si sections manquantes
  if (!alimentationText && full?.extract) {
    const keys = full.lang === 'en'
      ? ['diet', 'feed', 'feeds on', 'food']
      : ['alimentation', 'régime', 'se nourrit', 'nourrit', 'nourriture'];
    alimentationText = extractByKeywords(full.extract, keys);
  }
  if (!habitatText && full?.extract) {
    const keys = full.lang === 'en'
      ? ['habitat', 'forest', 'mountain', 'wetland', 'urban']
      : ['habitat', 'forêt', 'montagne', 'milieu', 'humide', 'urbain'];
    habitatText = extractByKeywords(full.extract, keys);
  }
  if (!reproductionText && full?.extract) {
    const keys = full.lang === 'en'
      ? ['breeding', 'nest', 'egg', 'incubation']
      : ['reproduction', 'nid', 'œuf', 'oeuf', 'incubation'];
    reproductionText = extractByKeywords(full.extract, keys);
  }
  if (!repartitionText && full?.extract) {
    const keys = full.lang === 'en'
      ? ['distribution', 'range', 'present in']
      : ['répartition', 'présent', 'distribution', 'aire'];
    repartitionText = extractByKeywords(full.extract, keys);
  }

  // Paraphrase par section
  identificationText = await paraphraseIfPossible(identificationText);
  habitatText = await paraphraseIfPossible(habitatText);
  alimentationText = await paraphraseIfPossible(alimentationText);
  reproductionText = await paraphraseIfPossible(reproductionText);
  repartitionText = await paraphraseIfPossible(repartitionText);

  // Xeno-Canto
  const xeno = await fetchXenoCanto(genus, species);

  const updates = {};
  const sources = [];

  // Assurer un champ de jointure stable avec l'app
  if (appId && data.appId !== appId) {
    updates['appId'] = appId;
  }

  if (identificationText) {
    updates.identification = { ...(updates.identification || {}), description: identificationText };
    if (wiki?.url) sources.push(wiki.url);
  }
  if (habitatText) {
    updates.habitat = { ...(updates.habitat || {}), description: habitatText };
  }
  if (alimentationText) {
    updates.alimentation = { ...(updates.alimentation || {}), description: alimentationText };
  }
  if (reproductionText) {
    updates.reproduction = { ...(updates.reproduction || {}), description: reproductionText };
  }
  if (repartitionText) {
    updates.repartition = { ...(updates.repartition || {}), description: repartitionText };
  }
  if (wiki?.image) {
    updates.medias = { ...(updates.medias || {}), imagePrincipale: wiki.image };
  }
  if (xeno?.file) {
    updates.vocalisations = { ...(updates.vocalisations || {}), fichierAudio: xeno.file };
    sources.push('https://xeno-canto.org');
  }

  if (sources.length) {
    updates.sources = { ...(updates.sources || {}), references: admin.firestore.FieldValue.arrayUnion(...sources) };
  }

  if (Object.keys(updates).length === 0) return { updated: false };

  // Migration: corriger d'anciens champs dotés (ex: "alimentation.description")
  const deletions = {};
  const dottedKeys = [
    'identification.description',
    'habitat.description',
    'alimentation.description',
    'reproduction.description',
    'repartition.description',
    'medias.imagePrincipale',
    'vocalisations.fichierAudio',
    'sources.references',
  ];
  for (const k of dottedKeys) {
    if (Object.prototype.hasOwnProperty.call(data, k)) {
      deletions[k] = admin.firestore.FieldValue.delete();
    }
  }

  await doc.ref.set(updates, { merge: true });
  if (Object.keys(deletions).length) {
    await doc.ref.update(deletions);
  }
  return { updated: true };
}

async function main() {
  const args = process.argv.slice(2);
  const limitArg = args.find(a => a.startsWith('--limit='));
  const idArg = args.find(a => a.startsWith('--id='));
  const allFlag = args.includes('--all');
  let limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : 20;
  if (!Number.isFinite(limit) || limit <= 0) limit = 20;

  let ok = 0, skip = 0, err = 0;

  if (idArg) {
    const id = idArg.split('=')[1];
    const doc = await db.collection('fiches_oiseaux').doc(id).get();
    if (!doc.exists) {
      console.log(`❌ Doc introuvable: ${id}`);
    } else {
      try {
        const res = await enrichOneDoc(doc);
        if (res.updated) { ok++; console.log(`✅ ${doc.id} enrichi`); }
        else { skip++; console.log(`↷ ${doc.id} rien à ajouter`); }
      } catch (e) {
        err++; console.log(`❌ ${doc.id} erreur: ${e.message}`);
      }
    }
  } else if (allFlag) {
    let lastDoc = null;
    while (true) {
      let query = db.collection('fiches_oiseaux').orderBy('__name__').limit(500);
      if (lastDoc) query = query.startAfter(lastDoc);
      const snapshot = await query.get();
      if (snapshot.empty) break;
      for (const doc of snapshot.docs) {
        try {
          const res = await enrichOneDoc(doc);
          if (res.updated) { ok++; console.log(`✅ ${doc.id} enrichi`); }
          else { skip++; console.log(`↷ ${doc.id} rien à ajouter`); }
        } catch (e) {
          err++; console.log(`❌ ${doc.id} erreur: ${e.message}`);
        }
      }
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      if (snapshot.size < 500) break;
    }
  } else {
    const snapshot = await db.collection('fiches_oiseaux').limit(limit).get();
    for (const doc of snapshot.docs) {
      try {
        const res = await enrichOneDoc(doc);
        if (res.updated) { ok++; console.log(`✅ ${doc.id} enrichi`); }
        else { skip++; console.log(`↷ ${doc.id} rien à ajouter`); }
      } catch (e) {
        err++; console.log(`❌ ${doc.id} erreur: ${e.message}`);
      }
    }
  }

  console.log(`\nRésumé: ${ok} mis à jour, ${skip} sans changement, ${err} erreurs`);
}

if (require.main === module) {
  // Node 18+ global fetch
  if (typeof fetch !== 'function') {
    global.fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));
  }
  main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
}

module.exports = { main };
