import 'package:flutter/material.dart';
import 'recompenses_utiles_page.dart';

/// Fonction utilitaire pour tester la page de récompenses
/// À utiliser temporairement pour tester le design
class TestRecompensesAccess {
  
  /// Afficher la page de récompenses depuis n'importe où
  static void showRecompensesPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecompensesUtilesPage(),
      ),
    );
  }
  
  /// Créer un bouton de test rapide
  static Widget buildTestButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => showRecompensesPage(context),
      backgroundColor: const Color(0xFF6A994E),
      child: const Icon(
        Icons.star,
        color: Colors.white,
      ),
    );
  }
  
  /// Créer un bouton de test simple
  static Widget buildSimpleTestButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => showRecompensesPage(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6A994E),
      ),
      child: const Text(
        'Tester Récompenses',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
