import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
// import supprimé: premium_service
import 'life_service.dart';
// PremiumService supprimé lors de la refonte
import 'user_profile_service.dart';
import 'user_avatar_service.dart';

/// Chef d'orchestre des systèmes utilisateur.
/// Centralise l'initialisation, l'arrêt et les opérations transverses.
class UserOrchestra {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === ÉTAT ET STREAMS (repris de l'ancien UserSyncService) ===
  static Stream<Map<String, dynamic>?>? _profileStream;
  static Stream<List<String>>? _favoritesStream;
  static Stream<List<Map<String, dynamic>>>? _badgesStream;
  static Stream<List<Map<String, dynamic>>>? _missionProgressStream;
  static Stream<List<Map<String, dynamic>>>? _sessionsStream;

  static Map<String, dynamic>? _currentProfile;
  static List<String> _currentFavorites = [];
  static List<Map<String, dynamic>> _currentBadges = [];
  static List<Map<String, dynamic>> _currentMissionProgress = [];
  static List<Map<String, dynamic>> _currentSessions = [];

  static final List<StreamSubscription<dynamic>> _activeSubscriptions = [];

  static final List<Function()> _profileCallbacks = [];
  static final List<Function()> _favoritesCallbacks = [];
  static final List<Function()> _badgesCallbacks = [];
  static final List<Function()> _missionProgressCallbacks = [];
  static final List<Function()> _sessionsCallbacks = [];

  /// Démarre tous les sous-systèmes pour l'utilisateur courant
  static Future<void> startForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('⚠️ UserOrchestra.start: aucun utilisateur connecté');
      return;
    }

    final String uid = user.uid;
    if (kDebugMode) debugPrint('🎼 UserOrchestra.start → uid=$uid');

