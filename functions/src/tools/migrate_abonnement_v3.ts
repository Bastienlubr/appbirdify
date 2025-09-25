/*
  One-shot migration tool (DRY-RUN by default) to converge abonnement schema.
  Usage examples:
    - DRY RUN all: npm run migrate:v3
    - DRY RUN one uid: npm run migrate:v3 -- --only uid=ABC123
    - APPLY all: DRY_RUN=false npm run migrate:v3
*/

import * as admin from 'firebase-admin';
import { createHash } from 'crypto';

// Initialize only if not already
try { admin.app(); } catch { admin.initializeApp(); }
const db = admin.firestore();

type Args = { onlyUid?: string | null; dryRun: boolean; batchSize: number };

function parseArgs(): Args {
  const argv = process.argv.slice(2);
  let onlyUid: string | null = null;
  for (const a of argv) {
    if (a.startsWith('uid=')) onlyUid = a.substring('uid='.length);
  }
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() !== 'false';
  const batchSize = Number(process.env.BATCH_SIZE ?? 200);
  return { onlyUid, dryRun, batchSize };
}

function nowTs() { return admin.firestore.Timestamp.now(); }

function buildPatches(uid: string, root: FirebaseFirestore.DocumentData | undefined,
  current: FirebaseFirestore.DocumentData | undefined,
  encart: FirebaseFirestore.DocumentData | undefined) {
  const userPatch: Record<string, any> = {};
  const currentPatch: Record<string, any> = {};
  const currentDelete: Record<string, any> = {};
  const encartPatch: Record<string, any> = {};

  // profil.updatedAt
  userPatch['profil.updatedAt'] = nowTs();

  // vie.updatedAt
  userPatch['vie.updatedAt'] = nowTs();

  // current defaults
  currentPatch['lastSync'] = nowTs();
  currentPatch['sourceMaj'] = 'CF';
  currentPatch['platform'] = 'android';

  // Rename renouvellement.auto -> autoRenewing
  const renewAuto = current?.renouvellement?.auto;
  if (typeof renewAuto === 'boolean') {
    currentPatch['autoRenewing'] = renewAuto;
  }

  // Migrate subscriptionId -> offre.productId if missing
  const subId = current?.subscriptionId as (string | undefined);
  const productId = current?.offre?.productId as (string | undefined);
  if (!productId && subId) {
    currentPatch['offre'] = { ...(current?.offre ?? {}), productId: subId };
  }

  // Remove legacy fields
  if (current?.renouvellement) {
    currentDelete['renouvellement'] = admin.firestore.FieldValue.delete();
  }
  if (typeof current?.lastToken === 'string' && (!current?.lastTokenHash)) {
    const hash = 'sha256:' + createHash('sha256').update(current.lastToken).digest('hex');
    currentPatch['lastTokenHash'] = hash;
    currentDelete['lastToken'] = admin.firestore.FieldValue.delete();
  }
  if (typeof current?.joursEssaiRestants !== 'undefined') {
    currentDelete['joursEssaiRestants'] = admin.firestore.FieldValue.delete();
  }

  return { userPatch, currentPatch, currentDelete, encartPatch };
}

async function run() {
  const { onlyUid, dryRun, batchSize } = parseArgs();
  const usersCol = db.collection('utilisateurs');
  let processed = 0;

  const writeBatch = () => db.batch();
  let batch = writeBatch();
  let writes = 0;

  const processDoc = async (uid: string) => {
    const userRef = usersCol.doc(uid);
    const [rootSnap, currentSnap, encartSnap] = await Promise.all([
      userRef.get(),
      userRef.collection('abonnement').doc('current').get(),
      userRef.collection('abonnement').doc('encart').get(),
    ]);
    const root = rootSnap.data();
    const current = currentSnap.data();
    const encart = encartSnap.data();

    const { userPatch, currentPatch, currentDelete } = buildPatches(uid, root, current, encart);
    const ops = {
      uid,
      userPatch,
      currentPatch,
      currentDelete,
    };

    if (dryRun) {
      // eslint-disable-next-line no-console
      console.log(JSON.stringify(ops));
      return;
    }

    if (Object.keys(userPatch).length > 0) {
      batch.set(userRef, userPatch, { merge: true });
      writes++;
    }
    if (Object.keys(currentPatch).length > 0 || Object.keys(currentDelete).length > 0) {
      const payload = { ...currentPatch, ...currentDelete };
      batch.set(userRef.collection('abonnement').doc('current'), payload, { merge: true });
      writes++;
    }

    if (writes >= batchSize) {
      await batch.commit();
      batch = writeBatch();
      writes = 0;
    }
  };

  if (onlyUid) {
    await processDoc(onlyUid);
  } else {
    const snap = await usersCol.select().get();
    for (const d of snap.docs) {
      await processDoc(d.id);
      processed++;
    }
  }

  if (!dryRun && writes > 0) {
    await batch.commit();
  }

  // eslint-disable-next-line no-console
  console.log(`Done. processed=${processed}, dryRun=${dryRun}`);
}

run().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});


