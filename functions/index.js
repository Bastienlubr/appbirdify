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

    return { ok: true, mock: true };
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

