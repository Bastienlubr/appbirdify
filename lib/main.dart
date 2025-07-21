import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/home_screen.dart';
import 'pages/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation Firebase avec gestion d'erreur
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // print("✅ Firebase connecté avec succès");
  } catch (e) {
    // print("❌ Erreur Firebase init: $e");
    return; // Arrêter l'exécution si Firebase ne peut pas s'initialiser
  }
  
  // Test de connexion Firestore
  try {
    await FirebaseFirestore.instance.collection('debug').doc('test').get();
    // print('✅ Connexion Firestore réussie !');
  } catch (e) {
    // print('❌ Erreur de connexion Firestore: $e');
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
