"use strict";
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
exports.verifierAbonnement = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const googleapis_1 = require("googleapis");
admin.initializeApp();
const androidpublisher = googleapis_1.google.androidpublisher('v3');
async function getSubState(packageName, token) {
    const auth = await googleapis_1.google.auth.getClient({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    googleapis_1.google.options({ auth });
    const res = await androidpublisher.purchases.subscriptionsv2.get({ packageName, token });
    return res.data;
}
exports.verifierAbonnement = functions
    .region('europe-west1')
    .runWith({ timeoutSeconds: 20, memory: '256MB' })
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    }
    const { packageName, subscriptionId, purchaseToken } = data || {};
    if (!packageName || !subscriptionId || !purchaseToken) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing fields');
    }
    const uid = context.auth.uid;
    const now = admin.firestore.Timestamp.now();
    const sub = await getSubState(packageName, purchaseToken);
    const line = sub?.lineItems?.[0];
    const basePlanId = line?.offerDetails?.basePlanId || null;
    const renewal = sub?.renewalTime ? Number(sub.renewalTime) : null;
    const startMs = line?.startTime || sub?.startTime || null;
    const endMs = line?.expiryTime || sub?.expiryTime || null;
    const autoRenew = sub?.autoRenewEnabled === true;
    const stateRaw = sub?.subscriptionState || '';
    // Déterminer etat (technique) + phase (FR) + accès autorisé
    let state = 'PENDING';
    let phase = 'en_attente';
    let access = true;
    const nowMs = Date.now();
    const endMsNum = endMs ? Number(endMs) : undefined;
    if (stateRaw.includes('ACTIVE')) {
        state = 'ACTIVE';
        phase = 'actif';
        access = true;
    }
    else if (stateRaw.includes('CANCELED')) {
        // Annulé mais accès jusqu'à fin de période
        if (endMsNum && endMsNum > nowMs) {
            state = 'CANCELED';
            phase = 'annulé';
            access = true;
        }
        else {
            state = 'EXPIRED';
            phase = 'expiré';
            access = false;
        }
    }
    else if (stateRaw.includes('EXPIRED')) {
        state = 'EXPIRED';
        phase = 'expiré';
        access = false;
    }
    else if (stateRaw.includes('PAUSED')) {
        state = 'SUSPENDED';
        phase = 'suspendu';
        access = false;
    }
    else if (stateRaw.includes('ON_HOLD') || stateRaw.includes('PENDING')) {
        // Paiement en validation → accès conservé
        state = 'PENDING';
        phase = 'en_attente';
        access = true;
    }
    const priceMicros = line?.pricingDetails?.[0]?.priceAmountMicros;
    const currency = line?.pricingDetails?.[0]?.priceCurrencyCode;
    const periodeCourante = {
        debut: startMs ? admin.firestore.Timestamp.fromMillis(Number(startMs)) : now,
        fin: endMs ? admin.firestore.Timestamp.fromMillis(Number(endMs)) : null,
    };
    const currentRef = admin.firestore().doc(`utilisateurs/${uid}/abonnement/current`);
    const encartRef = admin.firestore().doc(`utilisateurs/${uid}/abonnement/encart`);
    const prev = (await currentRef.get()).data() || null;
    if (prev?.periodeCourante?.debut?.toMillis && prev.periodeCourante.debut.toMillis() !== periodeCourante.debut.toMillis()) {
        await admin.firestore().collection(`utilisateurs/${uid}/abonnement/historique/cycles`).add({
            periodeCourante: prev.periodeCourante,
            etat: (prev.etat === 'ACTIVE') ? 'PAST' : prev.etat,
            offre: prev.offre,
            prix: prev.prix,
            packageName: prev.packageName,
            subscriptionId: prev.subscriptionId,
            createdAt: now,
        });
    }
    const dureeDeclarative = typeof subscriptionId === 'string' && subscriptionId.includes('1mois') ? 'P1M' :
        typeof subscriptionId === 'string' && subscriptionId.includes('6mois') ? 'P6M' :
            typeof subscriptionId === 'string' && subscriptionId.includes('12mois') ? 'P1Y' : undefined;
    await currentRef.set({
        etat: state,
        phase,
        periodeCourante,
        prochaineFacturation: renewal ? admin.firestore.Timestamp.fromMillis(renewal) : null,
        offre: { productId: subscriptionId, basePlanId, variantId: (subscriptionId || '').endsWith('_2') ? '2' : '1' },
        renouvellement: { auto: autoRenew },
        prix: (priceMicros && currency) ? { montant: Number(priceMicros) / 1000000, devise: currency, dureeDeclarative } : admin.firestore.FieldValue.delete(),
        packageName,
        subscriptionId,
        lastToken: purchaseToken,
        lastSync: now,
        accesAutorise: access,
        dateEtat: now,
    }, { merge: true });
    const plan = (subscriptionId || '').startsWith('premium_1mois') ? 'Abonnement 1 mois'
        : (subscriptionId || '').startsWith('premium_6mois') ? 'Abonnement 6 mois'
            : (subscriptionId || '').startsWith('premium_12mois') ? 'Abonnement 12 mois' : 'Abonnement';
    await encartRef.set({
        plan,
        debutFacturation: periodeCourante.debut,
        prochaineFacturation: renewal ? admin.firestore.Timestamp.fromMillis(renewal) : null,
        renouvellementAutomatique: autoRenew,
        updatedAt: now,
        // Essai gratuit 3 jours (déclaratif côté business).
        essai: {
            debut: periodeCourante.debut,
            fin: admin.firestore.Timestamp.fromMillis(periodeCourante.debut.toMillis() + 3 * 24 * 60 * 60 * 1000),
            actif: state === 'ACTIVE' ? false : true,
        },
    }, { merge: true });
    return { ok: true, state, basePlanId, autoRenew };
});
