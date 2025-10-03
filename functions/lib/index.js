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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeWebhook = exports.stripeCreatePortal = exports.stripeCreateCheckout = exports.androidRtdn = exports.verifierAbonnementV3 = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const pubsub_1 = require("firebase-functions/v2/pubsub");
const v2_1 = require("firebase-functions/v2");
const logger = __importStar(require("firebase-functions/logger"));
const googleapis_1 = require("googleapis");
const uuid = __importStar(require("uuid"));
const crypto_1 = require("crypto");
const stripe_1 = __importDefault(require("stripe"));
admin.initializeApp();
(0, v2_1.setGlobalOptions)({ region: 'europe-west1' });
function hashToken(token) {
    return 'sha256:' + (0, crypto_1.createHash)('sha256').update(token).digest('hex');
}
const db = admin.firestore();
// Expect service account with Play Developer API access (Android Publisher v3)
async function getAndroidPublisherClient() {
    const auth = new googleapis_1.google.auth.GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    // Passer l'instance GoogleAuth directement pour satisfaire les types
    const androidpublisher = googleapis_1.google.androidpublisher({ version: 'v3', auth });
    return androidpublisher;
}
exports.verifierAbonnementV3 = (0, https_1.onCall)(async (request) => {
    const data = request.data;
    const packageName = data?.packageName;
    const subscriptionId = data?.subscriptionId;
    const purchaseToken = data?.purchaseToken;
    const uid = data?.uid ?? request.auth?.uid ?? undefined;
    if (!packageName || !subscriptionId || !purchaseToken) {
        throw new https_1.HttpsError('invalid-argument', 'Missing required fields');
    }
    if (!uid) {
        // Permet l’usage sans uid si la CF est utilisée pour un simple check serveur
        logger.warn('No uid passed to verifierAbonnementV3; Firestore writes will be skipped');
    }
    const publisher = await getAndroidPublisherClient();
    try {
        // Subscriptions v2 (purchases.subscriptionsv2.get)
        const subs = await publisher.purchases.subscriptionsv2.get({
            packageName,
            token: purchaseToken,
        });
        const status = subs.data.subscriptionState; // e.g., ACTIVE, PENDING, CANCELED, EXPIRED, PAUSED, IN_GRACE_PERIOD
        const lineItem = subs.data.lineItems?.[0];
        const expiryTimeMillis = lineItem?.expiryTime ?? undefined;
        const autoRenewing = lineItem?.autoRenewingPlan?.autoRenewEnabled ?? false;
        // ACK si nécessaire (ack seulement pour achats non reconnus)
        // Note: avec Subscriptions v2, l’ACK passe par purchases.subscriptions.acknowledge (v3)
        if (status === 'ACTIVE' || status === 'FREE_TRIAL') {
            try {
                await publisher.purchases.subscriptions.acknowledge({
                    packageName,
                    subscriptionId,
                    token: purchaseToken,
                    requestBody: { developerPayload: `ack:${uuid.v4()}` },
                });
            }
            catch (e) {
                // Si déjà ack, Google renvoie une erreur; on ignore
                logger.info('Acknowledge attempt finished', { e });
            }
        }
        // Ecritures Firestore (batch atomique si uid dispo)
        if (uid) {
            const userRef = db.doc(`utilisateurs/${uid}`);
            const currentRef = userRef.collection('abonnement').doc('current');
            const encartRef = userRef.collection('abonnement').doc('encart');
            const now = admin.firestore.Timestamp.now();
            const nowMs = Date.now();
            // Normaliser état Play → cible
            const normalizeState = (s) => {
                switch (s) {
                    case 'IN_GRACE_PERIOD': return 'GRACE';
                    case 'ON_HOLD': return 'PAYMENT_RETRY';
                    case 'PAUSED': return 'SUSPENDED';
                    case 'FREE_TRIAL': return 'ACTIVE';
                    case 'ACTIVE':
                    case 'PENDING':
                    case 'CANCELED':
                    case 'EXPIRED':
                        return s;
                    default:
                        return 'UNKNOWN';
                }
            };
            const etat = normalizeState(status ?? undefined);
            const finTs = expiryTimeMillis ? admin.firestore.Timestamp.fromMillis(Number(expiryTimeMillis)) : null;
            const finMs = expiryTimeMillis ? Number(expiryTimeMillis) : null;
            // estPremium selon règles
            const estPremium = (etat === 'ACTIVE' || etat === 'GRACE' || etat === 'PAYMENT_RETRY' ||
                (etat === 'CANCELED' && !!finMs && nowMs < finMs));
            // current document (merge)
            const currentDoc = {
                etat,
                offre: { productId: subscriptionId },
                autoRenewing,
                periodeCourante: { debut: null, fin: finTs },
                prochaineFacturation: finTs,
                packageName,
                platform: 'android',
                lastTokenHash: hashToken(purchaseToken),
                lastSync: now,
                sourceMaj: 'CF',
            };
            // encart minimal (optionnel)
            const encartDoc = {
                produitId: subscriptionId,
                renouvellementAutomatique: autoRenewing,
                prochaineFacturation: finTs,
            };
            const profilUpdate = {
                estPremium,
                premiumActiveUntil: finTs ?? null,
                updatedAt: now,
            };
            const vieUpdate = {
                livesInfinite: estPremium,
                updatedAt: now,
            };
            const batch = db.batch();
            batch.set(currentRef, currentDoc, { merge: true });
            batch.set(encartRef, encartDoc, { merge: true });
            batch.set(userRef, { profil: profilUpdate }, { merge: true });
            batch.set(userRef, { vie: vieUpdate }, { merge: true });
            await batch.commit();
        }
        return { success: true, state: subs.data.subscriptionState, expiryTimeMillis: expiryTimeMillis ? Number(expiryTimeMillis) : undefined };
    }
    catch (e) {
        logger.error('verifierAbonnementV3 error', { e });
        return { success: false };
    }
});
// Real‑time Developer Notifications (RTDN) handler for subscription lifecycle updates
// Configure your Play Console to publish RTDN to Pub/Sub topic 'play-rtdn'
// Then deploy this function to react to renewals/expirations without opening the app
exports.androidRtdn = (0, pubsub_1.onMessagePublished)('play-rtdn', async (event) => {
    try {
        const maybeJson = event.data?.message?.json;
        const maybeBase64 = event.data?.message?.data;
        const payload = maybeJson ?? (maybeBase64 ? JSON.parse(Buffer.from(maybeBase64, 'base64').toString('utf8')) : undefined);
        if (!payload) {
            logger.warn('RTDN payload missing');
            return;
        }
        const packageName = payload?.packageName;
        const subNotif = payload?.subscriptionNotification;
        const subscriptionId = subNotif?.subscriptionId;
        const purchaseToken = subNotif?.purchaseToken;
        const notificationType = subNotif?.notificationType;
        if (!packageName || !subscriptionId || !purchaseToken) {
            logger.warn('RTDN missing fields', { packageName, subscriptionId, hasToken: !!purchaseToken, notificationType });
            return;
        }
        // Query latest state from Play
        const publisher = await getAndroidPublisherClient();
        const subs = await publisher.purchases.subscriptionsv2.get({ packageName, token: purchaseToken });
        const status = subs.data.subscriptionState; // ACTIVE | PENDING | IN_GRACE_PERIOD | PAUSED | ON_HOLD | CANCELED | EXPIRED | FREE_TRIAL
        const lineItem = subs.data.lineItems?.[0];
        const expiryTimeMillis = lineItem?.expiryTime ? Number(lineItem.expiryTime) : undefined;
        const autoRenewing = lineItem?.autoRenewingPlan?.autoRenewEnabled ?? false;
        // Map purchaseToken -> uid via collectionGroup on 'abonnement'
        const tokenHits = await db.collectionGroup('abonnement').where('lastTokenHash', '==', hashToken(purchaseToken)).limit(1).get();
        if (tokenHits.empty) {
            logger.info('RTDN: No user found for token, skipping Firestore write', { purchaseToken });
            return;
        }
        const currentDocHit = tokenHits.docs[0];
        const userRef = currentDocHit.ref.parent.parent; // utilisateurs/{uid}
        const uid = userRef.id;
        const currentRef = userRef.collection('abonnement').doc('current');
        const encartRef = userRef.collection('abonnement').doc('encart');
        const now = admin.firestore.Timestamp.now();
        const nowMs = Date.now();
        const normalizeState = (s) => {
            switch (s) {
                case 'IN_GRACE_PERIOD': return 'GRACE';
                case 'ON_HOLD': return 'PAYMENT_RETRY';
                case 'PAUSED': return 'SUSPENDED';
                case 'FREE_TRIAL': return 'ACTIVE';
                case 'ACTIVE':
                case 'PENDING':
                case 'CANCELED':
                case 'EXPIRED': return s;
                default: return 'UNKNOWN';
            }
        };
        const etat = normalizeState(status ?? undefined);
        const finTs = expiryTimeMillis ? admin.firestore.Timestamp.fromMillis(expiryTimeMillis) : null;
        const finMs = expiryTimeMillis ?? null;
        const estPremium = (etat === 'ACTIVE' || etat === 'GRACE' || etat === 'PAYMENT_RETRY' || (etat === 'CANCELED' && !!finMs && nowMs < finMs));
        const currentDoc = {
            etat,
            offre: { productId: subscriptionId },
            autoRenewing,
            periodeCourante: { debut: null, fin: finTs },
            prochaineFacturation: finTs,
            packageName,
            platform: 'android',
            lastTokenHash: hashToken(purchaseToken),
            lastSync: now,
            sourceMaj: 'RTDN',
        };
        const encartDoc = {
            produitId: subscriptionId,
            renouvellementAutomatique: autoRenewing,
            prochaineFacturation: finTs,
            majPar: 'RTDN',
        };
        const profilUpdate = { estPremium, premiumActiveUntil: finTs ?? null, updatedAt: now };
        const vieUpdate = { livesInfinite: estPremium, updatedAt: now };
        const batch = db.batch();
        batch.set(currentRef, currentDoc, { merge: true });
        batch.set(encartRef, encartDoc, { merge: true });
        batch.set(userRef, { profil: profilUpdate }, { merge: true });
        batch.set(userRef, { vie: vieUpdate }, { merge: true });
        const messageId = event.data?.message?.messageId ?? uuid.v4();
        const histRef = userRef.collection('abonnement_history').doc(messageId);
        batch.set(histRef, { type: etat, at: now, source: 'RTDN', payload: { notificationType: notificationType ?? null, purchaseTokenHash: hashToken(purchaseToken) } });
        await batch.commit();
        logger.info('RTDN processed', { uid, etat, notificationType, expiryTimeMillis, autoRenewing });
    }
    catch (e) {
        logger.error('RTDN handler error', { e });
    }
});
// =============== STRIPE (WEB) ABONNEMENTS =================
function getProjectBaseUrl() {
    const base = process.env.BASE_URL;
    if (base && /^https?:\/\//i.test(base))
        return base;
    return 'https://mindbird.fr';
}
function getStripe() {
    const secret = process.env.STRIPE_SECRET;
    if (!secret) {
        throw new Error('STRIPE_SECRET non défini dans les variables d’environnement');
    }
    return new stripe_1.default(secret, { apiVersion: '2023-10-16' });
}
async function ensureStripeCustomerId(uid, email) {
    const userRef = admin.firestore().doc(`utilisateurs/${uid}`);
    const snap = await userRef.get();
    const existing = snap.exists ? snap.data() : null;
    const existingId = existing?.stripe?.customerId;
    if (existingId)
        return existingId;
    const stripe = getStripe();
    const customer = await stripe.customers.create({
        email: email || undefined,
        metadata: { uid },
    });
    await userRef.set({ stripe: { customerId: customer.id, updatedAt: admin.firestore.Timestamp.now() } }, { merge: true });
    return customer.id;
}
async function resolvePriceIdFromPlan(plan) {
    const m = plan?.toLowerCase?.() || '';
    const p1 = process.env.STRIPE_PRICE_1M;
    const p6 = process.env.STRIPE_PRICE_6M;
    const p12 = process.env.STRIPE_PRICE_12M;
    let candidate;
    if (m.includes('12'))
        candidate = p12;
    else if (m.includes('6'))
        candidate = p6;
    else
        candidate = p1;
    if (!candidate)
        throw new Error('Prix Stripe non configuré pour le plan demandé');
    // Si l'utilisateur a saisi un ID de produit (prod_...), on résout vers un prix actif
    if (candidate.startsWith('prod_')) {
        const stripe = getStripe();
        const prices = await stripe.prices.list({ product: candidate, active: true, limit: 1 });
        const price = prices.data[0];
        if (!price?.id) {
            throw new Error(`Aucun prix actif trouvé pour le produit ${candidate}`);
        }
        return price.id;
    }
    return candidate;
}
exports.stripeCreateCheckout = (0, https_1.onCall)({
    secrets: ['STRIPE_SECRET', 'STRIPE_PRICE_1M', 'STRIPE_PRICE_6M', 'STRIPE_PRICE_12M'],
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid)
        throw new https_1.HttpsError('unauthenticated', 'Authentification requise');
    const data = (request.data || {});
    const plan = data.plan || '1m';
    try {
        const userRecord = await admin.auth().getUser(uid).catch(() => null);
        const email = userRecord?.email ?? null;
        const customerId = await ensureStripeCustomerId(uid, email);
        const priceId = await resolvePriceIdFromPlan(plan);
        const base = getProjectBaseUrl();
        const successUrl = `${base}/?checkout=success`;
        const cancelUrl = `${base}/?checkout=cancel`;
        const stripe = getStripe();
        const session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            customer: customerId,
            line_items: [{ price: priceId, quantity: 1 }],
            allow_promotion_codes: true,
            success_url: successUrl,
            cancel_url: cancelUrl,
            client_reference_id: uid,
            subscription_data: {
                metadata: { uid },
            },
            metadata: { uid, plan },
        });
        return { url: session.url };
    }
    catch (e) {
        logger.error('stripeCreateCheckout error', { e });
        throw new https_1.HttpsError('internal', e?.message || 'Erreur interne');
    }
});
exports.stripeCreatePortal = (0, https_1.onCall)({
    secrets: ['STRIPE_SECRET'],
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid)
        throw new https_1.HttpsError('unauthenticated', 'Authentification requise');
    try {
        const userRecord = await admin.auth().getUser(uid).catch(() => null);
        const email = userRecord?.email ?? null;
        const customerId = await ensureStripeCustomerId(uid, email);
        const base = getProjectBaseUrl();
        const returnUrl = `${base}/?portal=return`;
        const stripe = getStripe();
        const session = await stripe.billingPortal.sessions.create({ customer: customerId, return_url: returnUrl });
        return { url: session.url };
    }
    catch (e) {
        logger.error('stripeCreatePortal error', { e });
        throw new https_1.HttpsError('internal', e?.message || 'Erreur interne');
    }
});
exports.stripeWebhook = (0, https_1.onRequest)({
    region: 'europe-west1',
    secrets: ['STRIPE_SECRET', 'STRIPE_WEBHOOK_SECRET'],
}, async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const whSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!whSecret) {
        logger.error('STRIPE_WEBHOOK_SECRET manquant');
        res.status(500).send('Misconfiguration');
        return;
    }
    let event;
    try {
        const stripe = getStripe();
        event = stripe.webhooks.constructEvent(req.rawBody, sig, whSecret);
    }
    catch (err) {
        logger.error('Webhook signature verification failed', { err });
        res.status(400).send(`Webhook Error: ${err.message}`);
        return;
    }
    try {
        const stripe = getStripe();
        switch (event.type) {
            case 'checkout.session.completed': {
                const session = event.data.object;
                const uid = session.client_reference_id || session.metadata?.uid;
                if (!uid)
                    break;
                const subscriptionId = session.subscription;
                let currentPeriodEnd;
                let priceId;
                if (subscriptionId) {
                    const sub = await stripe.subscriptions.retrieve(subscriptionId);
                    currentPeriodEnd = sub.current_period_end ? sub.current_period_end * 1000 : undefined;
                    const price = sub.items.data[0]?.price;
                    priceId = price?.id;
                }
                await writeStripePremium(uid, 'ACTIVE', currentPeriodEnd, priceId, subscriptionId);
                break;
            }
            case 'customer.subscription.updated':
            case 'customer.subscription.created':
            case 'customer.subscription.deleted': {
                const sub = event.data.object;
                const uid = sub.metadata?.uid || undefined;
                const status = sub.status; // trialing, active, past_due, canceled, unpaid, incomplete, incomplete_expired, paused
                const endMs = sub.current_period_end ? sub.current_period_end * 1000 : undefined;
                const priceId = sub.items.data[0]?.price?.id;
                const etat = mapStripeStatusToEtat(status);
                if (uid) {
                    await writeStripePremium(uid, etat, endMs, priceId, sub.id);
                }
                break;
            }
            default:
                break;
        }
        res.json({ received: true });
    }
    catch (e) {
        logger.error('stripeWebhook handling error', { e });
        res.status(500).send('error');
    }
});
function mapStripeStatusToEtat(status) {
    switch (status) {
        case 'active':
        case 'trialing':
            return 'ACTIVE';
        case 'past_due':
            return 'PAYMENT_RETRY';
        case 'paused':
            return 'SUSPENDED';
        case 'canceled':
            return 'CANCELED';
        case 'unpaid':
        case 'incomplete':
        case 'incomplete_expired':
            return 'PENDING';
        default:
            return 'UNKNOWN';
    }
}
async function writeStripePremium(uid, etat, nextBillingMs, priceId, subscriptionId) {
    const db = admin.firestore();
    const userRef = db.doc(`utilisateurs/${uid}`);
    const currentRef = userRef.collection('abonnement').doc('current');
    const encartRef = userRef.collection('abonnement').doc('encart');
    const now = admin.firestore.Timestamp.now();
    const finTs = nextBillingMs ? admin.firestore.Timestamp.fromMillis(Number(nextBillingMs)) : null;
    const nowMs = Date.now();
    const estPremium = (etat === 'ACTIVE' || etat === 'GRACE' || etat === 'PAYMENT_RETRY' || (etat === 'CANCELED' && nextBillingMs && nowMs < nextBillingMs));
    const currentDoc = {
        etat,
        offre: { productId: priceId ?? 'stripe' },
        autoRenewing: true,
        periodeCourante: { debut: null, fin: finTs },
        prochaineFacturation: finTs,
        platform: 'stripe',
        subscriptionId: subscriptionId ?? null,
        lastSync: now,
        sourceMaj: 'STRIPE',
    };
    const encartDoc = {
        produitId: priceId ?? 'stripe',
        renouvellementAutomatique: true,
        prochaineFacturation: finTs,
    };
    const profilUpdate = { estPremium, premiumActiveUntil: finTs ?? null, updatedAt: now };
    const vieUpdate = { livesInfinite: estPremium, updatedAt: now };
    const batch = db.batch();
    batch.set(currentRef, currentDoc, { merge: true });
    batch.set(encartRef, encartDoc, { merge: true });
    batch.set(userRef, { profil: profilUpdate }, { merge: true });
    batch.set(userRef, { vie: vieUpdate }, { merge: true });
    await batch.commit();
}
