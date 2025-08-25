import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'user_orchestra_service.dart';

/// Service d'authentification pour gérer la vérification continue de la connexion Firebase
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Abonnement persistant aux changements d'authentification
  static StreamSubscription<User?>? _authSubscription;

  /// Stream des changements d'état d'authentification
  /// 
  /// Ce stream émet un User? :
  /// - User : Utilisateur connecté
  /// - null : Utilisateur déconnecté
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuel (peut être null si déconnecté)
  static User? get currentUser => _auth.currentUser;

  /// Vérifie si un utilisateur est connecté
  static bool get isUserLoggedIn => currentUser != null;

  /// Déconnecte l'utilisateur actuel
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) debugPrint('✅ Utilisateur déconnecté avec succès');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }

  /// Démarre un écouteur global pour synchroniser le profil/sessions dès qu'un utilisateur se connecte
  /// - Au login/inscription: lance UserSyncService.startSync()
  /// - À la déconnexion: lance UserSyncService.stopSync()
  static Future<void> startAuthSync() async {
    // Éviter les doublons d'écouteurs
    await _authSubscription?.cancel();

    if (kDebugMode) debugPrint('🔊 Activation du listener d\'authentification');
    _authSubscription = _auth.authStateChanges().listen((user) async {
      try {
        if (user != null) {
          if (kDebugMode) debugPrint('👤 Connecté: ${user.uid} → démarrage UserOrchestra');
          await UserOrchestra.startForCurrentUser();
        } else {
          if (kDebugMode) debugPrint('🚪 Déconnecté → arrêt de la synchronisation utilisateur');
          UserOrchestra.stop();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur dans le listener d\'auth: $e');
      }
    });

    // Démarrage immédiat au cas où un utilisateur est déjà connecté
    final current = _auth.currentUser;
    if (current != null) {
      try {
        if (kDebugMode) debugPrint('⚡ Démarrage immédiat UserOrchestra (utilisateur déjà connecté: ${current.uid})');
        await UserOrchestra.startForCurrentUser();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur lors du démarrage immédiat: $e');
      }
    }
  }

  /// Arrête le listener global d'authentification (à appeler si nécessaire au dispose global)
  static Future<void> stopAuthSync() async {
    if (kDebugMode) debugPrint('🛑 Désactivation du listener d\'authentification');
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  /// Obtient l'ID de l'utilisateur actuel
  static String? get currentUserId => currentUser?.uid;

  /// Obtient l'email de l'utilisateur actuel
  static String? get currentUserEmail => currentUser?.email;

  /// Vérifie si l'utilisateur est connecté de manière anonyme
  static bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// Écoute les changements d'état d'authentification avec un callback
  /// 
  /// [onAuthStateChanged] : Callback appelé à chaque changement d'état
  /// Retourne un StreamSubscription pour pouvoir annuler l'écoute
  static Stream<User?> listenToAuthChanges() {
    return authStateChanges;
  }

  /// Vérifie si l'utilisateur a un email vérifié
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Envoie un email de vérification
  static Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
      if (kDebugMode) debugPrint('✅ Email de vérification envoyé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de l\'envoi de l\'email de vérification: $e');
      rethrow;
    }
  }

  /// Supprime le compte utilisateur actuel
  static Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
      if (kDebugMode) debugPrint('✅ Compte utilisateur supprimé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la suppression du compte: $e');
      rethrow;
    }
  }

  /// Met à jour le mot de passe de l'utilisateur
  static Future<void> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
      if (kDebugMode) debugPrint('✅ Mot de passe mis à jour');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la mise à jour du mot de passe: $e');
      rethrow;
    }
  }

  /// Met à jour l'email de l'utilisateur
  static Future<void> updateEmail(String newEmail) async {
    try {
      await currentUser?.verifyBeforeUpdateEmail(newEmail);
      if (kDebugMode) debugPrint('✅ Email de vérification envoyé pour mise à jour');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la mise à jour de l\'email: $e');
      rethrow;
    }
  }

  /// Obtient les informations du profil utilisateur
  static Map<String, dynamic>? get userProfile {
    final user = currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }

  /// Vérifie si l'utilisateur a été créé récemment (dans les dernières 24h)
  static bool get isNewUser {
    final user = currentUser;
    if (user == null) return false;

    final creationTime = user.metadata.creationTime;
    if (creationTime == null) return false;

    final now = DateTime.now();
    final difference = now.difference(creationTime);
    
    return difference.inHours < 24;
  }

  /// Obtient le temps écoulé depuis la dernière connexion
  static Duration? get timeSinceLastSignIn {
    final user = currentUser;
    if (user == null) return null;

    final lastSignInTime = user.metadata.lastSignInTime;
    if (lastSignInTime == null) return null;

    final now = DateTime.now();
    return now.difference(lastSignInTime);
  }




} 