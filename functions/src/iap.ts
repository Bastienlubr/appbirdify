import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { google } from 'googleapis';

admin.initializeApp();

const androidpublisher = google.androidpublisher('v3');

async function getSubState(packageName: string, token: string) {
  const auth = await google.auth.getClient({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
  google.options({ auth });
  const res = await androidpublisher.purchases.subscriptionsv2.get({ packageName, token } as any);
  return res.data;
}

export const verifierAbonnement = functions
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

    const uid = context.auth.uid!;
    const now = admin.firestore.Timestamp.now();
    const sub = await getSubState(packageName, purchaseToken);

    const line = (sub as any)?.lineItems?.[0];
    const basePlanId = line?.offerDetails?.basePlanId || null;
    const renewal = (sub as any)?.renewalTime ? Number((sub as any).renewalTime) : null;
    const startMs = line?.startTime || (sub as any)?.startTime || null;
    const endMs = line?.expiryTime || (sub as any)?.expiryTime || null;
    const autoRenew = (sub as any)?.autoRenewEnabled === true;

    const stateRaw = (sub as any)?.subscriptionState || '';
    // Déterminer etat (technique) + phase (FR) + accès autorisé
    let state: 'ACTIVE' | 'CANCELED' | 'EXPIRED' | 'PENDING' | 'SUSPENDED' = 'PENDING';
    let phase: 'actif' | 'annulé' | 'en_attente' | 'suspendu' | 'expiré' = 'en_attente';
    let access = true;

    const nowMs = Date.now();
    const endMsNum = endMs ? Number(endMs) : undefined;

    if (stateRaw.includes('ACTIVE')) {
      state = 'ACTIVE';
      phase = 'actif';
      access = true;
    } else if (stateRaw.includes('CANCELED')) {
      // Annulé mais accès jusqu'à fin de période
      if (endMsNum && endMsNum > nowMs) {
        state = 'CANCELED';
        phase = 'annulé';
        access = true;
      } else {
        state = 'EXPIRED';
        phase = 'expiré';
        access = false;
      }
    } else if (stateRaw.includes('EXPIRED')) {
      state = 'EXPIRED';
      phase = 'expiré';
      access = false;
    } else if (stateRaw.includes('PAUSED')) {
      state = 'SUSPENDED';
      phase = 'suspendu';
      access = false;
    } else if (stateRaw.includes('ON_HOLD') || stateRaw.includes('PENDING')) {
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

    const dureeDeclarative =
      typeof subscriptionId === 'string' && subscriptionId.includes('1mois') ? 'P1M' :
      typeof subscriptionId === 'string' && subscriptionId.includes('6mois') ? 'P6M' :
      typeof subscriptionId === 'string' && subscriptionId.includes('12mois') ? 'P1Y' : undefined;

    await currentRef.set({
      etat: state,
      phase,
      periodeCourante,
      prochaineFacturation: renewal ? admin.firestore.Timestamp.fromMillis(renewal) : null,
      offre: { productId: subscriptionId, basePlanId, variantId: (subscriptionId || '').endsWith('_2') ? '2' : '1' },
      renouvellement: { auto: autoRenew },
      prix: (priceMicros && currency) ? { montant: Number(priceMicros) / 1_000_000, devise: currency, dureeDeclarative } : admin.firestore.FieldValue.delete(),
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
        fin: admin.firestore.Timestamp.fromMillis(
          (periodeCourante.debut as admin.firestore.Timestamp).toMillis() + 3 * 24 * 60 * 60 * 1000
        ),
        actif: state === 'ACTIVE' ? false : true,
      },
    }, { merge: true });

    return { ok: true, state, basePlanId, autoRenew };
  });