    try {
      // 1) S'assurer que le document utilisateur existe
      final firestoreService = FirestoreService();
      await firestoreService.createUserDocumentIfNeeded(uid);
      // Migration: déplacer un éventuel 'creeLe' racine sous profil.creeLe
      try {
        final userDocRef = FirebaseFirestore.instance.collection('utilisateurs').doc(uid);
        final snap = await userDocRef.get();
        final data = snap.data();
        if (data != null && data.containsKey('creeLe')) {
          await userDocRef.set({
            'profil': {
              ...((data['profil'] as Map<String, dynamic>?) ?? {}),
              'creeLe': data['creeLe'],
            },
            'creeLe': FieldValue.delete(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      // 2) Enrichir le profil (email, nom, premium, dernière connexion)
      try {
        await FirebaseAuth.instance.currentUser?.reload();
      } catch (_) {}
      final userRef = FirebaseAuth.instance.currentUser;
      try {
        await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).set({
          'profil': {
            'email': userRef?.email,
            'nomAffichage': userRef?.displayName,
            'estPremium': false,
            'derniereConnexion': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      } catch (_) {}

      // 3) Réinitialiser le schéma si nécessaire (one-shot), en conservant sessions & progression
      await _resetSchemaIfNeeded(uid);

      // 4) Préparer le système de vie (migration + cohérence)
      await LifeService.migrateLivesField(uid);
      await LifeService.verifyAndFixLives(uid);

      // 5) Harmoniser et nettoyer les champs hérités
      try {
        final userDocRef = FirebaseFirestore.instance.collection('utilisateurs').doc(uid);
        await userDocRef.get();
        final hasNewBiomes = false; // biomesDeverrouilles supprimé
        final legacyBiomes = null; // non utilisé

        final Map<String, dynamic> updates = {
          // Suppression des anciens champs
          'xp': FieldValue.delete(),
          'isPremium': FieldValue.delete(),
          'currentBiome': FieldValue.delete(),
          'biomesUnlocked': FieldValue.delete(), // legacy supprimé
          'biomesDeverrouilles': FieldValue.delete(), // supprimer si présent
          'Vie restante': FieldValue.delete(),
          'livesRemaining': FieldValue.delete(),
          'prochaineRecharge': FieldValue.delete(),
          'dailyResetDate': FieldValue.delete(),
          'livesLost': FieldValue.delete(),
          'vies.compte': FieldValue.delete(),
          'vies.max': FieldValue.delete(),
          'vies.Vie restante': FieldValue.delete(),
          'vies.prochaineRecharge': FieldValue.delete(),
          // Nettoyage des clés dottées indésirables
          'vie.vieRestante': FieldValue.delete(),
          'vie.vieMaximum': FieldValue.delete(),
          'vie.prochaineRecharge': FieldValue.delete(),
          // Ne plus écrire lastUpdated
          'lastUpdated': FieldValue.delete(),
        };

        if (!hasNewBiomes && legacyBiomes != null && legacyBiomes.isNotEmpty) {
          updates['biomesDeverrouilles'] = legacyBiomes;
        }

        await userDocRef.set(updates, SetOptions(merge: true));
      } catch (_) {}

      // 6) Démarrer la synchronisation temps réel unifiée
      await startRealtime();

      // 7) Premium supprimé: aucun démarrage IAP

      // 8) Avatar: écouter et précharger la photo de profil pour l'UI
      try {
        await UserAvatarService.instance.start();
      } catch (_) {}

      if (kDebugMode) debugPrint('✅ UserOrchestra démarré');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ UserOrchestra.start erreur: $e');
      rethrow;
    }
  }

  /// Arrête tous les sous-systèmes
  static void stop() {
    if (kDebugMode) debugPrint('🛑 UserOrchestra.stop');
    try {
      stopRealtime();
    } catch (_) {}
    // Premium supprimé: rien à arrêter
    try {
      UserAvatarService.instance.stop();
    } catch (_) {}
  }

  // === Facades utiles (délégation vers LifeService) ===

  static String? get currentUserId => LifeService.getCurrentUserId();
  static bool get isUserLoggedIn => LifeService.isUserLoggedIn;

  static Future<int> getCurrentLives(String uid) => LifeService.getCurrentLives(uid);
  static Future<int> checkAndResetLives(String uid) => LifeService.checkAndResetLives(uid);
  static Future<int> verifyAndFixLives(String uid) => LifeService.verifyAndFixLives(uid);
  static Future<void> syncLivesAfterQuiz(String uid, int livesRemaining) => LifeService.syncLivesAfterQuiz(uid, livesRemaining);
  static Future<int> forceResetLives(String uid) => LifeService.forceResetLives(uid);

  // === SYNC TEMPS RÉEL (intégration de l'ancien UserSyncService) ===

  static Future<void> startRealtime() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté, sync temps réel impossible');
      return;
    }

    if (kDebugMode) debugPrint('🔄 Démarrage sync temps réel pour ${user.uid}');
    try {
      await _startProfileStream(user.uid);
      await _startFavoritesStream(user.uid);
      await _startBadgesStream(user.uid);
      await _startMissionProgressStream(user.uid);
      await _startSessionsStream(user.uid);

      await UserProfileService.updateLastLogin(user.uid);
      // Si l'accès premium est autorisé, pousser immédiatement l'état premium côté profil et vies
      try {
        final currentAbo = await FirebaseFirestore.instance
            .collection('utilisateurs').doc(user.uid)
            .collection('abonnement').doc('current').get();
        final d = currentAbo.data();
        final bool accesAutorise = d?['accesAutorise'] == true;
        if (accesAutorise) {
          await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).set({
            'profil': {'estPremium': true},
            'vie': {'livesInfinite': true},
          }, SetOptions(merge: true));
        }
      } catch (_) {}
      if (kDebugMode) debugPrint('✅ Sync temps réel démarrée');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur démarrage sync temps réel: $e');
      rethrow;
    }
  }

  static void stopRealtime() {
    if (kDebugMode) debugPrint('🛑 Arrêt sync temps réel');
    for (final sub in _activeSubscriptions) {
      sub.cancel();
    }
    _activeSubscriptions.clear();
    _profileStream = null;
    _favoritesStream = null;
    _badgesStream = null;
    _missionProgressStream = null;
    _sessionsStream = null;
    _profileCallbacks.clear();
    _favoritesCallbacks.clear();
    _badgesCallbacks.clear();
    _missionProgressCallbacks.clear();
    _sessionsCallbacks.clear();
  }

  static Future<void> _startProfileStream(String uid) async {
    _profileStream = _firestore.collection('utilisateurs').doc(uid).snapshots().map((d) => d.exists ? d.data() : null);
    final sub = _profileStream!.listen((profile) {
      _currentProfile = profile;
      if (kDebugMode) debugPrint('📊 Profil mis à jour: ${profile?['profil']?['nomAffichage']}');
      _notifyProfileCallbacks();
    }, onError: (e) {
      if (kDebugMode) debugPrint('❌ Erreur stream profil: $e');
    });
    _activeSubscriptions.add(sub);
  }

  static Future<void> _startFavoritesStream(String uid) async {
    _favoritesStream = _firestore.collection('utilisateurs').doc(uid).collection('favoris').snapshots().map((s) => s.docs.map((d) => d.id).toList());
    final sub = _favoritesStream!.listen((favorites) {
      _currentFavorites = favorites;
      if (kDebugMode) debugPrint('❤️ Favoris mis à jour: ${favorites.length}');
      _notifyFavoritesCallbacks();
    }, onError: (e) {
      if (kDebugMode) debugPrint('❌ Erreur stream favoris: $e');
    });
    _activeSubscriptions.add(sub);
  }

  static Future<void> _startBadgesStream(String uid) async {
    _badgesStream = _firestore.collection('utilisateurs').doc(uid).collection('badges').snapshots().map((s) => s.docs.map((d) => d.data()).toList());
    final sub = _badgesStream!.listen((badges) {
      _currentBadges = badges;
      if (kDebugMode) debugPrint('🏆 Badges mis à jour: ${badges.length}');
      _notifyBadgesCallbacks();
    }, onError: (e) {
      if (kDebugMode) debugPrint('❌ Erreur stream badges: $e');
    });
    _activeSubscriptions.add(sub);
  }

  static Future<void> _startMissionProgressStream(String uid) async {
    _missionProgressStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
    final sub = _missionProgressStream!.listen((progress) {
      _currentMissionProgress = progress;
      if (kDebugMode) debugPrint('🎯 Progression missions mise à jour: ${progress.length}');
      _notifyMissionProgressCallbacks();
    }, onError: (e) {
      if (kDebugMode) debugPrint('❌ Erreur stream progression: $e');
    });
    _activeSubscriptions.add(sub);
  }

  static Future<void> _startSessionsStream(String uid) async {
    _sessionsStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('sessions')
        .orderBy('termineLe', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
    final sub = _sessionsStream!.listen((sessions) {
      _currentSessions = sessions;
      if (kDebugMode) debugPrint('📊 Sessions mises à jour: ${sessions.length}');
      _notifySessionsCallbacks();
    }, onError: (e) {
      if (kDebugMode) debugPrint('❌ Erreur stream sessions: $e');
    });
    _activeSubscriptions.add(sub);
  }

  // Getters publics équivalents
  static Map<String, dynamic>? get currentProfile => _currentProfile;
  static List<String> get currentFavorites => List.unmodifiable(_currentFavorites);
  static List<Map<String, dynamic>> get currentBadges => List.unmodifiable(_currentBadges);
  static List<Map<String, dynamic>> get currentMissionProgress => List.unmodifiable(_currentMissionProgress);
  static List<Map<String, dynamic>> get currentSessions => List.unmodifiable(_currentSessions);

  static int get currentLives => _currentProfile?['vie']?['vieRestante'] ?? 5;
  static int get maxLives => _currentProfile?['vie']?['vieMaximum'] ?? 5;
  // (Supprimé) biomesDeverrouilles: non utilisé désormais
  static List<String> get unlockedBiomes => const <String>[];
  static String get currentBiome => _currentProfile?['biomeActuel'] ?? 'milieu urbain';

  static Stream<Map<String, dynamic>?> get profileStream => _profileStream ?? Stream.empty();
  static Stream<List<String>> get favoritesStream => _favoritesStream ?? Stream.empty();
  static Stream<List<Map<String, dynamic>>> get badgesStream => _badgesStream ?? Stream.empty();
  static Stream<List<Map<String, dynamic>>> get missionProgressStream => _missionProgressStream ?? Stream.empty();
  static Stream<List<Map<String, dynamic>>> get sessionsStream => _sessionsStream ?? Stream.empty();

  // === Premium ===
  static bool get isPremium => _currentProfile?['profil']?['estPremium'] == true;
  static Stream<bool> get isPremiumStream => (_profileStream ?? const Stream<Map<String, dynamic>?>.empty())
      .map((p) => (p?['profil']?['estPremium'] == true));

  // Callbacks
  static void addProfileCallback(Function() cb) => _profileCallbacks.add(cb);
  static void removeProfileCallback(Function() cb) => _profileCallbacks.remove(cb);
  static void addFavoritesCallback(Function() cb) => _favoritesCallbacks.add(cb);
  static void removeFavoritesCallback(Function() cb) => _favoritesCallbacks.remove(cb);
  static void addBadgesCallback(Function() cb) => _badgesCallbacks.add(cb);
  static void removeBadgesCallback(Function() cb) => _badgesCallbacks.remove(cb);
  static void addMissionProgressCallback(Function() cb) => _missionProgressCallbacks.add(cb);
  static void removeMissionProgressCallback(Function() cb) => _missionProgressCallbacks.remove(cb);
  static void addSessionsCallback(Function() cb) => _sessionsCallbacks.add(cb);
  static void removeSessionsCallback(Function() cb) => _sessionsCallbacks.remove(cb);

  static void _notifyProfileCallbacks() {
    for (final cb in _profileCallbacks) {
      try {
        cb();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur callback profil: $e');
      }
    }
  }
  static void _notifyFavoritesCallbacks() {
    for (final cb in _favoritesCallbacks) {
      try {
        cb();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur callback favoris: $e');
      }
    }
  }
  static void _notifyBadgesCallbacks() {
    for (final cb in _badgesCallbacks) {
      try {
        cb();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur callback badges: $e');
      }
    }
  }
  static void _notifyMissionProgressCallbacks() {
    for (final cb in _missionProgressCallbacks) {
      try {
        cb();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur callback progression: $e');
      }
    }
  }
  static void _notifySessionsCallbacks() {
    for (final cb in _sessionsCallbacks) {
      try {
        cb();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur callback sessions: $e');
      }
    }
  }

  // Utilitaires
  static bool get isSyncing => _activeSubscriptions.isNotEmpty;
  static int get activeStreamsCount => _activeSubscriptions.length;
  static Future<void> forceSync() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (kDebugMode) debugPrint('🔄 Synchronisation forcée...');
    try {
      final profile = await UserProfileService.getUserProfile(user.uid);
      _currentProfile = profile;
      final favorites = await UserProfileService.getFavorites(user.uid);
      _currentFavorites = favorites;
      final badges = await UserProfileService.getBadges(user.uid);
      _currentBadges = badges;
      _notifyProfileCallbacks();
      _notifyFavoritesCallbacks();
      _notifyBadgesCallbacks();
      if (kDebugMode) debugPrint('✅ Synchronisation forcée terminée');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation forcée: $e');
    }
  }

  /// Réinitialise le schéma utilisateur (sans toucher aux sous-collections
  /// `sessions` et `progression_missions`). Supprime l'ancienne sous-collection
  /// `vie` si elle existe, et remet les champs root au format attendu.
  static Future<void> _resetSchemaIfNeeded(String uid) async {
    try {
      final rootRef = FirebaseFirestore.instance.collection('utilisateurs').doc(uid);
      final snap = await rootRef.get();
      final data = snap.data() ?? {};

      // Critère de reset: absence des clés structurantes nouvelles
      final bool needsReset = !(data.containsKey('profil') && data.containsKey('parametres') && data.containsKey('vie'));

      if (!needsReset) {
        // Même si pas de reset global, supprimer un éventuel 'creeLe' racine résiduel
        if (data.containsKey('creeLe')) {
          await rootRef.set({'creeLe': FieldValue.delete()}, SetOptions(merge: true));
        }
        return;
      }

      if (kDebugMode) debugPrint('🧹 Réinitialisation du schéma utilisateur (hors sessions/progression)');

      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day + 1);

      // Supprimer sous-collection vie/etat si elle existe
      try {
        final lifeCol = rootRef.collection('vie');
        final lifeDocs = await lifeCol.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in lifeDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (_) {}

      // Réécrire le document avec la structure cible
      await rootRef.set({
        'creeLe': FieldValue.delete(), // au cas où un autre passage le recrée
        'profil': {
          'email': data['profil']?['email'],
          'nomAffichage': data['profil']?['nomAffichage'],
          'estPremium': data['profil']?['estPremium'] ?? false,
          'derniereConnexion': FieldValue.serverTimestamp(),
        },
        'parametres': {
          'langue': (data['parametres']?['langue'] ?? 'fr'),
          'notifications': (data['parametres']?['notifications'] ?? true),
          'son': (data['parametres']?['son'] ?? true),
          'theme': data['parametres']?['theme'],
        },
        'biomesDeverrouilles': (data['biomesDeverrouilles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            (data['biomesUnlocked'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            ['milieu urbain'],
        'serie': {
          'derniersJoursActifs': (data['serie']?['derniersJoursActifs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
          'serieEnCours': (data['serie']?['serieEnCours'] as int?) ?? 0,
          'serieMaximum': (data['serie']?['serieMaximum'] as int?) ?? 0,
        },
        'vie': {
          'vieRestante': (data['vie']?['vieRestante'] as int?
                ?? data['vie']?['Vie restante'] as int?
                ?? data['Vie restante'] as int?
                ?? data['livesRemaining'] as int?
                ?? 5)
              .clamp(0, 5),
          'prochaineRecharge': data['vie']?['prochaineRecharge'] ?? nextMidnight,
          'vieMaximum': (data['vie']?['vieMaximum'] as int? ?? data['vies']?['max'] as int? ?? 5).clamp(1, 10),
        },
        // Supprimer d'éventuels doublons dottés à la racine
        'vie.vieRestante': FieldValue.delete(),
        'vie.vieMaximum': FieldValue.delete(),
        'vie.prochaineRecharge': FieldValue.delete(),
        'lastUpdated': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ _resetSchemaIfNeeded erreur: $e');
    }
  }
}


