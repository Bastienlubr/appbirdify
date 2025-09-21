const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

setGlobalOptions({ region: 'europe-west1', serviceAccount: '788742862967-compute@developer.gserviceaccount.com' });
try { admin.initializeApp(); } catch (_) {}

exports.verifierAbonnementV2 = onCall(async (request) => {
  const data = request.data || {};
  const { packageName, subscriptionId, purchaseToken } = data;
  const uid = request.auth && request.auth.uid ? request.auth.uid : null;
  console.log('verifierAbonnementV2 call', {
    hasAuth: !!request.auth,
    callerUid: uid,
  });
  if (!uid) {
    throw new HttpsError('permission-denied', 'Authentification requise');
  }
  if (!purchaseToken || !subscriptionId) {
    throw new HttpsError('invalid-argument', 'purchaseToken et subscriptionId requis');
  }

  try {
    const db = admin.firestore();
    const userRef = db.doc(`utilisateurs/${uid}`);
    const currentRef = userRef.collection('abonnement').doc('current');

    // Appel Google Play Subscriptions v2 pour récupérer phases/prices
    const { google } = require('googleapis');
    const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    const client = await auth.getClient();
    const androidpublisher = google.androidpublisher({ version: 'v3', auth: client });
    const res = await androidpublisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
      subscriptionId,
    });
    const sub = res && res.data ? res.data : {};
    const line = sub.lineItems && sub.lineItems.length ? sub.lineItems[0] : undefined;

    const isoToDate = (iso) => (iso ? new Date(iso) : null);
    const addIsoPeriod = (start, period) => {
      // Gère PnD, PnW, PnM, PnY (ISO 8601) avec ajout calendaire pour Mois/Années
      if (!start || !period || typeof period !== 'string') return null;
      const m = period.match(/^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$/i);
      if (!m) return null;
      const years = parseInt(m[1] || '0', 10);
      const months = parseInt(m[2] || '0', 10);
      const weeks = parseInt(m[3] || '0', 10);
      const days = parseInt(m[4] || '0', 10);
      const d = new Date(start.getTime());
      if (years) d.setFullYear(d.getFullYear() + years);
      if (months) d.setMonth(d.getMonth() + months);
      const totalDays = days + (weeks * 7);
      if (totalDays) d.setDate(d.getDate() + totalDays);
      return d;
    };
    const periodeDebut = isoToDate(line && line.startTime);
    const periodeFin = isoToDate(line && line.expiryTime);
    const prochaineFacturation = periodeFin;
    const etat = sub.subscriptionState || null;
    const autoRenew = !!sub.autoRenewing;

    // Phases de prix pour séparer essai gratuit et période payante
    const phases = (line && line.pricingPhases && line.pricingPhases.pricingPhases) || [];
    const trialPhase = phases.find((p) => String(p.priceAmountMicros || '0') === '0');
    const paidPhase = phases.find((p) => Number(p.priceAmountMicros || 0) > 0);
    const trialStart = periodeDebut;
    const trialEnd = trialPhase && trialStart ? (trialPhase.billingPeriod ? addIsoPeriod(trialStart, trialPhase.billingPeriod) : null) : null;
    const paidStart = trialEnd || periodeDebut;
    const priceAmountMicros = paidPhase && paidPhase.priceAmountMicros;
    const priceCurrency = paidPhase && paidPhase.priceCurrencyCode;

    let joursEssaiRestants = 0;
    if (trialEnd && Date.now() < trialEnd.getTime()) {
      joursEssaiRestants = Math.max(0, Math.ceil((trialEnd.getTime() - Date.now()) / 86400000));
    }

    const payload = {
      etat: etat || null,
      periodeCourante: { debut: periodeDebut || null, fin: periodeFin || null },
      prochaineFacturation: prochaineFacturation || null,
      offre: {
        productId: subscriptionId || null,
        basePlanId: (line && line.offerDetails && line.offerDetails.basePlanId) || null,
        offerId: (line && line.offerDetails && line.offerDetails.offerId) || null,
      },
      prix: priceAmountMicros && priceCurrency ? { montant: Number(priceAmountMicros) / 1e6, devise: priceCurrency } : null,
      renouvellement: { auto: autoRenew },
      essai: trialPhase ? {
        actif: !!trialEnd && Date.now() < trialEnd.getTime(),
        debut: trialStart || null,
        fin: trialEnd || null,
        joursRestants: joursEssaiRestants,
        dureeDeclarative: trialPhase.billingPeriod || null,
      } : null,
      payant: {
        debut: paidStart || null,
        dureeDeclarative: paidPhase && paidPhase.billingPeriod ? paidPhase.billingPeriod : null,
      },
      facturation: {
        derniereSync: new Date(),
        packageName: packageName || null,
        subscriptionId: subscriptionId || null,
        token: purchaseToken || null,
      },
      lastSync: new Date(),
    };

    await currentRef.set(payload, { merge: true });
    await userRef.set({ profil: { estPremium: (etat === 'ACTIVE' || etat === 'ON_HOLD' || etat === 'PAUSED' || etat === null) }, vie: { livesInfinite: true } }, { merge: true });

    return { ok: true, enriched: true };
  } catch (e) {
    console.error('verifierAbonnement error', e);
    throw new HttpsError('internal', String(e && e.message ? e.message : e));
  }
});


// Fallback Gen1 pour déblocage immédiat (même logique minimale)
exports.verifierAbonnementLegacy = functions.region('europe-west1').https.onCall(async (data, context) => {
  const { packageName, subscriptionId, purchaseToken } = data || {};
  const uid = context && context.auth && context.auth.uid ? context.auth.uid : null;
  if (!uid) throw new HttpsError('permission-denied', 'Authentification requise');
  if (!purchaseToken || !subscriptionId) throw new HttpsError('invalid-argument', 'purchaseToken et subscriptionId requis');
  try {
    const db = admin.firestore();
    const userRef = db.doc(`utilisateurs/${uid}`);
    const currentRef = userRef.collection('abonnement').doc('current');
    const payload = {
      etat: 'ACTIVE',
      periodeCourante: { debut: new Date(), fin: null },
      prochaineFacturation: null,
      offre: { productId: subscriptionId || null, basePlanId: null, offerId: null },
      prix: null,
      renouvellement: { auto: true },
      joursEssaiRestants: 0,
      lastSync: new Date(),
      packageName: packageName || null,
      subscriptionId: subscriptionId || null,
      lastToken: purchaseToken || null,
    };
    await currentRef.set(payload, { merge: true });
    await userRef.set({ profil: { estPremium: true }, vie: { livesInfinite: true } }, { merge: true });
    return { ok: true, legacy: true };
  } catch (e) {
    console.error('verifierAbonnementLegacy error', e);
    throw new HttpsError('internal', String(e && e.message ? e.message : e));
  }
});

