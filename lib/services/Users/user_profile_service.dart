import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'streak_service.dart'; // Unused
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service complet pour la gestion du profil utilisateur et de toutes ses données personnelles
class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // =============================
  // Streams temps réel (profil)
  // =============================

  /// Flux temps réel du document utilisateur complet
  static Stream<Map<String, dynamic>?> profileStream(String uid) {
    return _firestore
        .collection('utilisateurs')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data());
  }

  /// Flux temps réel des favoris (liste d'IDs)
  static Stream<List<String>> favoritesStream(String uid) {
    return _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('favoris')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.id).toList());
  }

  /// Flux temps réel des badges
  static Stream<List<Map<String, dynamic>>> badgesStream(String uid) {
    return _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('badges')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  /// Flux temps réel de la progression des missions
  static Stream<List<Map<String, dynamic>>> missionProgressStream(String uid) {
    return _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  /// Flux temps réel des sessions
  static Stream<List<Map<String, dynamic>>> sessionsStream(String uid) {
    return _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('sessions')
        .orderBy('commenceLe', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  // === PROFIL UTILISATEUR ===
  
  /// Crée ou met à jour le profil utilisateur complet
  static Future<void> createOrUpdateUserProfile({
    required String uid,
    String? displayName,
    String? email,
    String? photoURL,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final userRef = _firestore.collection('utilisateurs').doc(uid);
      // Lire l'état actuel pour ne pas écraser les champs "créés le"
      final existingDoc = await userRef.get();
      final existingData = existingDoc.data();

      // Prochaine minuit (00:00) pour la recharge des vies
      final DateTime now = DateTime.now();
      final DateTime nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

      final Map<String, dynamic> profileData = {
        'profil': {
          'nomAffichage': displayName ?? 'Utilisateur Birdify',
          'email': email,
          'urlAvatar': photoURL,
          'derniereConnexion': FieldValue.serverTimestamp(),
          'estPremium': false,
        },
        'parametres': {
          'langue': 'fr',
          'son': true,
          'notifications': true,
          'theme': null,
        },
        'biomesDeverrouilles': ['milieu urbain'],
        'serie': {
          'derniersJoursActifs': <String>[],
          'serieEnCours': 0,
          'serieMaximum': 0,
        },
        'vie': {
          'vieRestante': 5,
          'vieMaximum': 5,
          'prochaineRecharge': nextMidnight,
        },
        ...?additionalData,
      };
      
      // Ne définir 'profil.creeLe' qu'une seule fois (sous profil) :
      // - Si le document n'existe pas encore → serverTimestamp() sous profil.creeLe
      // - Si le doc existe et possède un 'creeLe' racine → le migrer sous profil.creeLe et supprimer le root
      final Map<String, dynamic> creationFields = {};
      if (!existingDoc.exists) {
        creationFields['profil'] = {
          ...?creationFields['profil'],
          'creeLe': FieldValue.serverTimestamp(),
        };
      } else {
        final profilMap = (existingData?['profil'] as Map<String, dynamic>?) ?? {};
        final hasProfilCreeLe = profilMap.containsKey('creeLe');
        final rootCreeLe = existingData?['creeLe'];
        if (!hasProfilCreeLe && rootCreeLe != null) {
          creationFields['profil'] = {
            ...profilMap,
            'creeLe': rootCreeLe,
          };
          creationFields['creeLe'] = FieldValue.delete();
        }
      }

      await userRef.set({...profileData, ...creationFields}, SetOptions(merge: true));
      
      if (kDebugMode) debugPrint('✅ Profil utilisateur créé/mis à jour pour $uid (schéma unifié)');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la création/mise à jour du profil: $e');
      }
      rethrow;
    }
  }

  /// Met à jour le nom d'affichage
  static Future<void> updateDisplayName({required String uid, required String nomAffichage}) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update({
        'profil.nomAffichage': nomAffichage,
      });
      if (_auth.currentUser?.uid == uid) {
        await _auth.currentUser!.updateDisplayName(nomAffichage);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur updateDisplayName: $e');
      rethrow;
    }
  }

  /// Met à jour l'email (Firestore + FirebaseAuth si utilisateur courant)
  static Future<void> updateEmail({required String uid, required String email}) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update({
        'profil.email': email,
      });
      if (_auth.currentUser?.uid == uid) {
        // Remplace updateEmail déprécié
        await _auth.currentUser!.verifyBeforeUpdateEmail(email);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur updateEmail: $e');
      rethrow;
    }
  }

  /// Met à jour l'URL d'avatar
  static Future<void> updateAvatarUrl({required String uid, required String urlAvatar}) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update({
        'profil.urlAvatar': urlAvatar,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur updateAvatarUrl: $e');
      rethrow;
    }
  }

  /// Active/désactive le premium
  static Future<void> setPremium({required String uid, required bool estPremium}) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update({
        'profil.estPremium': estPremium,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur setPremium: $e');
      rethrow;
    }
  }

  // === PARAMÈTRES ===

  /// Met à jour tout ou partie des paramètres
  static Future<void> updateSettings({
    required String uid,
    String? langue,
    bool? notifications,
    bool? son,
    String? theme,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (langue != null) updates['parametres.langue'] = langue;
      if (notifications != null) updates['parametres.notifications'] = notifications;
      if (son != null) updates['parametres.son'] = son;
      if (theme != null) updates['parametres.theme'] = theme;
      if (updates.isEmpty) return;
      await _firestore.collection('utilisateurs').doc(uid).update(updates);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur updateSettings: $e');
      rethrow;
    }
  }

  static Future<void> setLanguage({required String uid, required String langue}) =>
      updateSettings(uid: uid, langue: langue);

  static Future<void> setNotifications({required String uid, required bool enabled}) =>
      updateSettings(uid: uid, notifications: enabled);

  static Future<void> setSound({required String uid, required bool enabled}) =>
      updateSettings(uid: uid, son: enabled);

  static Future<void> setTheme({required String uid, required String? theme}) =>
      updateSettings(uid: uid, theme: theme);

  /// Obtient le profil complet de l'utilisateur
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final userDoc = await _firestore.collection('utilisateurs').doc(uid).get();
      
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération du profil: $e');
      }
      return null;
    }
  }

  // === FAVORIS ===
  
  /// Ajoute un oiseau aux favoris
  static Future<void> addToFavorites(String uid, String oiseauId) async {
    try {
      final favoriteRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('favoris')
          .doc(oiseauId);
      
      await favoriteRef.set({
        'ajouteLe': FieldValue.serverTimestamp(),
        'oiseauId': oiseauId,
      });
      
      if (kDebugMode) {
        debugPrint('✅ Oiseau $oiseauId ajouté aux favoris');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout aux favoris: $e');
      }
      rethrow;
    }
  }

  /// Retire un oiseau des favoris
  static Future<void> removeFromFavorites(String uid, String oiseauId) async {
    try {
      await _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('favoris')
          .doc(oiseauId)
          .delete();
      
      if (kDebugMode) {
        debugPrint('✅ Oiseau $oiseauId retiré des favoris');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la suppression des favoris: $e');
      }
      rethrow;
    }
  }

  /// Vérifie si un oiseau est dans les favoris
  static Future<bool> isFavorite(String uid, String oiseauId) async {
    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('favoris')
          .doc(oiseauId)
          .get();
      
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la vérification des favoris: $e');
      }
      return false;
    }
  }

  /// Obtient tous les favoris de l'utilisateur
  static Future<List<String>> getFavorites(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('favoris')
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des favoris: $e');
      }
      return [];
    }
  }

  // === BADGES ===
  
  /// Débloque un badge pour l'utilisateur
  static Future<void> unlockBadge(String uid, String badgeId, {
    String niveau = 'bronze',
    String source = 'mission',
  }) async {
    try {
      final badgeRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('badges')
          .doc(badgeId);
      
      await badgeRef.set({
        'obtenuLe': FieldValue.serverTimestamp(),
        'niveau': niveau,
        'source': source,
        'badgeId': badgeId,
      });
      
      if (kDebugMode) {
        debugPrint('🏆 Badge $badgeId ($niveau) débloqué via $source');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du déblocage du badge: $e');
      }
      rethrow;
    }
  }

  /// Obtient tous les badges de l'utilisateur
  static Future<List<Map<String, dynamic>>> getBadges(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('badges')
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des badges: $e');
      }
      return [];
    }
  }

  // === XP ET NIVEAUX ===
  
  /// Ajoute de l'XP à l'utilisateur
  static Future<void> addXP(String uid, int xpToAdd, {String? raison}) async {
    try {
      final userRef = _firestore.collection('utilisateurs').doc(uid);
      
      // Récupérer l'XP actuel
      final userDoc = await userRef.get();
      final currentData = userDoc.data();
      final currentXP = currentData?['totaux']?['xpTotal'] ?? 0;
      final currentLevel = currentData?['totaux']?['niveau'] ?? 1;
      
      final newXP = currentXP + xpToAdd;
      final newLevel = _calculateLevel(newXP);
      
      // Mettre à jour l'XP et le niveau
      await userRef.update({
        'totaux.xpTotal': newXP,
        'totaux.niveau': newLevel,
      });
      
      // Si le niveau a augmenté, débloquer un badge
      if (newLevel > currentLevel) {
        final badgeId = 'niveau_$newLevel';
        await unlockBadge(uid, badgeId, 
          niveau: _getLevelBadgeType(newLevel), 
          source: 'progression'
        );
      }
      
      if (kDebugMode) {
        debugPrint('⭐ XP ajouté: +$xpToAdd (total: $newXP, niveau: $newLevel)');
        if (raison != null) debugPrint('   Raison: $raison');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout d\'XP: $e');
      }
      rethrow;
    }
  }

  /// Calcule le niveau basé sur l'XP total
  static int _calculateLevel(int xpTotal) {
    // Formule : niveau = 1 + sqrt(xpTotal / 100)
    return 1 + sqrt(xpTotal / 100.0).floor();
  }

  /// Détermine le type de badge pour un niveau
  static String _getLevelBadgeType(int level) {
    if (level >= 50) return 'diamant';
    if (level >= 25) return 'or';
    if (level >= 10) return 'argent';
    return 'bronze';
  }

  // === SESSIONS DE QUIZ ===
  
  /// Enregistre une session de quiz
  static Future<void> recordQuizSession(String uid, {
    required String missionId,
    required int score,
    required int totalQuestions,
    required List<String> especesRateesIds,
    required int dureeSeconds,
    required List<Map<String, dynamic>> reponses,
    String? milieu,
  }) async {
    try {
      final sessionRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('sessions')
          .doc();
      
      final sessionData = {
        'idMission': missionId,
        'score': score,
        'especesRateesIds': especesRateesIds, // [id]
        'totalQuestions': totalQuestions,
        'dureeSeconds': dureeSeconds,
        'reponses': reponses,
        'commenceLe': FieldValue.serverTimestamp(),
      };
      if (milieu != null && milieu.isNotEmpty) {
        sessionData['milieu'] = milieu;
      }
      
      await sessionRef.set(sessionData);
      
      // Ajouter de l'XP basé sur le score
      final xpGagne = _calculateQuizXP(score, totalQuestions);
      await addXP(uid, xpGagne, raison: 'Quiz $missionId: $score/$totalQuestions');
      
      // Mettre à jour les statistiques globales
      await _updateGlobalStats(uid, score, totalQuestions);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'enregistrement de la session: $e');
      }
      rethrow;
    }
  }

  /// Calcule l'XP gagné pour un quiz
  static int _calculateQuizXP(int score, int totalQuestions) {
    final ratio = score / totalQuestions;
    if (ratio >= 0.9) return 50;      // Excellent
    if (ratio >= 0.7) return 30;      // Très bien
    if (ratio >= 0.5) return 20;      // Bien
    if (ratio >= 0.3) return 10;      // Moyen
    return 5;                          // À améliorer
  }

  /// Met à jour les statistiques globales
  static Future<void> _updateGlobalStats(String uid, int score, int totalQuestions) async {
    try {
      final userRef = _firestore.collection('utilisateurs').doc(uid);
      
      await userRef.update({
        'totaux.scoreTotal': FieldValue.increment(score),
        'totaux.missionsTerminees': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour des stats: $e');
      }
    }
  }

  // === PROGRESSION DES MISSIONS ===
  
  /// Met à jour la progression d'une mission
  static Future<void> updateMissionProgress(String uid, String missionId, {
    required int etoiles,
    required int score,
    required bool deverrouille,
  }) async {
    try {
      final progressRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('progression_missions')
          .doc(missionId);
      
      await progressRef.set({
        'etoiles': etoiles,
        'meilleurScore': score,
        'tentatives': FieldValue.increment(1),
        'deverrouille': deverrouille,
        'dernierePartieLe': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('🎯 Progression mission $missionId mise à jour: $etoiles étoiles, score $score');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour de la progression: $e');
      }
      rethrow;
    }
  }

  /// Obtient la progression d'une mission
  static Future<Map<String, dynamic>?> getMissionProgress(String uid, String missionId) async {
    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('progression_missions')
          .doc(missionId)
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération de la progression: $e');
      }
      return null;
    }
  }

  // === UTILITAIRES ===
  
  /// Obtient l'ID de l'utilisateur actuel
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Vérifie si un utilisateur est connecté
  static bool get isUserLoggedIn {
    return _auth.currentUser != null;
  }

  /// Obtient le profil de l'utilisateur actuel
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final uid = getCurrentUserId();
    if (uid == null) return null;
    return await getUserProfile(uid);
  }

  /// Met à jour la dernière connexion
  static Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update({
        'profil.derniereConnexion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour de la dernière connexion: $e');
      }
    }
  }
}
