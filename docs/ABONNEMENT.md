# Abonnements Google Play (Birdify)

Ce guide explique comment configurer, tester et publier les abonnements sur Google Play pour l’app Android `com.mindbird.app`.

## 1) Pré-requis
- Compte Google Play Console avec droits de publication
- Profil de paiement marchand activé (pour vendre des abonnements)
- Identifiant d’application: `com.mindbird.app` (déjà configuré dans le projet)

## 2) Créer les abonnements dans Play Console
1. Ouvre Play Console > ton app > Monétiser > Produits > Abonnements
2. Crée:
   - `premium_monthly` (Premium mensuel)
   - `premium_yearly` (Premium annuel)
3. Pour chaque abonnement:
   - Crée une Offre (optionnel: essai gratuit, remise) puis active-la
   - Publie/Active l’abonnement (sinon il reste invisible même en test)

Note: Les prix affichés dans l’app sont dynamiques et proviennent de Google Play; toute modification côté Console se reflèlera automatiquement après propagation.

## 3) Comptes de test
- Play Console > Paramètres > Licence de test: ajoute les adresses Gmail des testeurs
- Sur l’appareil de test, utilise un de ces comptes dans le Play Store

## 4) Signature Android (release)
Le projet charge `android/key.properties` s’il existe et signe automatiquement en release.

- Générer un keystore (Windows, JDK requis):
```
keytool -genkeypair -v -keystore android/app/keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
- Créer `android/key.properties`:
```
storeFile=android/app/keystore.jks
storePassword=VOTRE_MOT_DE_PASSE
keyAlias=upload
keyPassword=VOTRE_MOT_DE_PASSE
```
- Incrémentez le build number dans `pubspec.yaml` avant chaque envoi (ex: `version: 1.0.0+2`)

## 5) Générer et publier un AAB
- Générer le bundle:
```
flutter build appbundle --release
```
- Fichier à uploader: `build/app/outputs/bundle/release/app-release.aab`
- Dans Play Console, crée une nouvelle release (Tests internes recommandé au début), téléverse le AAB, ajoute des testeurs, puis publie

## 6) Déclarations “Contenu de l’application” (Play Console)
- Sécurité des données: compléter le formulaire (Firebase Auth/Firestore/Storage si utilisés)
- Public cible et contenu: compléter
- Identifiant publicitaire (Android 13 / AD_ID): l’app n’utilise pas d’Ads SDK → déclarez “N’utilise pas l’Advertising ID” (ne pas ajouter de permission AD_ID)
- Permissions: vérifier et déclarer celles réellement utilisées (ex: Internet, stockage si besoin)

## 7) Tester les achats in-app (IAP)
1. Installez l’app de test (Tests internes ou `flutter install` sur un appareil connecté au compte de test)
2. App > Menu Premium > “Choisis un abonnement”
3. Lancez un achat (sandbox). Après succès:
   - Firestore: `profil.estPremium = true`
   - Flag de gating: `livesInfinite = true`
4. Page “Gérer mon abonnement”:
   - “Gérer sur Google Play” ouvre la gestion abonnements du compte
   - “Restaurer mes achats” relance la restauration

## 8) Notes & bonnes pratiques
- SKU 6 mois: actuellement mappé sur l’annuel. Pour un vrai 6 mois, créez un 3e SKU et on le branche.
- Les prix dans l’UI sont dynamiques (label Google Play, devise locale). Pour des promos/essais, utilisez les Offres dans Play Console.
- À chaque nouvel upload de release: incrémentez le `versionCode` (`pubspec.yaml` champ après le `+`).
- En cas de message “release verrouillée/brouillon”: supprimez le brouillon et créez une nouvelle release.

## 9) Dépannage rapide
- Produits non visibles: vérifier que les abonnements/Offres sont publiés/actifs et que l’appareil utilise un compte test
- Achat ne s’ouvre pas: vérifier la disponibilité Play Billing et le package name `com.mindbird.app`
- Restauration: utilisez “Restaurer mes achats” sur la page de gestion
- Échec d’upload AAB: incrémentez la version (`pubspec.yaml`), rebuild, réessayez

---
Dernière MAJ: automatique via intégration IAP (in_app_purchase). Si un flux change côté Google, mettre à jour ici.

## 10) Checklist restante (à cocher)
- [ ] Créer `premium_monthly` et `premium_yearly` et les publier (Play Console)
- [ ] Ajouter les comptes test (Licence de test)
- [ ] Générer keystore + `android/key.properties` (si pas déjà fait)
- [ ] Incrémenter `version` dans `pubspec.yaml`
- [ ] Générer AAB release: `flutter build appbundle --release`
- [ ] Créer release (Tests internes) et uploader le AAB
- [ ] Compléter “Contenu de l’application” (Sécurité des données, Public cible, Identifiant publicitaire = Non)
- [ ] Tester l’achat sandbox (mensuel/annuel)
- [ ] Vérifier Firestore: `profil.estPremium = true` et `livesInfinite = true`
- [ ] Restauration via “Gérer mon abonnement” > “Restaurer mes achats”
