const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { google } = require('googleapis');

try { admin.initializeApp(); } catch (_) {}

exports.verifierAbonnement = functions.region('europe-west1').https.onCall(async (data, context) => {
  const { packageName, subscriptionId, purchaseToken } = data || {};
  let uid = context.auth && context.auth.uid ? context.auth.uid : null;
  console.log('verifierAbonnement call', {
    hasAuth: !!context.auth,
    callerUid: uid,
    hasApp: !!context.app,
    appId: context.app && context.app.appId ? context.app.appId : null,
  });
  // Fallback TEST UNIQUEMENT: accepter uid passé si pas d'auth client
  if (!uid && data && typeof data.uid === 'string' && data.uid.length > 0) {
    console.warn('⚠️ TEST BYPASS AUTH: utilisation du uid fourni dans data.uid');
    uid = data.uid;
  }
  if (!uid) {
    throw new functions.https.HttpsError('permission-denied', 'Authentification requise');
  }
  if (!purchaseToken || !subscriptionId) {
    throw new functions.https.HttpsError('invalid-argument', 'purchaseToken et subscriptionId requis');
  }

  try {
    const db = admin.firestore();

    // 0) Verrou de propriété: si ce purchaseToken a déjà été revendiqué par un autre uid, refuser
    // On stocke un mapping minimal token→owner pour éviter les migrations inter-comptes.
    const tokenKey = purchaseToken.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 150) || 'token';
    const tokenRef = db.collection('abonnements_tokens').doc(tokenKey);
    const claimedSnap = await tokenRef.get();
    if (claimedSnap.exists) {
      const owner = claimedSnap.get('ownerUid');
      if (owner && owner !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'Ce jeton d\'achat est déjà associé à un autre compte.');
      }
    }

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
    const etat = sub.subscriptionState || null; // ex: ACTIVE / ON_HOLD / PAUSED / CANCELED / EXPIRED
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

    const userRef = db.doc(`utilisateurs/${uid}`);
    const currentRef = userRef.collection('abonnement').doc('current');
    const historyCol = userRef.collection('abonnement').doc('historique').collection('cycles');

    const payload = {
      etat: etat || null,
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
      packageName: packageName || null,
      subscriptionId: subscriptionId || null,
      lastToken: purchaseToken || null,
    };

    // Écrire l'état courant
    await currentRef.set(payload, { merge: true });

    // Archiver le cycle courant dans l'historique si période disponible
    if (periodeDebut) {
      const key = periodeDebut.toISOString();
      await historyCol.doc(key).set({ ...payload, archivedAt: new Date() }, { merge: true });
    }

    // Mettre à jour des indicateurs racine (utilisés par l'UI)
    const etatStr = typeof etat === 'string' ? etat : String(etat || '');
    const now = Date.now();
    const activeByTime = (periodeFin && periodeFin.getTime && (periodeFin.getTime() > now));
    // Premium si état actif/hold/pause OU si la période payée n'est pas encore expirée
    const isPremium = /ACTIVE|ON_HOLD|PAUSED/i.test(etatStr) || (etatStr !== 'EXPIRED' && activeByTime);
    await userRef.set({
      profil: { estPremium: isPremium },
      vie: { livesInfinite: isPremium },
    }, { merge: true });

    // 3) Reconnaissance/acknowledge (au cas où le client ne l'aurait pas fait)
    try {
      await androidpublisher.purchases.subscriptions.acknowledge({
        packageName,
        subscriptionId,
        token: purchaseToken,
        requestBody: {},
      });
    } catch (ackErr) {
      console.warn('acknowledge error (ignoré):', ackErr && ackErr.message ? ackErr.message : ackErr);
    }

    // 4) Revendiquer le jeton pour cet uid (si pas déjà pris)
    await tokenRef.set({ ownerUid: uid, subscriptionId, lastSeen: new Date() }, { merge: true });

    return { ok: true };
  } catch (e) {
    console.error('verifierAbonnement error', e);
    throw new functions.https.HttpsError('internal', String(e && e.message ? e.message : e));
  }
});

