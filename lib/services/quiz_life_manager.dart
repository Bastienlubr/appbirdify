import 'life_sync_service.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer la consommation des vies pendant un quiz
/// 
/// Ce service :
/// - Vérifie les vies avant de lancer un quiz
/// - Consomme les vies en cas d'erreur
/// - Synchronise les vies après le quiz
class QuizLifeManager {
  static int _livesLost = 0;
  static bool _quizStarted = false;

  /// Vérifie si l'utilisateur peut lancer un quiz
  /// 
  /// [uid] : ID de l'utilisateur
  /// 
  /// Retourne true si le quiz peut être lancé, false sinon
  static Future<bool> canStartQuiz(String uid) async {
    try {
      if (kDebugMode) debugPrint('🔄 Vérification des vies avant le lancement du quiz');
      
      final canStart = await LifeSyncService.syncLivesBeforeQuiz(uid);
      
      if (canStart) {
        _quizStarted = true;
        _livesLost = 0;
        if (kDebugMode) debugPrint('✅ Quiz autorisé - Démarrage');
      } else {
        if (kDebugMode) debugPrint('❌ Quiz refusé - Plus de vies disponibles');
      }
      
      return canStart;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la vérification des vies: $e');
      // En cas d'erreur, permettre l'accès au quiz pour éviter de bloquer l'utilisateur
      _quizStarted = true;
      _livesLost = 0;
      return true;
    }
  }

  /// Consomme une vie en cas d'erreur dans le quiz
  /// 
  /// Cette méthode :
  /// - Incrémente le compteur de vies perdues
  /// - Ne consomme pas immédiatement dans Firestore (attendre la fin du quiz)
  static void loseLife() {
    if (_quizStarted) {
      _livesLost++;
      if (kDebugMode) debugPrint('💔 Vie perdue - Total perdues: $_livesLost');
    }
  }

  /// Finalise le quiz et synchronise les vies
  /// 
  /// [uid] : ID de l'utilisateur
  /// 
  /// Cette méthode :
  /// - Synchronise les vies perdues dans Firestore
  /// - Remet à zéro les compteurs internes
  static Future<void> finishQuiz(String uid) async {
    try {
      if (_quizStarted) {
        if (kDebugMode) debugPrint('🔄 Finalisation du quiz - Vies perdues: $_livesLost');
        
        // Synchroniser les vies perdues
        await LifeSyncService.syncLivesAfterQuiz(uid, _livesLost);
        
        // Remettre à zéro les compteurs
        _livesLost = 0;
        _quizStarted = false;
        
        if (kDebugMode) debugPrint('✅ Quiz finalisé avec succès');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la finalisation du quiz: $e');
      // Remettre à zéro les compteurs même en cas d'erreur
      _livesLost = 0;
      _quizStarted = false;
    }
  }

  /// Annule le quiz sans consommer de vies
  /// 
  /// Cette méthode :
  /// - Remet à zéro les compteurs sans synchroniser
  /// - Utile quand l'utilisateur quitte le quiz volontairement
  static void cancelQuiz() {
    if (kDebugMode) debugPrint('🔄 Annulation du quiz - Aucune vie consommée');
    _livesLost = 0;
    _quizStarted = false;
  }

  /// Récupère le nombre de vies perdues pendant le quiz actuel
  /// 
  /// Retourne le nombre de vies perdues
  static int getLivesLost() {
    return _livesLost;
  }

  /// Vérifie si un quiz est en cours
  /// 
  /// Retourne true si un quiz est en cours, false sinon
  static bool isQuizActive() {
    return _quizStarted;
  }

  /// Force la réinitialisation des compteurs (debug)
  /// 
  /// Cette méthode est utile pour le débogage
  static void reset() {
    if (kDebugMode) debugPrint('🔄 Réinitialisation forcée des compteurs de quiz');
    _livesLost = 0;
    _quizStarted = false;
  }
} 