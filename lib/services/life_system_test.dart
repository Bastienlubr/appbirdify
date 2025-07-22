import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LifeSystemTest {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Réinitialise les vies de l'utilisateur à 5 (fonction de test uniquement)
  /// 
  /// [uid] : ID de l'utilisateur
  static Future<void> resetVies(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Réinitialisation des vies pour l\'utilisateur $uid...');
      }

      // Référence vers le document utilisateur
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      
      // Réinitialiser les vies restantes à 5
      await userRef.set({
        'livesRemaining': 5,
        'lastLifeUsedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Vies réinitialisées avec succès pour l\'utilisateur $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la réinitialisation des vies: $e');
      }
      rethrow;
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
} 