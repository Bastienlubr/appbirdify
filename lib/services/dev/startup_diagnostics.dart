import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import '../../firebase_options.dart';

/// Outils de diagnostic et capture d'erreurs au démarrage
class StartupDiagnostics {
  /// Active des handlers globaux pour capturer un maximum d'erreurs dès l'ouverture
  static void initGlobalErrorHandlers() {
    // Erreurs Flutter synchrones (widgets/rendering)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      if (kDebugMode) {
        debugPrint('🔴 FlutterError: ${details.exceptionAsString()}');
      }
    };

    // Erreurs asynchrones non gérées
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('🔴 Uncaught async error: $error');
        debugPrint(stack.toString());
      }
      // true = l'erreur a été gérée (évite crash dans certains cas de debug)
      return true;
    };
  }

  /// Exécute quelques vérifications rapides et loggue un état lisible dans la console
  static Future<void> runOnBoot() async {
    try {
      // Résumé Firebase
      final FirebaseApp? app = Firebase.apps.isNotEmpty ? Firebase.apps.first : null;
      final opts = DefaultFirebaseOptions.currentPlatform;
      if (kDebugMode) {
        debugPrint('🧭 Boot diagnostics:');
        debugPrint('   • Firebase app: ${app?.name ?? 'non initialisée'}');
        debugPrint('   • Firebase projectId: ${opts.projectId}');
      }

      // App Check: tentative douce puis, après délai, tentative "force refresh" pour récupérer un token debug
      String? token;
      try {
        token = await FirebaseAppCheck.instance.getToken(false);
      } catch (_) {}
      if (token == null) {
        // Retenter après un court délai pour éviter Too many attempts
        await Future.delayed(const Duration(seconds: 2));
        try {
          token = await FirebaseAppCheck.instance.getToken(true);
        } catch (e) {
          if (kDebugMode) debugPrint('   • AppCheck token indisponible: $e');
        }
      }
      if (kDebugMode) {
        if (token != null) {
          debugPrint('   • APP_CHECK_DEBUG_TOKEN: $token');
          debugPrint('     👉 Copie ce token dans Firebase Console > App Check > Debug tokens (Android), puis relance.');
        }
      }

      // État utilisateur
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (kDebugMode) {
          debugPrint('   • Utilisateur connecté: ${user != null ? user.uid : 'aucun'}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('   • Lecture utilisateur impossible: $e');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('⚠️ StartupDiagnostics.runOnBoot erreur: $e');
        debugPrint(st.toString());
      }
    }
  }

  /// Exécute une fonction dans une zone protégée pour logguer les erreurs non gérées
  static Future<void> runGuarded(Future<void> Function() body) async {
    return runZonedGuarded(body, (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('🔴 Zone error: $error');
        debugPrint(stack.toString());
      }
    });
  }
}


