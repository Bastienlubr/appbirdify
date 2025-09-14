import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service centralisé pour la gestion des vies utilisateur (Firestore)
/// Remplace l'ancien LifeSyncService. Toutes les opérations liées aux vies
/// doivent passer par ce service unique.
class LifeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Vérifie que l'utilisateur est authentifié et que l'UID correspond
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
  static DocumentReference? _getSecureUserDocument(String uid) {
    if (!_validateAuthentication(uid)) {
      return null;
    }
    return _firestore.collection('utilisateurs').doc(uid);
  }

  // On n'utilise plus de sous-collection pour les vies. Tout est stocké
  // dans le document utilisateur sous la clé imbriquée `vie.{...}`.

  /// Synchronise les vies restantes avec Firestore après un quiz
  static Future<void> syncLivesAfterQuiz(String uid, int livesRemaining) async {
    try {
      final userDocRef = _getSecureUserDocument(uid);
      if (userDocRef != null) {
        final snap = await userDocRef.get();
        final data = snap.data() as Map<String, dynamic>?;
        if ((data?['vie']?['livesInfinite'] == true) || (data?['livesInfinite'] == true)) {
          if (kDebugMode) debugPrint('♾️ Mode vies infinies actif: synchronisation ignorée');
          return;
        }
      }
    } catch (_) {}

    const maxRetries = 3;
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        // Récupérer le plafond depuis Firestore
        int maxLives = 5;
        try {
          final userDoc = _getSecureUserDocument(uid);
          final snap = await userDoc!.get();
          final data = snap.data() as Map<String, dynamic>?;
          final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
              ? (data?['vie'] as Map<String, dynamic>)
              : null;
          maxLives = (vie?['vieMaximum'] as int? ?? data?['vies']?['max'] as int? ?? 5).clamp(1, 50);
        } catch (_) {}

        final clampedLives = livesRemaining.clamp(0, maxLives);

        if (kDebugMode) {
          debugPrint('🔄 Synchronisation des vies restantes: $clampedLives pour l\'utilisateur $uid (tentative ${retryCount + 1}/$maxRetries)');
          debugPrint('   - Vies reçues: $livesRemaining');
          debugPrint('   - Vies après clamp: $clampedLives');
        }

        final userDoc = _getSecureUserDocument(uid);
        if (userDoc == null) {
          throw Exception('Erreur d\'authentification: Impossible d\'accéder au document utilisateur');
        }

        await userDoc.set({
          'vie': {
            'vieRestante': clampedLives,
          },
          // plus d'écriture du champ root lastUpdated
          // Nettoyage clés dottées à chaque écriture
          'vie.Vie restante': FieldValue.delete(),
          'vie.vieRestante': FieldValue.delete(),
          'vie.vieMaximum': FieldValue.delete(),
          'vie.prochaineRecharge': FieldValue.delete(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          debugPrint('✅ Vies restantes synchronisées avec Firestore: $clampedLives vies pour l\'utilisateur $uid');
        }
        return;
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
          rethrow;
        } else {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
  }

  /// Obtient le nombre de vies perdues (calculé: vieMaximum - Vie restante)
  static Future<int> getLivesLost(String uid) async {
    try {
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        if (kDebugMode) {
          debugPrint('❌ Erreur d\'authentification lors de la récupération des vies perdues');
        }
        return 0;
      }

      final snap = await userDoc.get();
      if (!snap.exists) return 0;
      final data = snap.data() as Map<String, dynamic>?;
      if ((data?['vie']?['livesInfinite'] == true) || (data?['livesInfinite'] == true)) {
        return 0;
      }
      final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
          ? (data?['vie'] as Map<String, dynamic>)
          : null;
      final int maxLives = (vie?['vieMaximum'] as int? ?? 5).clamp(1, 10);
      final int currentLives = (vie?['Vie restante'] as int? ?? 5).clamp(0, maxLives);
      return (maxLives - currentLives).clamp(0, maxLives);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des vies perdues: $e');
      }
      return 0;
    }
  }

  /// Retourne le nombre de vies actuelles
  static Future<int> getCurrentLives(String uid) async {
    try {
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        if (kDebugMode) {
          debugPrint('❌ Erreur d\'authentification lors de la récupération des vies');
        }
        return 5;
      }

      DocumentSnapshot userDocSnapshot = await userDoc.get();
      if (userDocSnapshot.exists) {
        final data = userDocSnapshot.data() as Map<String, dynamic>?;
        if ((data?['vie']?['livesInfinite'] == true) || (data?['livesInfinite'] == true)) {
          if (kDebugMode) debugPrint('♾️ getCurrentLives: vies infinies (vie.livesInfinite) → retour 5 (affichage)');
          return 5;
        }
        final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
            ? (data?['vie'] as Map<String, dynamic>)
            : null;
        final Map<String, dynamic>? vies = data?['vies'] is Map<String, dynamic>
            ? (data?['vies'] as Map<String, dynamic>)
            : null;
        // Lire le maximum depuis Firestore (fallback 5)
        final int maxLives = (vie?['vieMaximum'] as int? ?? data?['vies']?['max'] as int? ?? 5).clamp(1, 50);
        final dynamic livesNew = vie?['vieRestante'];
        final dynamic livesSingular = vie?['Vie restante'];
        final dynamic livesTopFr = data?['Vie restante'];
        final dynamic livesNestedFr = vies?['Vie restante'];
        final dynamic livesLegacy = data?['livesRemaining'];
        final dynamic livesOldNested = vies?['compte'] ?? vie?['compte'];
        final int lives = (livesNew ?? livesSingular ?? livesTopFr ?? livesNestedFr ?? livesLegacy ?? livesOldNested ?? 5) as int;
        return lives.clamp(0, maxLives);
      }
      return 5;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des vies actuelles: $e');
      }
      return 5;
    }
  }

  /// Vérifie et réinitialise les vies à 5 si un nouveau jour commence
  static Future<int> checkAndResetLives(String uid) async {
    const maxRetries = 3;
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        if (kDebugMode) {
          debugPrint('🔄 Vérification de la réinitialisation quotidienne pour l\'utilisateur $uid (tentative ${retryCount + 1}/$maxRetries)');
        }

        final userDoc = _getSecureUserDocument(uid);
        if (userDoc == null) {
          throw Exception('Erreur d\'authentification: Impossible d\'accéder au document utilisateur');
        }

        DocumentSnapshot userDocSnapshot = await userDoc.get();
        if (!userDocSnapshot.exists) {
          if (kDebugMode) {
            debugPrint('⚠️ Document utilisateur inexistant, création avec 5 vies');
          }
          await userDoc.set({
            'vie': {
              'vieRestante': 5,
              'prochaineRecharge': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
            },
            // plus d'écriture du champ root lastUpdated
            'livesRemaining': FieldValue.delete(),
            'vies.compte': FieldValue.delete(),
            'vies.Vie restante': FieldValue.delete(),
            'vies.prochaineRecharge': FieldValue.delete(),
            'Vie restante': FieldValue.delete(),
            'prochaineRecharge': FieldValue.delete(),
            'vie.Vie restante': FieldValue.delete(),
            'vie.vieRestante': FieldValue.delete(),
            'vie.vieMaximum': FieldValue.delete(),
            'vie.prochaineRecharge': FieldValue.delete(),
          }, SetOptions(merge: true));
          if (kDebugMode) {
            debugPrint('✅ Document utilisateur créé avec 5 vies pour l\'utilisateur $uid');
          }
          return 5;
        }

        final data = userDocSnapshot.data() as Map<String, dynamic>?;
        if ((data?['vie']?['livesInfinite'] == true) || (data?['livesInfinite'] == true)) {
          if (kDebugMode) debugPrint('♾️ checkAndResetLives: vies infinies actives (vie.livesInfinite) → aucune réinitialisation');
          return 5;
        }
        final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
            ? (data?['vie'] as Map<String, dynamic>)
            : null;
        final Map<String, dynamic>? vies = data?['vies'] is Map<String, dynamic>
            ? (data?['vies'] as Map<String, dynamic>)
            : null;
        final int maxLives = (vie?['vieMaximum'] as int? ?? data?['vies']?['max'] as int? ?? 5).clamp(1, 50);
        final int currentLives = (vie?['vieRestante'] as int?
              ?? data?['Vie restante'] as int?
              ?? vies?['Vie restante'] as int?
              ?? data?['livesRemaining'] as int?
              ?? vie?['compte'] as int?
              ?? vies?['compte'] as int?
              ?? 5)
            .clamp(0, maxLives);
        final Timestamp? prochaineRechargeTs = (vie?['prochaineRecharge'] as Timestamp?)
            ?? (data?['prochaineRecharge'] as Timestamp?)
            ?? (vies?['prochaineRecharge'] as Timestamp?);
        final DateTime now = DateTime.now();
        final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);

        if (kDebugMode) {
          debugPrint('📊 Données utilisateur récupérées:');
          debugPrint('   - Vies actuelles dans Firestore: $currentLives');
          debugPrint('   - Données complètes: $data');
        }

        final bool shouldReset = prochaineRechargeTs != null
            ? now.isAfter(prochaineRechargeTs.toDate()) || now.isAtSameMomentAs(prochaineRechargeTs.toDate())
            : false;
        if (currentLives > maxLives) {
          if (kDebugMode) {
            debugPrint('⚠️ vieRestante ($currentLives) > vieMaximum ($maxLives) → correction');
          }
          await userDoc.set({
            'vie': {
              'vieRestante': maxLives,
            },
          }, SetOptions(merge: true));
          return maxLives;
        } else if (shouldReset) {
          if (kDebugMode) {
            debugPrint('🔄 Prochaine recharge atteinte, réinitialisation des vies à 5 pour l\'utilisateur $uid');
          }
          await userDoc.set({
            'vie': {
              'vieRestante': maxLives,
              'prochaineRecharge': nextMidnight,
            },
            // plus d'écriture du champ root lastUpdated
            'Vie restante': FieldValue.delete(),
            'prochaineRecharge': FieldValue.delete(),
            'livesRemaining': FieldValue.delete(),
            'vies.compte': FieldValue.delete(),
            'vies.Vie restante': FieldValue.delete(),
            'vies.prochaineRecharge': FieldValue.delete(),
            'vie.Vie restante': FieldValue.delete(),
            'vie.vieRestante': FieldValue.delete(),
            'vie.vieMaximum': FieldValue.delete(),
            'vie.prochaineRecharge': FieldValue.delete(),
          }, SetOptions(merge: true));
          if (kDebugMode) {
            debugPrint('✅ Vies réinitialisées au maximum ($maxLives) pour l\'utilisateur $uid');
          }
          return maxLives;
        } else {
          if (kDebugMode) {
            debugPrint('✅ Pas de réinitialisation nécessaire, vies actuelles: $currentLives pour l\'utilisateur $uid');
          }
          return currentLives.clamp(0, maxLives);
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
          return 5;
        } else {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
    return 5;
  }

  /// Vérifie la cohérence des vies et corrige si nécessaire
  static Future<int> verifyAndFixLives(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 Vérification de la cohérence des vies pour l\'utilisateur $uid');
      }

      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        if (kDebugMode) {
          debugPrint('❌ Erreur d\'authentification lors de la vérification de cohérence');
        }
        return 5;
      }

      DocumentSnapshot userDocSnapshot = await userDoc.get();
      if (!userDocSnapshot.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ Document utilisateur inexistant, création avec 5 vies');
        }
        await userDoc.set({
          'vie': {
            'vieRestante': 5,
            'prochaineRecharge': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'livesRemaining': FieldValue.delete(),
          'Vie restante': FieldValue.delete(),
          'vies.compte': FieldValue.delete(),
          'vies.Vie restante': FieldValue.delete(),
          'vie.Vie restante': FieldValue.delete(),
          'vie.vieRestante': FieldValue.delete(),
          'vie.vieMaximum': FieldValue.delete(),
          'vie.prochaineRecharge': FieldValue.delete(),
        }, SetOptions(merge: true));
        return 5;
      }

      final data = userDocSnapshot.data() as Map<String, dynamic>?;
      if ((data?['vie']?['livesInfinite'] == true) || (data?['livesInfinite'] == true)) {
        if (kDebugMode) debugPrint('♾️ verifyAndFixLives: vies infinies (vie.livesInfinite) → rien à corriger');
        return 5;
      }
      final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
          ? (data?['vie'] as Map<String, dynamic>)
          : null;
      final Map<String, dynamic>? vies = data?['vies'] is Map<String, dynamic>
          ? (data?['vies'] as Map<String, dynamic>)
          : null;
      final int currentLives = (vie?['vieRestante'] as int?
            ?? data?['Vie restante'] as int?
            ?? vies?['Vie restante'] as int?
            ?? data?['livesRemaining'] as int?
            ?? vie?['compte'] as int?
            ?? vies?['compte'] as int?
            ?? 5)
          .clamp(0, 5);
      final correctedLives = currentLives.clamp(0, 5);

      if (currentLives != correctedLives) {
        if (kDebugMode) {
          debugPrint('⚠️ Incohérence détectée: $currentLives → $correctedLives');
        }
        await userDoc.set({
          'vie': {
            'vieRestante': correctedLives,
          },
          // plus d'écriture du champ root lastUpdated
          'Vie restante': FieldValue.delete(),
          'livesRemaining': FieldValue.delete(),
          'vies.compte': FieldValue.delete(),
          'vies.Vie restante': FieldValue.delete(),
          'vie.Vie restante': FieldValue.delete(),
          'vie.vieRestante': FieldValue.delete(),
          'vie.vieMaximum': FieldValue.delete(),
          'vie.prochaineRecharge': FieldValue.delete(),
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
      return 5;
    }
  }

  /// Réinitialisation forcée des vies à 5
  static Future<int> forceResetLives(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Réinitialisation forcée des vies pour l\'utilisateur $uid');
      }

      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) {
        throw Exception('Erreur d\'authentification: Impossible d\'accéder au document utilisateur');
      }

      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day + 1);
      await userDoc.set({
        'vie': {
          'vieRestante': 5,
          'prochaineRecharge': nextMidnight,
        },
        // plus d'écriture du champ root lastUpdated
        'Vie restante': FieldValue.delete(),
        'prochaineRecharge': FieldValue.delete(),
        'livesRemaining': FieldValue.delete(),
        'vies.compte': FieldValue.delete(),
        'vies.Vie restante': FieldValue.delete(),
        'vies.prochaineRecharge': FieldValue.delete(),
        'vie.Vie restante': FieldValue.delete(),
        'vie.vieRestante': FieldValue.delete(),
        'vie.vieMaximum': FieldValue.delete(),
        'vie.prochaineRecharge': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Vies réinitialisées à 5 pour l\'utilisateur $uid');
      }
      return 5;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la réinitialisation forcée: $e');
      }
      return 5;
    }
  }

  /// Migration des champs legacy vers le schéma unifié
  static Future<void> migrateLivesField(String uid) async {
    try {
      final userDoc = _getSecureUserDocument(uid);
      if (userDoc == null) return;

      final snap = await userDoc.get();
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final hasTopFr = data.containsKey('Vie restante');
      final hasLegacy = data.containsKey('livesRemaining');
      final Map<String, dynamic>? vie = data['vie'] is Map<String, dynamic> ? (data['vie'] as Map<String, dynamic>) : null;
      final Map<String, dynamic>? vies = data['vies'] is Map<String, dynamic> ? (data['vies'] as Map<String, dynamic>) : null;
      final bool hasNestedFr = vies?.containsKey('Vie restante') == true;
      final bool hasSingular = vie?.containsKey('Vie restante') == true;
      final bool hasOldNested = vies?.containsKey('compte') == true || vie?.containsKey('compte') == true;

      int? value;
      if (!hasTopFr && hasLegacy) {
        value = (data['livesRemaining'] as int?)?.clamp(0, 5);
      } else if (!hasTopFr && hasNestedFr) {
        value = (vies?['Vie restante'] as int?)?.clamp(0, 5);
      } else if (!hasTopFr && hasSingular) {
        value = (vie?['Vie restante'] as int?)?.clamp(0, 5);
      } else if (!hasTopFr && hasOldNested) {
        value = ((vies?['compte'] ?? vie?['compte']) as int?)?.clamp(0, 5);
      }
      if (value != null) {
        await userDoc.set({
          'vie': {
            'vieRestante': value,
          },
          'livesRemaining': FieldValue.delete(),
          'Vie restante': FieldValue.delete(),
          'vies.compte': FieldValue.delete(),
          'vies.Vie restante': FieldValue.delete(),
          'prochaineRecharge': FieldValue.delete(),
          'vies.prochaineRecharge': FieldValue.delete(),
          'vie.Vie restante': FieldValue.delete(),
          'vie.vieRestante': FieldValue.delete(),
          'vie.vieMaximum': FieldValue.delete(),
          'vie.prochaineRecharge': FieldValue.delete(),
          // plus d'écriture du champ root lastUpdated
        }, SetOptions(merge: true));
        if (kDebugMode) debugPrint('🔁 Migration des vies → mapping "vie.vieRestante" ($value)');
      }

      // Migrer livesInfinite racine vers vie.livesInfinite
      if (data.containsKey('livesInfinite')) {
        final bool li = (data['livesInfinite'] == true);
        await userDoc.set({
          'vie': {
            'livesInfinite': li,
          },
          // Supprimer toujours l'ancien champ résiduel
          'livesInfinite': FieldValue.delete(),
        }, SetOptions(merge: true));
        if (kDebugMode) debugPrint('🔁 Migration livesInfinite → vie.livesInfinite ($li) + suppression racine');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur migration champ vies: $e');
    }
  }

  /// ID de l'utilisateur courant
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Indique si un utilisateur est connecté
  static bool get isUserLoggedIn {
    return _auth.currentUser != null;
  }

  // (supprimé) addLives(uid, delta) remplacé par addLivesTransactional

  /// Version transactionnelle: lit et écrit de façon atomique et renvoie {before, after, max}
  static Future<Map<String, int>> addLivesTransactional(String uid, int delta) async {
    final userDoc = _getSecureUserDocument(uid);
    if (userDoc == null) {
      return {'before': 5, 'after': 5, 'max': 5};
    }
    return await _firestore.runTransaction<Map<String, int>>((txn) async {
      final snap = await txn.get(userDoc);
      final data = snap.data() as Map<String, dynamic>?;
      if ((data?['vie']?['livesInfinite'] == true) || (data?['livesInfinite'] == true)) {
        return {'before': 5, 'after': 5, 'max': 5};
      }
      final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
          ? (data?['vie'] as Map<String, dynamic>)
          : null;
      final Map<String, dynamic>? vies = data?['vies'] is Map<String, dynamic>
          ? (data?['vies'] as Map<String, dynamic>)
          : null;

      // Déterminer max à partir des différentes variantes
      final int maxLives = (vie?['vieMaximum'] as int?
            ?? data?['vies']?['max'] as int?
            ?? 5)
          .clamp(1, 50);

      // Lire le courant depuis toutes les variantes connues (héritage inclus)
      final dynamic livesNew = vie?['vieRestante'];
      final dynamic livesSingular = vie?['Vie restante'];
      final dynamic livesTopFr = data?['Vie restante'];
      final dynamic livesNestedFr = vies?['Vie restante'];
      final dynamic livesLegacy = data?['livesRemaining'];
      final dynamic livesOldNested = vies?['compte'] ?? vie?['compte'];
      final int current = (livesNew ?? livesSingular ?? livesTopFr ?? livesNestedFr ?? livesLegacy ?? livesOldNested ?? 5) as int;

      final int currentClamped = current.clamp(0, maxLives);
      final int updated = (currentClamped + delta).clamp(0, maxLives);
      txn.set(userDoc, {
        'vie': {
          'vieRestante': updated,
        },
        'vie.Vie restante': FieldValue.delete(),
        'Vie restante': FieldValue.delete(),
        'livesRemaining': FieldValue.delete(),
        'vies.compte': FieldValue.delete(),
        'vies.Vie restante': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('❤️ addLivesTransactional: $currentClamped -> $updated (max=$maxLives)');
      return {'before': currentClamped, 'after': updated, 'max': maxLives};
    });
  }

  // (supprimé) ensureMaxLivesAtLeast — non utilisé
}


