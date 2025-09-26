"use strict";
/*
  One-shot migration tool (DRY-RUN by default) to converge abonnement schema.
  Usage examples:
    - DRY RUN all: npm run migrate:v3
    - DRY RUN one uid: npm run migrate:v3 -- --only uid=ABC123
    - APPLY all: DRY_RUN=false npm run migrate:v3
*/
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const admin = __importStar(require("firebase-admin"));
const crypto_1 = require("crypto");
// Initialize only if not already
try {
    admin.app();
}
catch {
    admin.initializeApp();
}
const db = admin.firestore();
function parseArgs() {
    const argv = process.argv.slice(2);
    let onlyUid = null;
    for (const a of argv) {
        if (a.startsWith('uid='))
            onlyUid = a.substring('uid='.length);
    }
    const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() !== 'false';
    const batchSize = Number(process.env.BATCH_SIZE ?? 200);
    return { onlyUid, dryRun, batchSize };
}
function nowTs() { return admin.firestore.Timestamp.now(); }
function buildPatches(uid, root, current, encart) {
    const userPatch = {};
    const currentPatch = {};
    const currentDelete = {};
    const encartPatch = {};
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
    const subId = current?.subscriptionId;
    const productId = current?.offre?.productId;
    if (!productId && subId) {
        currentPatch['offre'] = { ...(current?.offre ?? {}), productId: subId };
    }
    // Remove legacy fields
    if (current?.renouvellement) {
        currentDelete['renouvellement'] = admin.firestore.FieldValue.delete();
    }
    if (typeof current?.lastToken === 'string' && (!current?.lastTokenHash)) {
        const hash = 'sha256:' + (0, crypto_1.createHash)('sha256').update(current.lastToken).digest('hex');
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
    const processDoc = async (uid) => {
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
    }
    else {
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
