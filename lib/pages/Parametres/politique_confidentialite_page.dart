import 'package:flutter/material.dart';

class PolitiqueConfidentialitePage extends StatelessWidget {
  const PolitiqueConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F5F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF334355)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Politique de confidentialité',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w900,
            color: Color(0xFF334355),
          ),
        ),
        centerTitle: true,
      ),
      body: const _Content(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  TextStyle get _h1 => const TextStyle(
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: Color(0xFF334355),
      );
  // ignore: unused_element
  TextStyle get _h2 => const TextStyle(
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: Color(0xFF334355),
      );
  TextStyle get _p => const TextStyle(
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 1.45,
        color: Color(0xFF334355),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dernière mise à jour : 28/09/2025', style: _p.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              "La présente politique de confidentialité décrit comment l’application MindBird, éditée en France, traite les données personnelles de ses utilisateurs.",
              style: _p,
            ),
            const SizedBox(height: 12),
            Text('📩 Pour toute question, vous pouvez nous contacter à l’adresse : admin@mindbird.fr', style: _p),
            const SizedBox(height: 20),

            Text('1. Données collectées', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Lors de l’utilisation de l’application MindBird, nous collectons les données suivantes :\n\n"
              "Données de compte : adresse e-mail, identifiant, mot de passe (si création de compte interne).\n\n"
              "Authentification via Google (si choisie par l’utilisateur).\n\n"
              "Numéro de téléphone (si inscription par téléphone).\n\n"
              "Données d’utilisation : progression, scores, missions et quiz réalisés.\n\n"
              "Informations techniques : données liées à l’appareil (identifiant Firebase), mais pas de localisation GPS précise. Une information générale (pays de connexion) peut être déduite du téléphone.\n\n"
              "Nous ne collectons pas l’âge, ni de données sensibles.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('2. Finalités de la collecte', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Les données collectées servent à :\n\n"
              "- Permettre la création et la gestion du compte utilisateur.\n"
              "- Sauvegarder et synchroniser la progression (scores, missions, quiz).\n"
              "- Améliorer l’expérience utilisateur grâce à Firebase Analytics.\n"
              "- Diffuser de la publicité via Google AdMob.\n"
              "- Gérer les abonnements et paiements via Google Play Billing.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('3. Services tiers utilisés', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’application utilise des services externes pouvant collecter certaines données :\n\n"
              "- Firebase Authentication, Firestore et Storage (Google LLC).\n"
              "- Firebase Analytics (Google LLC).\n"
              "- Google AdMob (publicité).\n"
              "- Google Play Billing (paiements).\n\n"
              "Ces services appliquent leur propre politique de confidentialité.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('4. Conservation des données', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Les données liées au compte sont conservées tant que l’utilisateur dispose d’un compte actif.\n\n"
              "En cas de suppression du compte, toutes les données personnelles associées (identifiants, scores, progression) sont supprimées dans un délai maximum de 30 jours.\n\n"
              "Les données anonymisées (statistiques générales) peuvent être conservées à des fins d’analyse.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('5. Droits des utilisateurs', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Conformément au RGPD, vous disposez des droits suivants :\n\n"
              "- Accès à vos données.\n"
              "- Rectification en cas d’erreur.\n"
              "- Suppression (droit à l’oubli).\n"
              "- Limitation ou opposition au traitement.\n\n"
              "Vous pouvez exercer ces droits directement via l’application (menu > supprimer mon compte) ou en nous écrivant à admin@mindbird.fr.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('6. Publicité et consentement', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’application affiche des annonces via Google AdMob.\n"
              "Lors du premier lancement, un message de consentement peut être proposé afin d’accepter ou refuser la personnalisation des publicités (conformément au RGPD).",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('7. Sécurité des données', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Nous mettons en place des mesures techniques et organisationnelles pour protéger vos données (cryptage, accès restreint, authentification sécurisée).",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('8. Modifications de la politique', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Nous pouvons mettre à jour la présente politique pour l’adapter aux évolutions légales ou techniques. Les utilisateurs seront informés en cas de changement majeur.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('📩 Contact : admin@mindbird.fr', style: _p),
          ],
        ),
      ),
    );
  }
}


