import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../pages/auth/login_screen.dart';
import '../../pages/auth/register_screen.dart';
import '../../pages/auth/questionnaire_screen.dart';
import '../../pages/Abonnement/information_abonnement_page.dart';
import '../../pages/Abonnement/choix_offre_page.dart';
import '../../pages/Profil/profil_page.dart';
import '../../pages/home_screen.dart';

class DevQuickNavPage extends StatelessWidget {
  const DevQuickNavPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(child: Text('DevQuickNav indisponible en release')),
      );
    }

    final entries = <_NavEntry>[
      _NavEntry('Login', () => const LoginScreen()),
      _NavEntry('Register', () => const RegisterScreen()),
      _NavEntry('Questionnaire', () => const QuestionnaireScreen()),
      _NavEntry('Abonnement - Infos', () => const InformationAbonnementPage()),
      _NavEntry('Abonnement - Choix offre', () => const ChoixOffrePage()),
      _NavEntry('Profil', () => const ProfilPage()),
      _NavEntry('Home', () => const HomeScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Navigation rapide (DEV)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final e in entries)
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => e.builder())),
                child: Text(e.label),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  final String label;
  final Widget Function() builder;
  _NavEntry(this.label, this.builder);
}


