import 'package:flutter/material.dart';

class ConditionsGeneralesPage extends StatelessWidget {
  const ConditionsGeneralesPage({super.key});

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
          'Conditions générales d’utilisation',
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
              "Bienvenue sur l’application MindBird.\nLes présentes Conditions Générales d’Utilisation (ci-après “CGU”) encadrent l’accès et l’utilisation de l’application. En utilisant MindBird, vous acceptez pleinement ces CGU.",
              style: _p,
            ),
            const SizedBox(height: 12),
            Text('📩 Pour toute question, vous pouvez nous contacter à l’adresse : admin@mindbird.fr', style: _p),
            const SizedBox(height: 20),

            Text('1. Objet de l’application', style: _h1),
            const SizedBox(height: 8),
            Text(
              "MindBird est une application mobile éducative qui permet d’apprendre à reconnaître les chants d’oiseaux à travers des quiz, missions et fonctionnalités de progression.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('2. Accès et inscription', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’accès à certaines fonctionnalités nécessite la création d’un compte utilisateur.\n\n"
              "L’inscription peut se faire par e-mail, numéro de téléphone ou via Google Login.\n\n"
              "L’utilisateur s’engage à fournir des informations exactes et à maintenir la confidentialité de son mot de passe.\n\n"
              "L’application est destinée à un public de plus de 13 ans.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('3. Utilisation de l’application', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’utilisateur s’engage à utiliser MindBird uniquement à des fins personnelles et non commerciales.\n\n"
              "Toute tentative de fraude, piratage, modification du code ou usage abusif est interdite.\n\n"
              "L’utilisateur est responsable de son usage de l’application et de son compte.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('4. Services gratuits et premium', style: _h1),
            const SizedBox(height: 8),
            Text(
              "MindBird propose un accès gratuit avec certaines limitations (quiz, vies quotidiennes, publicités).\n\n"
              "Un abonnement premium est proposé via Google Play Billing, permettant de débloquer des fonctionnalités supplémentaires (accès illimité, entraînement personnalisé, suppression des limites).\n\n"
              "Les prix, durées et modalités de renouvellement sont indiqués clairement dans l’application et sur le Play Store.\n\n"
              "Les abonnements sont gérés directement par Google Play : l’annulation ou la modification doit se faire via les paramètres de compte Google de l’utilisateur.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('5. Propriété intellectuelle', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’ensemble des contenus présents dans l’application (sons, textes, visuels, codes) sont protégés par le droit d’auteur.\n\n"
              "Toute reproduction, distribution ou exploitation sans autorisation est interdite.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('6. Responsabilité', style: _h1),
            const SizedBox(height: 8),
            Text(
              "MindBird met tout en œuvre pour assurer un service de qualité, mais ne garantit pas que l’application sera exempte de bugs ou d’interruptions.\n\n"
              "L’éditeur ne pourra être tenu responsable des dommages directs ou indirects liés à l’utilisation de l’application.\n\n"
              "L’utilisateur est seul responsable de la bonne utilisation de son compte.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('7. Données personnelles', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’utilisation de l’application implique le traitement de certaines données personnelles (comptes, progression, abonnements).\n"
              "Ce traitement est décrit en détail dans la Politique de confidentialité accessible depuis l’application et sur le Play Store.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('8. Résiliation et suppression de compte', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’utilisateur peut supprimer son compte et ses données à tout moment via l’application ou en écrivant à admin@mindbird.fr.\n\n"
              "En cas de non-respect des CGU, l’éditeur se réserve le droit de suspendre ou supprimer un compte sans préavis.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('9. Modifications des CGU', style: _h1),
            const SizedBox(height: 8),
            Text(
              "L’éditeur peut mettre à jour les présentes CGU pour s’adapter à des évolutions légales ou techniques. Les utilisateurs seront informés en cas de modification majeure.",
              style: _p,
            ),
            const SizedBox(height: 16),

            Text('10. Droit applicable', style: _h1),
            const SizedBox(height: 8),
            Text(
              "Les présentes CGU sont régies par le droit français. En cas de litige, les tribunaux compétents seront ceux du ressort de la juridiction française.",
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



