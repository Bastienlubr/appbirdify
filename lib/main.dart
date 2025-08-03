import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/home_screen.dart';
import 'pages/auth/login_screen.dart';
import 'services/local_image_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation Firebase avec gestion d'erreur robuste
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialisé avec succès');
  } catch (e) {
    debugPrint('❌ Erreur lors de l\'initialisation Firebase: $e');
    // En cas d'échec d'initialisation Firebase, on continue quand même
    // pour permettre à l'app de fonctionner en mode hors ligne
  }
  
  // Initialisation des services de préchargement
  try {
    await LocalImageService().initialize();
    debugPrint('✅ Services de préchargement initialisés avec succès');
  } catch (e) {
    debugPrint('❌ Erreur lors de l\'initialisation des services de préchargement: $e');
    // En cas d'échec, on continue quand même
  }
  
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
        textTheme: GoogleFonts.quicksandTextTheme(),
        fontFamily: 'Quicksand',
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginScreen()
          : const HomeScreen(),
    );
  }
}
