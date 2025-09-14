const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

try { admin.initializeApp(); } catch (_) {}

exports.verifierAbonnement = functions.region('europe-west1').https.onCall(async (data, context) => {
  const { uid, packageName, subscriptionId, purchaseToken } = data || {};
  if (!context.auth || !context.auth.uid || context.auth.uid !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Authentification requise');
  }
  if (!purchaseToken || !subscriptionId) {
    throw new functions.https.HttpsError('invalid-argument', 'purchaseToken et subscriptionId requis');
  }

  try {
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const client = await auth.getClient();
    const androidpublisher = google.androidpublisher({ version: 'v3', auth: client });

    // Appel Play Developer API v3: purchases.subscriptionsv2.get
    const res = await androidpublisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
      subscriptionId,
    });

    const sub = res && res.data ? res.data : {};
    const line = sub.lineItems && sub.lineItems.length ? sub.lineItems[0] : undefined;

    const isoToDate = (iso) => (iso ? new Date(iso) : null);
    const periodeDebut = isoToDate(line && line.startTime);
    const periodeFin = isoToDate(line && line.expiryTime);
    const prochaineFacturation = periodeFin;
    const etat = sub.subscriptionState || null; // ACTIVE, CANCELED, PAUSED, ON_HOLD, EXPIRED
    const autoRenew = !!sub.autoRenewing;
    const pricePhase = line && line.pricingPhases && line.pricingPhases.pricingPhases && line.pricingPhases.pricingPhases[0];
    const amountMicros = pricePhase && pricePhase.priceAmountMicros;
    const currency = pricePhase && pricePhase.priceCurrencyCode;

    // Essai gratuit (phase à 0) si détectée → calcul simple basé sur startTime
    let joursEssaiRestants = 0;
    try {
      const freePhase = line && line.pricingPhases && line.pricingPhases.pricingPhases
        ? line.pricingPhases.pricingPhases.find((p) => String(p.priceAmountMicros || '') === '0')
        : null;
      if (freePhase && periodeDebut) {
        // Heuristique: si durée non parsée, fallback 7 jours
        const trialDays = 7;
        const diff = Math.max(0, trialDays - Math.floor((Date.now() - periodeDebut.getTime()) / 86400000));
        joursEssaiRestants = diff;
      }
    } catch (_) {}

    const docRef = admin.firestore().doc(`utilisateurs/${uid}`);
    await docRef.set({
      abonnement: {
        etat,
        periodeCourante: {
          debut: periodeDebut || null,
          fin: periodeFin || null,
        },
        prochaineFacturation: prochaineFacturation || null,
        offre: {
          productId: subscriptionId || null,
          basePlanId: (line && line.offerDetails && line.offerDetails.basePlanId) || null,
          offerId: (line && line.offerDetails && line.offerDetails.offerId) || null,
        },
        prix: amountMicros && currency ? { montant: Number(amountMicros) / 1e6, devise: currency } : null,
        renouvellement: { auto: autoRenew },
        joursEssaiRestants,
        lastSync: new Date(),
      },
    }, { merge: true });

    return { ok: true };
  } catch (e) {
    console.error('verifierAbonnement error', e);
    throw new functions.https.HttpsError('internal', String(e && e.message ? e.message : e));
  }
});


