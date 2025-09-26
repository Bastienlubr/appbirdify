## Fonctionnement de l’abonnement Premium (Birdify)

Ce document explique de manière concise et exploitable comment fonctionne l’abonnement Premium dans l’app: flux, données Firestore, Cloud Function de vérification, et mapping UI ↔ produit. Il sert de référence pour le développement et pour outiller l’IA (OpenAI) avec un contexte précis.

### TL;DR – Cycle de vie d’un achat (aligné Play Billing)
1) Montrer les offres: `ChoixOffrePage` (1/6/12 mois) via SKUs configurés.
2) Lancer l’achat: `PremiumService.buyXxx()` ouvre Google Play.
3) Vérifier côté serveur: `_onPurchaseUpdate` → `_verifyAndAcknowledge()` appelle la CF `verifierAbonnementV2` avec `{ packageName, subscriptionId, purchaseToken }`.
4) Accorder l’accès: la CF met à jour Firestore (`profil.estPremium = true`, `vie.livesInfinite = true`, doc `abonnement/current` à jour). Fallback client en sandbox si CF indisponible.
5) Accuser réception: `completePurchase(p)` (acknowledge). Pas de consommation (abonnements).

### Vue d’ensemble
- Achats gérés via `in_app_purchase` (Android Google Play).
- Vérification côté backend via Cloud Functions (fallback client pour tests).
- État Premium piloté par Firestore, consommé par l’UI (gating, vies infinies, écrans de bienvenue/gestion).

### Code source principal
- Service d’achats: `lib/services/premium_service.dart`
- Page de choix d’offre: `lib/pages/Abonnement/choix_offre_page.dart`
- Page de bienvenue: `lib/pages/Abonnement/bienvenue_abonnement_page.dart`
- Page gérer abonnement: `lib/pages/Abonnement/gerer_mon_abonnement_page.dart`

### Produits (SKUs)
- Mensuel: un des IDs dans `PremiumService.monthlySkus`
- Semestriel: `PremiumService.semiAnnualSkus`
- Annuel: `PremiumService.annualSkus`

Les listes contiennent plusieurs variantes publiées (redondance). Le service choisit une variante non possédée lorsqu’il en propose plusieurs.

### Flux IAP
1) Démarrage (`PremiumService.start`)
- Vérifie la disponibilité Billing, écoute `purchaseStream`, interroge les produits, effectue une restauration initiale (idempotent).

2) Achat (`buy`, `buyMonthly`, `buySemiAnnual`, `buyAnnual`)
- Lance `buyNonConsumable` avec le `ProductDetails` sélectionné.
- Déclenche une restauration différée (8s) si nécessaire pour assurer la réception des achats.

3) Réception (`_onPurchaseUpdate`)
- Pour chaque `PurchaseDetails`:
  - Marque l’ID produit comme possédé (évite de reproposer la même variante).
  - Appelle `_verifyAndAcknowledge`.

4) Vérification serveur (V3) & Accusé
- Back‑end: `verifierAbonnementV3` avec `{ packageName, subscriptionId, purchaseToken }`.
- Le serveur consulte l’API Play (subscriptions v2), ACK si nécessaire, puis écrit Firestore (profil + `abonnement/current` + `encart`).
- Côté client: aucune écriture Firestore ni acknowledge Android en flux sécurisé.

5) Restauration (`restore`)
- Relance `restorePurchases` si besoin pour resynchroniser un abonnement déjà actif.

### États d’abonnement: mapping Google Play → Firestore → UX
- Actif (ACTIVE)
  - Firestore: `current.etat = 'ACTIVE'`, `offre.productId`, `renouvellement.auto = true/false`, dates de période renseignées.
  - Profil: `profil.estPremium = true`, `vie.livesInfinite = true`.
  - UX: accès Premium, `ChoixOffrePage` redirige vers `'/abonnement/bienvenue'`.

- Annulé (CANCELED)
  - Firestore: `current.etat = 'CANCELED'`, `periodeCourante.fin` fixé par CF à la date d’expiration.
  - Profil: reste Premium jusqu’à `fin` (CF peut maintenir `estPremium = true` jusqu’à expiration puis remettre à `false`).
  - UX: accès maintenu jusqu’à `fin`, puis retour offres.

- Délai de grâce (GRACE) / Retente paiement (PAYMENT_RETRY)
  - Firestore: `current.etat = 'GRACE' | 'PAYMENT_RETRY'`, `prochaineFacturation` mis à jour.
  - Profil: `estPremium = true` tant que Play maintient l’accès.
  - UX: accès OK; panneau gestion peut afficher un bandeau d’avertissement.

- En attente (PENDING)
  - Firestore: `current.etat = 'PENDING'`.
  - Profil: `estPremium = false` (pas d’accès tant que l’achat n’est pas confirmé).
  - UX: reste sur offres, proposer "Restaurer mes achats".

- Suspendu (SUSPENDED)
  - Firestore: `current.etat = 'SUSPENDED'`.
  - Profil: `estPremium = false`.
  - UX: bloqué; CTA vers gestion Google Play.

- Expiré (EXPIRED)
  - Firestore: `current.etat = 'EXPIRED'`, `periodeCourante.fin` renseigné.
  - Profil: `estPremium = false`, `vie.livesInfinite = false`.
  - UX: retour aux offres, masquer avantages Premium.

