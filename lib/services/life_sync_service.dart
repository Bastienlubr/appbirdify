import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'package:flutter/foundation.dart';

/// Service centralisé pour la synchronisation du système de vies
/// 
/// Ce service gère toute la logique de synchronisation entre Firestore et l'application
/// à tous les moments clés : entrée sur l'écran d'accueil, avant un quiz, après un quiz
class LifeSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirestoreService _firestoreService = FirestoreService();

  /// Synchronise les vies lors de l'entrée sur l'écran d'accueil
  /// 
  /// Cette méthode :
  /// - Vérifie que le document utilisateur existe (via FirestoreService)
  /// - Appelle resetLivesIfNeeded(uid) pour remettre les vies à 5 si la date est dépassée
  /// - Recharge les données de Firestore
  /// 
  /// [uid] : L'identifiant unique de l'utilisateur
  static Future<void> syncLivesOnHomeEntry(String uid) async {
    try {
      if (kDebugMode) debugPrint('🔄 Début de la synchronisation des vies - Entrée sur l\'écran d\'accueil');
      
      // Vérifier que le document utilisateur existe
      final documentCreated = await _firestoreService.createUserDocumentIfNeeded(uid);
      if (documentCreated) {
        if (kDebugMode) debugPrint('✅ Document utilisateur créé lors de la synchronisation');
      }
      
      // Appeler resetLivesIfNeeded pour remettre les vies à 5 si la date est dépassée
      await _firestoreService.resetLivesIfNeeded(uid);
      
      // Recharger les données de Firestore pour s'assurer de la synchronisation
      final currentLives = await _firestoreService.getLivesRemaining(uid);
      if (kDebugMode) debugPrint('✅ Synchronisation terminée - Vies actuelles: $currentLives');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation des vies à l\'entrée: $e');
      rethrow;
    }
  }

  /// Synchronise les vies avant de lancer un quiz
  /// 
  /// Cette méthode :
  /// - Recharge les données Firestore
  /// - Vérifie si livesRemaining > 0
  /// - Retourne true si le quiz peut être lancé, false sinon
  /// 
  /// [uid] : L'identifiant unique de l'utilisateur
  /// 
  /// Retourne true si le quiz peut être lancé, false sinon
  static Future<bool> syncLivesBeforeQuiz(String uid) async {
    try {
      if (kDebugMode) debugPrint('🔄 Vérification des vies avant le lancement du quiz');
      
      // Recharger les données Firestore
      final livesRemaining = await _firestoreService.getLivesRemaining(uid);
      if (kDebugMode) debugPrint('📊 Vies restantes: $livesRemaining');
      
      // Vérifier si livesRemaining > 0
      final canStartQuiz = livesRemaining > 0;
      
      if (canStartQuiz) {
        if (kDebugMode) debugPrint('✅ Quiz autorisé - Vies suffisantes');
      } else {
        if (kDebugMode) debugPrint('❌ Quiz refusé - Plus de vies disponibles');
      }
      
      return canStartQuiz;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la vérification des vies avant le quiz: $e');
      // En cas d'erreur, permettre l'accès au quiz pour éviter de bloquer l'utilisateur
      if (kDebugMode) debugPrint('⚠️ Accès au quiz autorisé par défaut en cas d\'erreur');
      return true;
    }
  }

  /// Synchronise les vies après la fin d'un quiz
  /// 
  /// Cette méthode :
  /// - Si livesLost > 0, appelle consumeLives(uid, livesLost) depuis FirestoreService
  /// - Met à jour Firestore proprement même si le quiz a été quitté en cours
  /// 
  /// [uid] : L'identifiant unique de l'utilisateur
  /// [livesLost] : Le nombre de vies perdues pendant le quiz
  static Future<void> syncLivesAfterQuiz(String uid, int livesLost) async {
    try {
      if (kDebugMode) debugPrint('🔄 Synchronisation des vies après le quiz');
      
      if (livesLost > 0) {
        // Appeler consumeLives pour décrémenter les vies perdues
        final consumedLives = await _firestoreService.consumeLives(uid, livesLost);
        if (kDebugMode) debugPrint('📉 Vies consommées: $consumedLives sur $livesLost perdues');
        
        // Récupérer les vies restantes après consommation
        final remainingLives = await _firestoreService.getLivesRemaining(uid);
        if (kDebugMode) debugPrint('📊 Vies restantes après le quiz: $remainingLives');
      } else {
        if (kDebugMode) debugPrint('✅ Aucune vie perdue - Synchronisation terminée');
      }
      
      if (kDebugMode) debugPrint('✅ Synchronisation post-quiz terminée');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation post-quiz: $e');
      rethrow;
    }
  }

  /// Méthode utilitaire pour obtenir les vies actuelles depuis Firestore
  /// 
  /// [uid] : L'identifiant unique de l'utilisateur
  /// 
  /// Retourne le nombre de vies restantes
  static Future<int> getCurrentLives(String uid) async {
    try {
      final lives = await _firestoreService.getLivesRemaining(uid);
      if (kDebugMode) debugPrint('📊 Vies actuelles récupérées: $lives');
      return lives;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la récupération des vies actuelles: $e');
      return 5; // Valeur par défaut en cas d'erreur
    }
  }

  /// Méthode utilitaire pour forcer la réinitialisation des vies (debug)
  /// 
  /// [uid] : L'identifiant unique de l'utilisateur
  /// [lives] : Le nombre de vies à définir (par défaut 5)
  static Future<void> forceResetLives(String uid, {int lives = 5}) async {
    try {
      if (kDebugMode) debugPrint('🔄 Réinitialisation forcée des vies à $lives');
      
      // Calculer aujourd'hui à minuit
      DateTime today = DateTime.now();
      DateTime todayMidnight = DateTime(today.year, today.month, today.day);
      
      // Mettre à jour le document Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
        'livesRemaining': lives,
        'dailyResetDate': todayMidnight,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) debugPrint('✅ Vies réinitialisées à $lives');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la réinitialisation forcée des vies: $e');
      rethrow;
    }
  }

  /// Méthode utilitaire pour vérifier l'état de synchronisation
  /// 
  /// [uid] : L'identifiant unique de l'utilisateur
  /// 
  /// Retourne un Map avec les informations de synchronisation
  static Future<Map<String, dynamic>> getSyncStatus(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) {
        return {
          'exists': false,
          'livesRemaining': 5,
          'lastUpdated': null,
          'dailyResetDate': null,
        };
      }
      
      final data = doc.data();
      return {
        'exists': true,
        'livesRemaining': data?['livesRemaining'] ?? 5,
        'lastUpdated': data?['lastUpdated'],
        'dailyResetDate': data?['dailyResetDate'],
      };
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la récupération du statut de synchronisation: $e');
      return {
        'exists': false,
        'livesRemaining': 5,
        'lastUpdated': null,
        'dailyResetDate': null,
        'error': e.toString(),
      };
    }
  }
} 