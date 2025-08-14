import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service complet pour la gestion du profil utilisateur et de toutes ses données personnelles
class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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
      final existingData = existingDoc.data() as Map<String, dynamic>?;

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      
      final Map<String, dynamic> profileData = {
        'profil': {
          'nomAffichage': displayName ?? 'Utilisateur Birdify',
          'email': email,
          'urlAvatar': photoURL,
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        },
        'vies': {
          'compte': 5,
          'max': 5,
          'prochaineRecharge': FieldValue.serverTimestamp(),
        },
        'serie': {
          'jours': 0,
          'dernierJourActif': null,
        },
        'totaux': {
          'scoreTotal': 0,
          'missionsTerminees': 0,
          'xpTotal': 0,
          'niveau': 1,
        },
        'parametres': {
          'langue': 'fr',
          'sonActive': true,
          'notifications': true,
          'theme': 'system',
        },
        'biomesUnlocked': ['milieu urbain'],
        'biomeActuel': 'milieu urbain',
        'derniereConnexion': FieldValue.serverTimestamp(),
        'dateResetQuotidien': Timestamp.fromDate(todayMidnight),
        ...?additionalData,
      };
      
      // Ne définir 'creeLe' qu'une seule fois :
      // - Si le document n'existe pas encore → serverTimestamp()
      // - Si le doc existe sans 'creeLe' mais possède 'createdAt' → recopier 'createdAt' pour conserver l'historique
      // - Sinon, ne pas toucher à 'creeLe'
      final Map<String, dynamic> creationFields = {};
      if (!existingDoc.exists) {
        creationFields['creeLe'] = FieldValue.serverTimestamp();
      } else {
        final hasCreeLe = existingData?.containsKey('creeLe') == true;
        if (!hasCreeLe) {
          final createdAt = existingData?['createdAt'];
          if (createdAt != null) {
            creationFields['creeLe'] = createdAt;
          }
        }
      }

      await userRef.set({...profileData, ...creationFields}, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ Profil utilisateur créé/mis à jour pour $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la création/mise à jour du profil: $e');
      }
      rethrow;
    }
  }

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
        'derniereMiseAJour': FieldValue.serverTimestamp(),
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
    required List<Map<String, dynamic>> reponses,
    String? commentaireAudio,
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
        'totalQuestions': totalQuestions,
        'pourcentage': (score / totalQuestions * 100).round(),
        'reponses': reponses,
        'commentaireAudio': commentaireAudio,
        'commenceLe': FieldValue.serverTimestamp(),
        'termineLe': FieldValue.serverTimestamp(),
      };
      
      await sessionRef.set(sessionData);
      
      // Ajouter de l'XP basé sur le score
      final xpGagne = _calculateQuizXP(score, totalQuestions);
      await addXP(uid, xpGagne, raison: 'Quiz $missionId: $score/$totalQuestions');
      
      // Mettre à jour les statistiques globales
      await _updateGlobalStats(uid, score, totalQuestions);
      
      if (kDebugMode) {
        debugPrint('📊 Session quiz enregistrée: $score/$totalQuestions (+$xpGagne XP)');
      }
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
        'derniereMiseAJour': FieldValue.serverTimestamp(),
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
        'derniereMiseAJour': FieldValue.serverTimestamp(),
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
        'derniereConnexion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour de la dernière connexion: $e');
      }
    }
  }
}
