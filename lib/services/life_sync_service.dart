import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LifeSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Synchronise les vies restantes avec Firestore après un quiz
  /// 
  /// [uid] : ID de l'utilisateur
  /// [livesRemaining] : Nombre de vies restantes (sera clampé entre 0 et 5)
  static Future<void> syncLivesAfterQuiz(String uid, int livesRemaining) async {
    try {
      // Clamper la valeur entre 0 et 5
      final clampedLives = livesRemaining.clamp(0, 5);
      
      if (kDebugMode) {
        debugPrint('🔄 Synchronisation des vies restantes: $clampedLives pour l\'utilisateur $uid');
      }

      // Écrire directement la valeur des vies restantes dans Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'livesRemaining': clampedLives,
        'lastLifeUsedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Vies restantes synchronisées avec Firestore: $clampedLives vies pour l\'utilisateur $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la synchronisation des vies restantes: $e');
      }
      rethrow;
    }
  }

  /// Obtient le nombre de vies perdues depuis Firestore
  static Future<int> getLivesLost(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        return data?['livesLost'] ?? 0;
      }
      
      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des vies perdues: $e');
      }
      return 0;
    }
  }

  /// Obtient le nombre de vies actuelles de l'utilisateur
  /// Retourne le nombre de vies restantes depuis Firestore
  static Future<int> getCurrentLives(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final livesRemaining = data?['livesRemaining'] ?? 5;
        
        // S'assurer que le nombre de vies est valide
        return (livesRemaining as int).clamp(0, 5);
      }
      
      // Si le document n'existe pas, retourner 5 vies par défaut
      return 5;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des vies actuelles: $e');
      }
      // Fallback à 5 vies en cas d'erreur
      return 5;
    }
  }

  /// Obtient l'ID de l'utilisateur actuel
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Vérifie si un utilisateur est connecté
  static bool get isUserLoggedIn {
    return _auth.currentUser != null;
  }

  /// Vérifie et réinitialise les vies à 5 si un nouveau jour est commencé
  /// 
  /// [uid] : ID de l'utilisateur
  /// Retourne le nombre de vies actuelles (après réinitialisation si nécessaire)
  static Future<int> checkAndResetLives(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Vérification de la réinitialisation quotidienne pour l\'utilisateur $uid');
      }

      // Lire les données actuelles de l'utilisateur
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        // Si le document n'existe pas, créer avec 5 vies
        await _firestore.collection('users').doc(uid).set({
          'livesRemaining': 5,
          'dailyResetDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (kDebugMode) {
          debugPrint('✅ Document utilisateur créé avec 5 vies pour l\'utilisateur $uid');
        }
        return 5;
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      final currentLives = (data?['livesRemaining'] ?? 5) as int;
      
      // Récupérer la date de dernière réinitialisation
      final dailyResetDate = data?['dailyResetDate'] as Timestamp?;
      final lastResetDate = dailyResetDate?.toDate().toLocal() ?? DateTime.now().toLocal();
      
      // Date d'aujourd'hui à minuit
      final todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      
      // Vérifier si on est passé à un nouveau jour
      if (lastResetDate.isBefore(todayMidnight)) {
        if (kDebugMode) {
          debugPrint('🔄 Nouveau jour détecté, réinitialisation des vies à 5 pour l\'utilisateur $uid');
        }
        
        // Réinitialiser les vies à 5 et mettre à jour la date
        await _firestore.collection('users').doc(uid).set({
          'livesRemaining': 5,
          'dailyResetDate': todayMidnight,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (kDebugMode) {
          debugPrint('✅ Vies réinitialisées à 5 pour l\'utilisateur $uid');
        }
        return 5;
      } else {
        if (kDebugMode) {
          debugPrint('✅ Pas de réinitialisation nécessaire, vies actuelles: $currentLives pour l\'utilisateur $uid');
        }
        return currentLives.clamp(0, 5);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la vérification/réinitialisation des vies: $e');
      }
      // En cas d'erreur, retourner 5 vies par défaut
      return 5;
    }
  }
} 