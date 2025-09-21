import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform, TargetPlatform, debugPrint, kIsWeb;
import 'user_orchestra_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart' show ActionCodeSettings; // Unnecessary, already imported above

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===== State & listeners ===================================================
  static StreamSubscription<User?>? _authSubscription;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  static Future<void> startAuthSync() async {
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
        if (kDebugMode) debugPrint('❌ Erreur listener auth: $e');
      }
    });
    final current = _auth.currentUser;
    if (current != null) {
      try {
        if (kDebugMode) debugPrint('⚡ Démarrage immédiat UserOrchestra (utilisateur déjà connecté: ${current.uid})');
        await UserOrchestra.startForCurrentUser();
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur démarrage immédiat: $e');
      }
    }
  }

  static Future<void> stopAuthSync() async {
    if (kDebugMode) debugPrint('🛑 Désactivation du listener d\'authentification');
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  // ===== Email/password ======================================================
  static Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<UserCredential> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _db.collection('utilisateurs').doc(cred.user!.uid).set({
      'profil': {
        'email': email,
        'nomAffichage': email.split('@').first,
      }
    }, SetOptions(merge: true));
    return cred;
  }

  // ===== Google ==============================================================
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: utiliser directement FirebaseAuth avec popup
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({ 'prompt': 'select_account' });
        final res = await _auth.signInWithPopup(provider);
        await _db.collection('utilisateurs').doc(res.user!.uid).set({
          'profil': {
            'email': res.user!.email,
            'nomAffichage': res.user!.displayName ?? res.user!.email?.split('@').first,
          }
        }, SetOptions(merge: true));
        return res;
      }

      // Mobile/Desktop natif: GoogleSignIn SDK
      final g = GoogleSignIn();
      try { await g.disconnect(); } catch (_) {}
      try { await g.signOut(); } catch (_) {}
      final googleUser = await g.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final res = await _auth.signInWithCredential(cred);
      await _db.collection('utilisateurs').doc(res.user!.uid).set({
        'profil': {
          'email': res.user!.email,
          'nomAffichage': res.user!.displayName ?? res.user!.email?.split('@').first,
        }
      }, SetOptions(merge: true));
      return res;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Google Sign-In a échoué: $e');
      return null;
    }
  }

  // ===== Apple ===============================================================
  static Future<UserCredential?> signInWithApple() async {
    try {
      if (!(defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) return null;
      final appleCredential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);
      final oauth = OAuthProvider('apple.com').credential(idToken: appleCredential.identityToken, accessToken: appleCredential.authorizationCode);
      final res = await _auth.signInWithCredential(oauth);
      await _db.collection('utilisateurs').doc(res.user!.uid).set({
        'profil': {
          'email': res.user!.email,
          'nomAffichage': res.user!.displayName ?? res.user!.email?.split('@').first,
        }
      }, SetOptions(merge: true));
      return res;
    } catch (_) { return null; }
  }

  // ===== Email lien magique ==================================================
  static Future<bool> sendEmailSignInLink({required String email, required String continueUrl}) async {
    try {
      final settings = ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: true,
        androidPackageName: 'com.example.appbirdify',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.example.appbirdify',
      );
      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: settings);
      return true;
    } catch (_) { return false; }
  }

  static Future<UserCredential?> completeEmailLinkSignIn({required String email, required String link}) async {
    try {
      if (!_auth.isSignInWithEmailLink(link)) return null;
      final cred = await _auth.signInWithEmailLink(email: email, emailLink: link);
      await _db.collection('utilisateurs').doc(cred.user!.uid).set({
        'profil': {
          'email': cred.user!.email,
          'nomAffichage': cred.user!.displayName ?? cred.user!.email?.split('@').first,
        }
      }, SetOptions(merge: true));
      return cred;
    } catch (_) { return null; }
  }

  // ===== Sign out ============================================================
  static Future<void> signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

  // ===== Reauth ==============================================================
  static Future<bool> reauthWithPassword(String email, String password) async {
    try {
      final cred = EmailAuthProvider.credential(email: email, password: password);
      await _auth.currentUser!.reauthenticateWithCredential(cred);
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> reauthWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      await _auth.currentUser!.reauthenticateWithCredential(cred);
      return true;
    } catch (_) { return false; }
  }

  // ===== Updates =============================================================
  static Future<bool> updateDisplayName(String name) async {
    try {
      final u = _auth.currentUser;
      if (u == null) return false;
      await u.updateDisplayName(name);
      await _db.collection('utilisateurs').doc(u.uid).set({'profil': {'nomAffichage': name}}, SetOptions(merge: true));
      return true;
    } catch (_) { return false; }
  }

  // ===== Phone Auth ==========================================================
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Échec de vérification');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (onAutoRetrievalTimeout != null) onAutoRetrievalTimeout();
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  static Future<UserCredential?> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final res = await _auth.signInWithCredential(cred);
      await _db.collection('utilisateurs').doc(res.user!.uid).set({
        'profil': {
          'phone': res.user!.phoneNumber,
          'nomAffichage': res.user!.displayName ?? res.user!.phoneNumber,
        }
      }, SetOptions(merge: true));
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateEmail(String newEmail) async {
    try {
      final u = _auth.currentUser;
      if (u == null) return false;
      await u.verifyBeforeUpdateEmail(
        newEmail,
        ActionCodeSettings(
          url: 'https://appbirdify.page.link/update-email',
          handleCodeInApp: true,
          androidPackageName: 'com.mindbird.appbirdify',
          androidInstallApp: true,
          androidMinimumVersion: '21',
          iOSBundleId: 'com.mindbird.appbirdify',
        ),
      );
      // L'email Firebase sera mis à jour après vérification par l'utilisateur.
      // Nous n'écrivons pas immédiatement dans Firestore pour éviter les incohérences.
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return false;
      return false;
    } catch (_) { return false; }
  }

  static Future<bool> updatePassword(String currentPassword, String newPassword) async {
    try {
      final u = _auth.currentUser;
      if (u == null || u.email == null) return false;
      final cred = EmailAuthProvider.credential(email: u.email!, password: currentPassword);
      await u.reauthenticateWithCredential(cred);
      await u.updatePassword(newPassword);
      return true;
    } catch (_) { return false; }
  }
}