### Firestore: structure et drapeaux
- Profil utilisateur: `utilisateurs/{uid}`
  - `profil.estPremium: bool` → gating global (Premium ON/OFF)
  - `vie.livesInfinite: bool` → vies infinies si Premium

- Abonnement courant: `utilisateurs/{uid}/abonnement/current`
  - `etat: 'ACTIVE' | ...`
  - `offre.productId: string` (ID produit acheté)
  - `subscriptionId: string?` (fallback)
  - `renouvellement.auto: bool`
  - `periodeCourante.debut/fin: Timestamp?`
  - `prochaineFacturation: Timestamp?`
  - `joursEssaiRestants: number`
  - `lastToken, lastSync, packageName`

- Encart d’info: `utilisateurs/{uid}/abonnement/encart`
  - `plan`, `prixAffiche`, `essai.debut/fin`, `debutFacturation`, `prochaineFacturation`, `renouvellementAutomatique`

Ces champs sont mis à jour par la CF `verifierAbonnementV2` (ou via le fallback client en sandbox).

### Initialisation Billing / Reconnexion
- À l’entrée dans le flux Premium (ou au démarrage si souhaité), `PremiumService.start()`:
  - vérifie `isAvailable`, installe `purchaseStream`, interroge `queryProductDetails`, lance une restauration unique.
- En flux sécurisé: restoration à chaque `start()` pour capter PENDING→PURCHASED hors app. `triggerForegroundSync()` relance une restauration au retour foreground.
- La lib `in_app_purchase` gère la reconnexion au service Billing.

### Mapping UI ↔ produit/état
- Choix des offres (`ChoixOffrePage`)
  - Sélection locale: `OffreType { mois1, mois6, mois12 }`.
  - Achat: appelle `PremiumService.instance.buyXxx()` selon la sélection.
  - Écoute `.../abonnement/current`:
    - Si `etat == 'ACTIVE'` → navigation `'/abonnement/bienvenue'`.
    - Si `offre.productId` est présent → fige la sélection visuelle en fonction du SKU.

- Bienvenue (`bienvenue_abonnement_page.dart`)
  - Écran de confirmation après activation de l’abonnement.

- Gérer (`gerer_mon_abonnement_page.dart`)
  - “Gérer sur Google Play”: ouvre la gestion d’abonnement du compte.
  - “Restaurer mes achats”: relance `restore()`.

### Gating Premium
- L’UI s’appuie sur:
  - `profil.estPremium == true` pour déverrouiller les fonctionnalités Premium.
  - `vie.livesInfinite == true` pour masquer les limitations de vies.
  - Les écrans d’offres détectent `current.etat == 'ACTIVE'` pour basculer automatiquement vers la page de bienvenue.

### Points d’intégration clés (référence code)
- Service: `lib/services/premium_service.dart` (flux complet IAP, CF, Firestore)
- UI offres: `lib/pages/Abonnement/choix_offre_page.dart`
- UI bienvenue: `lib/pages/Abonnement/bienvenue_abonnement_page.dart`
- UI gestion: `lib/pages/Abonnement/gerer_mon_abonnement_page.dart`

### Dépannage rapide
- Produits non visibles → vérifier publication/activation des abonnements/offres et compte test sur l’appareil.
- Achat ne s’ouvre pas → vérifier Play Billing disponible et `packageName`.
- Pas de synchro Premium → vérifier la CF `verifierAbonnementV2` (logs Firebase) ou la restauration.

---

# Guide Play Console (Android)

## Pré‑requis
- Compte Google Play Console (droits de publication)
- Profil marchand activé
- Identifiant app: `com.mindbird.app`

## Créer les abonnements
1. Play Console > Monétiser > Produits > Abonnements
2. Créer/activer les variantes (mensuel, 6 mois, annuel) et leurs offres (essai/remise)
3. Publier chaque abonnement/offre

## Comptes de test
- Paramètres > Licence de test: ajouter les Gmail
- Sur l’appareil: utiliser ce compte dans Play Store

## Signature Android (release)
- Keystore + `android/key.properties` (voir modèle ci‑dessous)
```
keytool -genkeypair -v -keystore android/app/keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
```
storeFile=android/app/keystore.jks
storePassword=***
keyAlias=upload
keyPassword=***
```

## Publier un AAB
```
flutter build appbundle --release
```
Uploader `build/app/outputs/bundle/release/app-release.aab` (tests internes recommandé).

## Déclarations Play Console
- Sécurité des données (Firebase Auth/Firestore/Storage)
- Public cible
- Advertising ID: Non (si pas d’Ads SDK)
- Permissions: uniquement nécessaires

## Tester les achats
1. Installer la build de test (tests internes)
2. Lancer un achat depuis l’app
3. Après succès: Firestore doit montrer `profil.estPremium = true` et `vie.livesInfinite = true`
4. “Gérer mon abonnement” > “Restaurer mes achats” = restauration

## Dépannage
- Produits invisibles: vérifier publication/offres et compte test
- Restauration KO: relancer l’app et `restore()`
- AAB rejeté: incrémenter `version` (`pubspec.yaml`) puis rebuild

## Checklist
- [ ] Abonnements/offres publiés
- [ ] Comptes test ajoutés
- [ ] Keystore configuré
- [ ] `version` incrémentée
- [ ] AAB généré et uploadé (tests internes)
- [ ] Achat sandbox OK → Firestore à jour
- [ ] Restauration OK
