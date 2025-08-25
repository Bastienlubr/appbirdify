import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'pages/home_screen.dart';
import 'services/Users/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Forcer l'orientation en mode portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialisation Firebase avec gestion d'erreur robuste
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialisé avec succès');
  } catch (e) {
  // App Check (Debug pour tests locaux; passe à PlayIntegrity/DeviceCheck en prod)
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    debugPrint('🛡️ Firebase App Check activé (mode debug)');
  } catch (e) {
    debugPrint('⚠️ App Check non activé: $e');
  }
    debugPrint('❌ Erreur lors de l\'initialisation Firebase: $e');
    // En cas d'échec d'initialisation Firebase, on continue quand même
    // pour permettre à l'app de fonctionner en mode hors ligne
  }
  // Démarrer l'écouteur d'auth pour synchroniser automatiquement le profil utilisateur
  await AuthService.startAuthSync();
  
  // (Supprimé) Initialisation du scan d'images locales au démarrage
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF386641)),
        fontFamily: 'Quicksand',
      ),
      home: const HomeScreen(),
    );
  }
}
