import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'user_profile_service.dart';

/// Service de synchronisation en temps réel pour toutes les données utilisateur
/// Permet d'écouter les changements et de maintenir l'état à jour
class UserSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Streams de données en temps réel
  static Stream<Map<String, dynamic>?>? _profileStream;
  static Stream<List<String>>? _favoritesStream;
  static Stream<List<Map<String, dynamic>>>? _badgesStream;
  static Stream<List<Map<String, dynamic>>>? _missionProgressStream;
  static Stream<List<Map<String, dynamic>>>? _sessionsStream;
  
  // État actuel des données
  static Map<String, dynamic>? _currentProfile;
  static List<String> _currentFavorites = [];
  static List<Map<String, dynamic>> _currentBadges = [];
  static List<Map<String, dynamic>> _currentMissionProgress = [];
  static List<Map<String, dynamic>> _currentSessions = [];
  
  // Listeners actifs
  static final List<StreamSubscription<dynamic>> _activeSubscriptions = [];
  
  // Callbacks pour notifier les widgets
  static final List<Function()> _profileCallbacks = [];
  static final List<Function()> _favoritesCallbacks = [];
  static final List<Function()> _badgesCallbacks = [];
  static final List<Function()> _missionProgressCallbacks = [];
  static final List<Function()> _sessionsCallbacks = [];

  // === INITIALISATION ET DÉMARRAGE ===
  
  /// Démarre la synchronisation pour l'utilisateur actuel
  static Future<void> startSync() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté, synchronisation impossible');
      return;
    }
    
    if (kDebugMode) debugPrint('🔄 Démarrage de la synchronisation pour ${user.uid}');
    
    try {
      // Créer le profil s'il n'existe pas
      await UserProfileService.createOrUpdateUserProfile(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
      );
      
      // Démarrer tous les streams
      await _startProfileStream(user.uid);
      await _startFavoritesStream(user.uid);
      await _startBadgesStream(user.uid);
      await _startMissionProgressStream(user.uid);
      await _startSessionsStream(user.uid);
      
      // Mettre à jour la dernière connexion
      await UserProfileService.updateLastLogin(user.uid);
      
      if (kDebugMode) debugPrint('✅ Synchronisation démarrée avec succès');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du démarrage de la synchronisation: $e');
      rethrow;
    }
  }
  
  /// Arrête la synchronisation et ferme tous les streams
  static void stopSync() {
    if (kDebugMode) debugPrint('🛑 Arrêt de la synchronisation');
    
    // Fermer tous les streams actifs
    for (final subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    
    // Réinitialiser les streams
    _profileStream = null;
    _favoritesStream = null;
    _badgesStream = null;
    _missionProgressStream = null;
    _sessionsStream = null;
    
    // Vider les callbacks
    _profileCallbacks.clear();
    _favoritesCallbacks.clear();
    _badgesCallbacks.clear();
    _missionProgressCallbacks.clear();
    _sessionsCallbacks.clear();
    
    if (kDebugMode) debugPrint('✅ Synchronisation arrêtée');
  }

  // === STREAMS DE DONNÉES ===
  
  /// Démarre le stream du profil utilisateur
  static Future<void> _startProfileStream(String uid) async {
    _profileStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
    
    final subscription = _profileStream!.listen(
      (profile) {
        _currentProfile = profile;
        if (kDebugMode) debugPrint('📊 Profil mis à jour: ${profile?['profil']?['nomAffichage']}');
        _notifyProfileCallbacks();
      },
      onError: (error) {
        if (kDebugMode) debugPrint('❌ Erreur stream profil: $error');
      },
    );
    
    _activeSubscriptions.add(subscription);
  }
  
  /// Démarre le stream des favoris
  static Future<void> _startFavoritesStream(String uid) async {
    _favoritesStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('favoris')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
    
    final subscription = _favoritesStream!.listen(
      (favorites) {
        _currentFavorites = favorites;
        if (kDebugMode) debugPrint('❤️ Favoris mis à jour: ${favorites.length} oiseaux');
        _notifyFavoritesCallbacks();
      },
      onError: (error) {
        if (kDebugMode) debugPrint('❌ Erreur stream favoris: $error');
      },
    );
    
    _activeSubscriptions.add(subscription);
  }
  
  /// Démarre le stream des badges
  static Future<void> _startBadgesStream(String uid) async {
    _badgesStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('badges')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    
    final subscription = _badgesStream!.listen(
      (badges) {
        _currentBadges = badges;
        if (kDebugMode) debugPrint('🏆 Badges mis à jour: ${badges.length} badges');
        _notifyBadgesCallbacks();
      },
      onError: (error) {
        if (kDebugMode) debugPrint('❌ Erreur stream badges: $error');
      },
    );
    
    _activeSubscriptions.add(subscription);
  }
  
  /// Démarre le stream de la progression des missions
  static Future<void> _startMissionProgressStream(String uid) async {
    _missionProgressStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('progression_missions')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    
    final subscription = _missionProgressStream!.listen(
      (progress) {
        _currentMissionProgress = progress;
        if (kDebugMode) debugPrint('🎯 Progression missions mise à jour: ${progress.length} missions');
        _notifyMissionProgressCallbacks();
      },
      onError: (error) {
        if (kDebugMode) debugPrint('❌ Erreur stream progression: $error');
      },
    );
    
    _activeSubscriptions.add(subscription);
  }
  
  /// Démarre le stream des sessions
  static Future<void> _startSessionsStream(String uid) async {
    _sessionsStream = _firestore
        .collection('utilisateurs')
        .doc(uid)
        .collection('sessions')
        .orderBy('termineLe', descending: true)
        .limit(50) // Limiter à 50 dernières sessions
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    
    final subscription = _sessionsStream!.listen(
      (sessions) {
        _currentSessions = sessions;
        if (kDebugMode) debugPrint('📊 Sessions mises à jour: ${sessions.length} sessions');
        _notifySessionsCallbacks();
      },
      onError: (error) {
        if (kDebugMode) debugPrint('❌ Erreur stream sessions: $error');
      },
    );
    
    _activeSubscriptions.add(subscription);
  }

  // === ACCÈS AUX DONNÉES ACTUELLES ===
  
  /// Obtient le profil actuel (peut être null si pas encore chargé)
  static Map<String, dynamic>? get currentProfile => _currentProfile;
  
  /// Obtient la liste des favoris actuels
  static List<String> get currentFavorites => List.unmodifiable(_currentFavorites);
  
  /// Obtient la liste des badges actuels
  static List<Map<String, dynamic>> get currentBadges => List.unmodifiable(_currentBadges);
  
  /// Obtient la progression des missions actuelle
  static List<Map<String, dynamic>> get currentMissionProgress => List.unmodifiable(_currentMissionProgress);
  
  /// Obtient les sessions actuelles
  static List<Map<String, dynamic>> get currentSessions => List.unmodifiable(_currentSessions);
  
  /// Vérifie si un oiseau est dans les favoris
  static bool isFavorite(String oiseauId) {
    return _currentFavorites.contains(oiseauId);
  }
  
  /// Obtient la progression d'une mission spécifique
  static Map<String, dynamic>? getMissionProgress(String missionId) {
    try {
      return _currentMissionProgress.firstWhere(
        (progress) => progress['idMission'] == missionId,
        orElse: () => {},
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Obtient le niveau actuel de l'utilisateur
  static int get currentLevel => _currentProfile?['totaux']?['niveau'] ?? 1;
  
  /// Obtient l'XP total actuel
  static int get currentXP => _currentProfile?['totaux']?['xpTotal'] ?? 0;
  
  /// Obtient le score total actuel
  static int get currentTotalScore => _currentProfile?['totaux']?['scoreTotal'] ?? 0;
  
  /// Obtient le nombre de missions terminées
  static int get completedMissionsCount => _currentProfile?['totaux']?['missionsTerminees'] ?? 0;
  
  /// Obtient le nombre de vies restantes
  static int get currentLives => _currentProfile?['vies']?['compte'] ?? 5;
  
  /// Obtient le nombre maximum de vies
  static int get maxLives => _currentProfile?['vies']?['max'] ?? 5;
  
  /// Obtient les biomes débloqués
  static List<String> get unlockedBiomes => 
      List<String>.from(_currentProfile?['biomesUnlocked'] ?? ['milieu urbain']);
  
  /// Obtient le biome actuel
  static String get currentBiome => _currentProfile?['biomeActuel'] ?? 'milieu urbain';

  // === STREAMS PUBLICS ===
  
  /// Stream du profil utilisateur
  static Stream<Map<String, dynamic>?> get profileStream => _profileStream ?? Stream.empty();
  
  /// Stream des favoris
  static Stream<List<String>> get favoritesStream => _favoritesStream ?? Stream.empty();
  
  /// Stream des badges
  static Stream<List<Map<String, dynamic>>> get badgesStream => _badgesStream ?? Stream.empty();
  
  /// Stream de la progression des missions
  static Stream<List<Map<String, dynamic>>> get missionProgressStream => _missionProgressStream ?? Stream.empty();
  
  /// Stream des sessions
  static Stream<List<Map<String, dynamic>>> get sessionsStream => _sessionsStream ?? Stream.empty();

  // === GESTION DES CALLBACKS ===
  
  /// Ajoute un callback pour les changements de profil
  static void addProfileCallback(Function() callback) {
    _profileCallbacks.add(callback);
  }
  
  /// Retire un callback de profil
  static void removeProfileCallback(Function() callback) {
    _profileCallbacks.remove(callback);
  }
  
  /// Ajoute un callback pour les changements de favoris
  static void addFavoritesCallback(Function() callback) {
    _favoritesCallbacks.add(callback);
  }
  
  /// Retire un callback de favoris
  static void removeFavoritesCallback(Function() callback) {
    _favoritesCallbacks.remove(callback);
  }
  
  /// Ajoute un callback pour les changements de badges
  static void addBadgesCallback(Function() callback) {
    _badgesCallbacks.add(callback);
  }
  
  /// Retire un callback de badges
  static void removeBadgesCallback(Function() callback) {
    _badgesCallbacks.remove(callback);
  }
  
  /// Ajoute un callback pour les changements de progression
  static void addMissionProgressCallback(Function() callback) {
    _missionProgressCallbacks.add(callback);
  }
  
  /// Retire un callback de progression
  static void removeMissionProgressCallback(Function() callback) {
    _missionProgressCallbacks.remove(callback);
  }
  
  /// Ajoute un callback pour les changements de sessions
  static void addSessionsCallback(Function() callback) {
    _sessionsCallbacks.add(callback);
  }
  
  /// Retire un callback de sessions
  static void removeSessionsCallback(Function() callback) {
    _sessionsCallbacks.remove(callback);
  }
  
  // === NOTIFICATIONS ===
  
  /// Notifie tous les callbacks de profil
  static void _notifyProfileCallbacks() {
    for (final callback in _profileCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur dans callback profil: $e');
      }
    }
  }
  
  /// Notifie tous les callbacks de favoris
  static void _notifyFavoritesCallbacks() {
    for (final callback in _favoritesCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur dans callback favoris: $e');
      }
    }
  }
  
  /// Notifie tous les callbacks de badges
  static void _notifyBadgesCallbacks() {
    for (final callback in _badgesCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur dans callback badges: $e');
      }
    }
  }
  
  /// Notifie tous les callbacks de progression
  static void _notifyMissionProgressCallbacks() {
    for (final callback in _missionProgressCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur dans callback progression: $e');
      }
    }
  }
  
  /// Notifie tous les callbacks de sessions
  static void _notifySessionsCallbacks() {
    for (final callback in _sessionsCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur dans callback sessions: $e');
      }
    }
  }

  // === UTILITAIRES ===
  
  /// Vérifie si la synchronisation est active
  static bool get isSyncing => _activeSubscriptions.isNotEmpty;
  
  /// Obtient le nombre de streams actifs
  static int get activeStreamsCount => _activeSubscriptions.length;
  
  /// Force la synchronisation de toutes les données
  static Future<void> forceSync() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    if (kDebugMode) debugPrint('🔄 Synchronisation forcée...');
    
    try {
      // Recharger le profil
      final profile = await UserProfileService.getUserProfile(user.uid);
      _currentProfile = profile;
      
      // Recharger les favoris
      final favorites = await UserProfileService.getFavorites(user.uid);
      _currentFavorites = favorites;
      
      // Recharger les badges
      final badges = await UserProfileService.getBadges(user.uid);
      _currentBadges = badges;
      
      // Notifier tous les callbacks
      _notifyProfileCallbacks();
      _notifyFavoritesCallbacks();
      _notifyBadgesCallbacks();
      
      if (kDebugMode) debugPrint('✅ Synchronisation forcée terminée');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation forcée: $e');
    }
  }
}
