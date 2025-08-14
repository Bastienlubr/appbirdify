import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LifeSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Vérifie que l'utilisateur est authentifié et que l'UID correspond
  /// 
  /// [uid] : ID de l'utilisateur à vérifier
  /// Retourne true si l'authentification est valide
  static bool _validateAuthentication(String uid) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        debugPrint('❌ Erreur d\'authentification: Aucun utilisateur connecté');
      }
      return false;
    }
    
    if (currentUser.uid != uid) {
      if (kDebugMode) {
        debugPrint('❌ Erreur d\'authentification: UID ne correspond pas (connecté: ${currentUser.uid}, demandé: $uid)');
      }
      return false;
    }
    
    return true;
  }

  /// Obtient une référence sécurisée au document utilisateur
  /// 
  /// [uid] : ID de l'utilisateur
  /// Retourne la référence du document ou null si l'authentification échoue
  static DocumentReference? _getSecureUserDocument(String uid) {
    if (!_validateAuthentication(uid)) {
      return null;
    }
    
    return _firestore.collection('utilisateurs').doc(uid);
  }

  /// Synchronise les vies restantes avec Firestore après un quiz
  /// 
  /// [uid] : ID de l'utilisateur
  /// [livesRemaining] : Nombre de vies restantes (sera clampé entre 0 et 5)
  static Future<void> syncLivesAfterQuiz(String uid, int livesRemaining) async {
    // Mode vies infinies: ne pas synchroniser de décrément
    try {
      final userDocRef = _getSecureUserDocument(uid);
      if (userDocRef != null) {
        final snap = await userDocRef.get();
        final data = snap.data() as Map<String, dynamic>?;
        if ((data?['livesInfinite'] ?? false) == true) {
          if (kDebugMode) debugPrint('♾️ Mode vies infinies actif: synchronisation ignorée');
          return;
        }
      }
    } catch (_) {}
    const maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        // Clamper la valeur entre 0 et 5
        final clampedLives = livesRemaining.clamp(0, 5);
        
        if (kDebugMode) {
          debugPrint('🔄 Synchronisation des vies restantes: $clampedLives pour l\'utilisateur $uid (tentative ${retryCount + 1}/$maxRetries)');
          debugPrint('   - Vies reçues: $livesRemaining');
          debugPrint('   - Vies après clamp: $clampedLives');
        }

        // Obtenir une référence sécurisée au document utilisateur
        final userDoc = _getSecureUserDocument(uid);
        if (userDoc == null) {
          throw Exception('Erreur d\'authentification: Impossible d\'accéder au document utilisateur');
        }

        // Écrire directement la valeur des vies restantes dans Firestore
        await userDoc.set({
          'livesRemaining': clampedLives,
          'lastLifeUsedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          debugPrint('✅ Vies restantes synchronisées avec Firestore: $clampedLives vies pour l\'utilisateur $uid');
        }
        return; // Succès, sortir de la boucle
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          debugPrint('❌ Erreur lors de la synchronisation des vies restantes (tentative $retryCount/$maxRetries): $e');
          debugPrint('   - Stack trace: ${e.toString()}');
        }
        
        if (retryCount >= maxRetries) {
          if (kDebugMode) {
            debugPrint('❌ Échec après $maxRetries tentatives de synchronisation');
          }
          rethrow; // Relancer l'erreur après échec de toutes les tentatives
        } else {
          // Attendre avant de réessayer (backoff exponentiel)
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
  }

  /// Obtient le nombre de vies perdues depuis Firestore
  static Future<int> getLivesLost(String uid) async {
    try {
      // Obtenir une référence sécurisée au document utilisateur
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        if (kDebugMode) {
          debugPrint('❌ Erreur d\'authentification lors de la récupération des vies perdues');
        }
        return 0; // Fallback
      }

      DocumentSnapshot userDocSnapshot = await userDoc.get();
      
      if (userDocSnapshot.exists) {
        final data = userDocSnapshot.data() as Map<String, dynamic>?;
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
      // Obtenir une référence sécurisée au document utilisateur
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        if (kDebugMode) {
          debugPrint('❌ Erreur d\'authentification lors de la récupération des vies');
        }
        return 5; // Fallback
      }

      DocumentSnapshot userDocSnapshot = await userDoc.get();
      
      if (userDocSnapshot.exists) {
        final data = userDocSnapshot.data() as Map<String, dynamic>?;
        if ((data?['livesInfinite'] ?? false) == true) {
          if (kDebugMode) debugPrint('♾️ getCurrentLives: mode vies infinies → retour 5 (affichage)');
          return 5; // Affichage stable
        }
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
    const maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        if (kDebugMode) {
          debugPrint('🔄 Vérification de la réinitialisation quotidienne pour l\'utilisateur $uid (tentative ${retryCount + 1}/$maxRetries)');
        }

        // Obtenir une référence sécurisée au document utilisateur
        final userDoc = _getSecureUserDocument(uid);
        if (userDoc == null) {
          throw Exception('Erreur d\'authentification: Impossible d\'accéder au document utilisateur');
        }

        // Lire les données actuelles de l'utilisateur
        DocumentSnapshot userDocSnapshot = await userDoc.get();
        
        if (!userDocSnapshot.exists) {
          if (kDebugMode) {
            debugPrint('⚠️ Document utilisateur inexistant, création avec 5 vies');
          }
          
          // Si le document n'existe pas, créer avec 5 vies
          await userDoc.set({
            'livesRemaining': 5,
            'dailyResetDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          if (kDebugMode) {
            debugPrint('✅ Document utilisateur créé avec 5 vies pour l\'utilisateur $uid');
          }
          return 5;
        }

        final data = userDocSnapshot.data() as Map<String, dynamic>?;
        if ((data?['livesInfinite'] ?? false) == true) {
          if (kDebugMode) debugPrint('♾️ checkAndResetLives: vies infinies actives → aucune réinitialisation');
          return 5;
        }
        final currentLives = (data?['livesRemaining'] ?? 5) as int;
        
        if (kDebugMode) {
          debugPrint('📊 Données utilisateur récupérées:');
          debugPrint('   - Vies actuelles dans Firestore: $currentLives');
          debugPrint('   - Données complètes: $data');
        }
        
        // Récupérer la date de dernière réinitialisation
        final dailyResetDate = data?['dailyResetDate'] as Timestamp?;
        final lastResetDate = dailyResetDate?.toDate().toLocal() ?? DateTime.now().toLocal();
        
        // Date d'aujourd'hui à minuit
        final todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        
        if (kDebugMode) {
          debugPrint('📅 Dates de réinitialisation:');
          debugPrint('   - Dernière réinitialisation: $lastResetDate');
          debugPrint('   - Aujourd\'hui minuit: $todayMidnight');
          debugPrint('   - Nouveau jour détecté: ${lastResetDate.isBefore(todayMidnight)}');
        }
        
        // Vérifier si on est passé à un nouveau jour
        if (lastResetDate.isBefore(todayMidnight)) {
          if (kDebugMode) {
            debugPrint('🔄 Nouveau jour détecté, réinitialisation des vies à 5 pour l\'utilisateur $uid');
          }
          
          // Réinitialiser les vies à 5 et mettre à jour la date
          await userDoc.set({
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
        retryCount++;
        if (kDebugMode) {
          debugPrint('❌ Erreur lors de la vérification/réinitialisation des vies (tentative $retryCount/$maxRetries): $e');
          debugPrint('   - Stack trace: ${e.toString()}');
        }
        
        if (retryCount >= maxRetries) {
          if (kDebugMode) {
            debugPrint('❌ Échec après $maxRetries tentatives, utilisation du fallback');
          }
          // En cas d'erreur persistante, retourner 5 vies par défaut
          return 5;
        } else {
          // Attendre avant de réessayer (backoff exponentiel)
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
    
    // Fallback final
    return 5;
  }

  /// Vérifie la cohérence des vies et corrige si nécessaire
  /// 
  /// [uid] : ID de l'utilisateur
  /// Retourne le nombre de vies corrigées
  static Future<int> verifyAndFixLives(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 Vérification de la cohérence des vies pour l\'utilisateur $uid');
      }

      // Obtenir une référence sécurisée au document utilisateur
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        if (kDebugMode) {
          debugPrint('❌ Erreur d\'authentification lors de la vérification de cohérence');
        }
        return 5; // Fallback
      }

      DocumentSnapshot userDocSnapshot = await userDoc.get();
      
      if (!userDocSnapshot.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ Document utilisateur inexistant, création avec 5 vies');
        }
        await userDoc.set({
          'livesRemaining': 5,
          'dailyResetDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return 5;
      }

      final data = userDocSnapshot.data() as Map<String, dynamic>?;
      if ((data?['livesInfinite'] ?? false) == true) {
        if (kDebugMode) debugPrint('♾️ verifyAndFixLives: vies infinies → rien à corriger');
        return 5;
      }
      final currentLives = (data?['livesRemaining'] ?? 5) as int;
      final correctedLives = currentLives.clamp(0, 5);
      
      if (currentLives != correctedLives) {
        if (kDebugMode) {
          debugPrint('⚠️ Incohérence détectée: $currentLives → $correctedLives');
        }
        
        // Corriger les vies
        await userDoc.set({
          'livesRemaining': correctedLives,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (kDebugMode) {
          debugPrint('✅ Vies corrigées: $correctedLives');
        }
      } else {
        if (kDebugMode) {
          debugPrint('✅ Vies cohérentes: $correctedLives');
        }
      }
      
      return correctedLives;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la vérification de cohérence: $e');
      }
      return 5; // Fallback
    }
  }

  /// Force la réinitialisation des vies à 5
  /// 
  /// [uid] : ID de l'utilisateur
  /// Retourne le nombre de vies après réinitialisation
  static Future<int> forceResetLives(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Réinitialisation forcée des vies pour l\'utilisateur $uid');
      }

      // Obtenir une référence sécurisée au document utilisateur
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        throw Exception('Erreur d\'authentification: Impossible d\'accéder au document utilisateur');
      }

      await userDoc.set({
        'livesRemaining': 5,
        'dailyResetDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ Vies réinitialisées à 5 pour l\'utilisateur $uid');
      }
      
      return 5;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la réinitialisation forcée: $e');
      }
      return 5; // Fallback
    }
  }


} 