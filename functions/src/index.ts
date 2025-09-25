import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as logger from 'firebase-functions/logger';
import { google } from 'googleapis';
import * as uuid from 'uuid';
import { createHash } from 'crypto';

admin.initializeApp();
setGlobalOptions({ region: 'europe-west1' });

function hashToken(token: string): string {
  return 'sha256:' + createHash('sha256').update(token).digest('hex');
}
const db = admin.firestore();

type VerifyResponse = { success: boolean; state?: string; expiryTimeMillis?: number };

// Expect service account with Play Developer API access (Android Publisher v3)
async function getAndroidPublisherClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  // Passer l'instance GoogleAuth directement pour satisfaire les types
  const androidpublisher = google.androidpublisher({ version: 'v3', auth });
  return androidpublisher;
}

export const verifierAbonnementV3 = onCall(async (request): Promise<VerifyResponse> => {
  const data = request.data as any;
  const packageName: string = data?.packageName;
  const subscriptionId: string = data?.subscriptionId;
  const purchaseToken: string = data?.purchaseToken;
  const uid: string | undefined = (data?.uid as string | undefined) ?? request.auth?.uid ?? undefined;

  if (!packageName || !subscriptionId || !purchaseToken) {
    throw new HttpsError('invalid-argument', 'Missing required fields');
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
      } catch (e) {
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
      const normalizeState = (s?: string): string => {
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
      const estPremium = (
        etat === 'ACTIVE' || etat === 'GRACE' || etat === 'PAYMENT_RETRY' ||
        (etat === 'CANCELED' && !!finMs && nowMs < finMs)
      );

      // current document (merge)
      const currentDoc: Record<string, any> = {
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
      const encartDoc: Record<string, any> = {
        produitId: subscriptionId,
        renouvellementAutomatique: autoRenewing,
        prochaineFacturation: finTs,
      };

      const profilUpdate = {
        estPremium,
        premiumActiveUntil: finTs ?? null,
        updatedAt: now,
      } as Record<string, any>;
      const vieUpdate = {
        livesInfinite: estPremium,
        updatedAt: now,
      } as Record<string, any>;

      const batch = db.batch();
      batch.set(currentRef, currentDoc, { merge: true });
      batch.set(encartRef, encartDoc, { merge: true });
      batch.set(userRef, { profil: profilUpdate }, { merge: true });
      batch.set(userRef, { vie: vieUpdate }, { merge: true });
      await batch.commit();
    }

    return { success: true, state: (subs.data.subscriptionState as string | undefined), expiryTimeMillis: expiryTimeMillis ? Number(expiryTimeMillis) : undefined };
  } catch (e) {
    logger.error('verifierAbonnementV3 error', { e });
    return { success: false };
  }
});

// Real‑time Developer Notifications (RTDN) handler for subscription lifecycle updates
// Configure your Play Console to publish RTDN to Pub/Sub topic 'play-rtdn'
// Then deploy this function to react to renewals/expirations without opening the app
export const androidRtdn = onMessagePublished('play-rtdn', async (event) => {
  try {
    const maybeJson = (event.data?.message?.json as any | undefined);
    const maybeBase64 = (event.data?.message?.data as string | undefined);
    const payload: any = maybeJson ?? (maybeBase64 ? JSON.parse(Buffer.from(maybeBase64, 'base64').toString('utf8')) : undefined);
    if (!payload) {
      logger.warn('RTDN payload missing');
      return;
    }
      const packageName: string | undefined = payload?.packageName;
      const subNotif = payload?.subscriptionNotification;
      const subscriptionId: string | undefined = subNotif?.subscriptionId;
      const purchaseToken: string | undefined = subNotif?.purchaseToken;
      const notificationType: number | undefined = subNotif?.notificationType;

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
      const userRef = currentDocHit.ref.parent.parent!; // utilisateurs/{uid}
      const uid = userRef.id;
      const currentRef = userRef.collection('abonnement').doc('current');
      const encartRef = userRef.collection('abonnement').doc('encart');

      const now = admin.firestore.Timestamp.now();
      const nowMs = Date.now();

      const normalizeState = (s?: string): string => {
        switch (s) {
          case 'IN_GRACE_PERIOD': return 'GRACE';
          case 'ON_HOLD': return 'PAYMENT_RETRY';
          case 'PAUSED': return 'SUSPENDED';
          case 'FREE_TRIAL': return 'ACTIVE';
          case 'ACTIVE': case 'PENDING': case 'CANCELED': case 'EXPIRED': return s;
          default: return 'UNKNOWN';
        }
      };

      const etat = normalizeState(status ?? undefined);
      const finTs = expiryTimeMillis ? admin.firestore.Timestamp.fromMillis(expiryTimeMillis) : null;
      const finMs = expiryTimeMillis ?? null;
      const estPremium = (etat === 'ACTIVE' || etat === 'GRACE' || etat === 'PAYMENT_RETRY' || (etat === 'CANCELED' && !!finMs && nowMs < finMs));

      const currentDoc: Record<string, any> = {
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
      const encartDoc: Record<string, any> = {
        produitId: subscriptionId,
        renouvellementAutomatique: autoRenewing,
        prochaineFacturation: finTs,
        majPar: 'RTDN',
      };
      const profilUpdate = { estPremium, premiumActiveUntil: finTs ?? null, updatedAt: now } as Record<string, any>;
      const vieUpdate = { livesInfinite: estPremium, updatedAt: now } as Record<string, any>;

      const batch = db.batch();
      batch.set(currentRef, currentDoc, { merge: true });
      batch.set(encartRef, encartDoc, { merge: true });
      batch.set(userRef, { profil: profilUpdate }, { merge: true });
      batch.set(userRef, { vie: vieUpdate }, { merge: true });

      const messageId = (event.data?.message?.messageId as string | undefined) ?? uuid.v4();
      const histRef = userRef.collection('abonnement_history').doc(messageId);
      batch.set(histRef, { type: etat, at: now, source: 'RTDN', payload: { notificationType: notificationType ?? null, purchaseTokenHash: hashToken(purchaseToken) } });
      await batch.commit();

      logger.info('RTDN processed', { uid, etat, notificationType, expiryTimeMillis, autoRenewing });
  } catch (e) {
    logger.error('RTDN handler error', { e });
  }
});


