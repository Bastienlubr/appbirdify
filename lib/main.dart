import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/home_screen.dart';
import 'pages/auth/login_screen.dart';
import 'pages/auth/register_screen.dart';
// import 'pages/auth/questionnaire_screen.dart'; // Unused
import 'services/Users/auth_service.dart';
import 'pages/Abonnement/information_abonnement_page.dart';
import 'pages/Abonnement/choix_offre_page.dart';
import 'pages/Abonnement/gerer_mon_abonnement_page.dart';

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
      home: const RootDecider(),
      routes: {
        '/abonnement/information': (context) => const InformationAbonnementPage(),
        '/abonnement/choix-offre': (context) => const ChoixOffrePage(),
        '/abonnement/gerer': (context) => GererMonAbonnementPage(titleHorizontalOffset: 10),
      },
    );
  }
}

class RootDecider extends StatelessWidget {
  const RootDecider({super.key});

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool('firstLaunchDone') ?? false;
    if (!hasLaunched) {
      await prefs.setBool('firstLaunchDone', true);
      return true; // C'est le premier lancement
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFirstLaunch(),
      builder: (context, snapshot) {
        // Si un utilisateur est déjà connecté → Home directement
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          return const HomeScreen();
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Premier lancement : aller à l'inscription directement
        if (snapshot.data == true) {
          return const RegisterScreen();
        }

        // Sinon, écran de connexion
        return const LoginScreen();
      },
    );
  }
}
