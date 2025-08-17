#!/usr/bin/env node
const admin = require('firebase-admin');
const sa = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

function snip(text, n = 220) {
  if (!text) return '';
  const s = String(text).trim();
  return s.length > n ? s.slice(0, n) + '…' : s;
}

async function main() {
  const args = process.argv.slice(2);
  const idArg = args.find(a => a.startsWith('--id='));
  const docId = idArg ? idArg.split('=')[1] : 'o_2';
  const doc = await db.collection('fiches_oiseaux').doc(docId).get();
  if (!doc.exists) {
    console.log('❌ Doc introuvable:', docId);
    return;
  }
  const x = doc.data();
  console.log('Doc:', docId, 'appId=', x.appId || '');
  console.log('identification:', snip(x?.identification?.description));
  console.log('morphologie:', snip(x?.identification?.morphologie));
  console.log('habitat:', snip(x?.habitat?.description));
  console.log('alimentation:', snip(x?.alimentation?.description));
  console.log('reproduction:', snip(x?.reproduction?.description));
  console.log('protectionEtatActuel:', snip(x?.protectionEtatActuel?.description));
}

if (require.main === module) {
  main().then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1);});
}


