import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/Mission/communs/commun_generateur_quiz.dart';
import '../../services/Mission/communs/commun_gestionnaire_assets.dart';
import '../../models/bird.dart';

/// Service pour gérer les quiz personnalisés de l'utilisateur
class CustomQuizService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sauvegarde un quiz personnalisé dans Firestore
  static Future<bool> saveCustomQuiz({
    required String name,
    required String description,
    required List<String> selectedBirdNames,
    required int questionsCount,
    required List<QuizQuestion> questions,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('❌ Utilisateur non authentifié');
        return false;
      }

      final quizId = DateTime.now().millisecondsSinceEpoch.toString();
      final quizData = {
        'id': quizId,
        'name': name.trim(),
        'description': description.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'selectedBirds': selectedBirdNames,
        'questionsCount': questionsCount,
        // Ne pas sauvegarder les questions générées pour garder l'aléatoire
      };

      // Sauvegarder dans la sous-collection mesQuiz de l'utilisateur
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('mesQuiz')
          .doc(quizId)
          .set(quizData);

      if (kDebugMode) debugPrint('✅ Quiz personnalisé sauvegardé: $name');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur sauvegarde quiz: $e');
      return false;
    }
  }

  /// Récupère tous les quiz personnalisés de l'utilisateur
  static Stream<List<Map<String, dynamic>>> getUserCustomQuizzes() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('utilisateurs')
        .doc(user.uid)
        .collection('mesQuiz')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Supprime un quiz personnalisé
  static Future<bool> deleteCustomQuiz(String quizId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('mesQuiz')
          .doc(quizId)
          .delete();

      if (kDebugMode) debugPrint('✅ Quiz personnalisé supprimé: $quizId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur suppression quiz: $e');
      return false;
    }
  }

  /// Récupère un quiz personnalisé par ID et génère les questions aléatoirement
  static Future<List<QuizQuestion>?> loadCustomQuiz(String quizId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('mesQuiz')
          .doc(quizId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final selectedBirdNames = List<String>.from(data['selectedBirds'] ?? []);
      if (selectedBirdNames.isEmpty) return null;

      // Régénérer les questions aléatoirement à partir des espèces sauvegardées
      await MissionPreloader.loadBirdifyData();
      final selectedBirds = selectedBirdNames
          .map((name) => MissionPreloader.getBirdData(name) ?? MissionPreloader.findBirdByName(name))
          .where((bird) => bird != null)
          .cast<Bird>()
          .toList();

      if (selectedBirds.isEmpty) return null;

      // Récupérer le nombre de questions sauvegardé
      final savedQuestionsCount = data['questionsCount'] as int? ?? 10;
      
      // Générer de nouvelles questions (aléatoire à chaque fois)
      final questions = await QuizGenerator.generateQuizFromBirds(selectedBirds, maxQuestions: savedQuestionsCount);
      return questions;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur chargement quiz: $e');
      return null;
    }
  }
}