// Fallback HTTP (tests): même logique sans App Check/Auth obligatoire
exports.verifierAbonnementHttp = functions.region('europe-west1').https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method-not-allowed' });
    return;
  }
  const { packageName, subscriptionId, purchaseToken, uid: rawUid } = req.body || {};
  if (!rawUid || !subscriptionId || !purchaseToken) {
    res.status(400).json({ ok: false, error: 'missing-arguments' });
    return;
  }
  try {
    const db = admin.firestore();

    const tokenKey = purchaseToken.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 150) || 'token';
    const tokenRef = db.collection('abonnements_tokens').doc(tokenKey);
    const claimedSnap = await tokenRef.get();
    if (claimedSnap.exists) {
      const owner = claimedSnap.get('ownerUid');
      if (owner && owner !== rawUid) {
        res.status(403).json({ ok: false, error: 'token-owned-by-other-uid' });
        return;
      }
    }

    const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    const client = await auth.getClient();
    const androidpublisher = google.androidpublisher({ version: 'v3', auth: client });

    const resPlay = await androidpublisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
      subscriptionId,
    });
    const sub = resPlay && resPlay.data ? resPlay.data : {};
    const line = sub.lineItems && sub.lineItems.length ? sub.lineItems[0] : undefined;

    const isoToDate = (iso) => (iso ? new Date(iso) : null);
    const periodeDebut = isoToDate(line && line.startTime);
    const periodeFin = isoToDate(line && line.expiryTime);
    const prochaineFacturation = periodeFin;
    const etat = sub.subscriptionState || null;
    const autoRenew = !!sub.autoRenewing;
    const pricePhase = line && line.pricingPhases && line.pricingPhases.pricingPhases && line.pricingPhases.pricingPhases[0];
    const amountMicros = pricePhase && pricePhase.priceAmountMicros;
    const currency = pricePhase && pricePhase.priceCurrencyCode;

    let joursEssaiRestants = 0;
    try {
      const freePhase = line && line.pricingPhases && line.pricingPhases.pricingPhases
        ? line.pricingPhases.pricingPhases.find((p) => String(p.priceAmountMicros || '') === '0')
        : null;
      if (freePhase && periodeDebut) {
        const trialDays = 7;
        const diff = Math.max(0, trialDays - Math.floor((Date.now() - periodeDebut.getTime()) / 86400000));
        joursEssaiRestants = diff;
      }
    } catch (_) {}

    const userRef = db.doc(`utilisateurs/${rawUid}`);
    const currentRef = userRef.collection('abonnement').doc('current');
    const historyCol = userRef.collection('abonnement').doc('historique').collection('cycles');

    const payload = {
      etat: etat || null,
      periodeCourante: { debut: periodeDebut || null, fin: periodeFin || null },
      prochaineFacturation: prochaineFacturation || null,
      offre: { productId: subscriptionId || null, basePlanId: (line && line.offerDetails && line.offerDetails.basePlanId) || null, offerId: (line && line.offerDetails && line.offerDetails.offerId) || null },
      prix: amountMicros && currency ? { montant: Number(amountMicros) / 1e6, devise: currency } : null,
      renouvellement: { auto: autoRenew },
      joursEssaiRestants,
      lastSync: new Date(),
      packageName: packageName || null,
      subscriptionId: subscriptionId || null,
      lastToken: purchaseToken || null,
    };

    await currentRef.set(payload, { merge: true });
    if (periodeDebut) {
      const key = periodeDebut.toISOString();
      await historyCol.doc(key).set({ ...payload, archivedAt: new Date() }, { merge: true });
    }

    const etatStr = typeof etat === 'string' ? etat : String(etat || '');
    const now = Date.now();
    const activeByTime = (periodeFin && periodeFin.getTime && (periodeFin.getTime() > now));
    const isPremium = /ACTIVE|ON_HOLD|PAUSED/i.test(etatStr) || (etatStr !== 'EXPIRED' && activeByTime);
    await userRef.set({ profil: { estPremium: isPremium }, vie: { livesInfinite: isPremium } }, { merge: true });

    try {
      await androidpublisher.purchases.subscriptions.acknowledge({ packageName, subscriptionId, token: purchaseToken, requestBody: {} });
    } catch (ackErr) {
      console.warn('acknowledge error (ignored):', ackErr && ackErr.message ? ackErr.message : ackErr);
    }

    await tokenRef.set({ ownerUid: rawUid, subscriptionId, lastSeen: new Date() }, { merge: true });
    res.status(200).json({ ok: true });
  } catch (e) {
    console.error('verifierAbonnementHttp error', e);
    res.status(500).json({ ok: false, error: String(e && e.message ? e.message : e) });
  }
});


