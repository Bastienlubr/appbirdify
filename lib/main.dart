import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'services/ads/ad_service.dart';
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
import 'pages/Abonnement/bienvenue_abonnement_page.dart';
import 'services/outils_developpement/auto_lock_service.dart';
import 'data/bird_image_alignments.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Handlers globaux d'erreurs au plus tôt (supprimés)
  // IMPORTANT: garder ensureInitialized dans la même zone que runApp (zone par défaut)
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
    debugPrint('❌ Erreur lors de l\'initialisation Firebase: $e');
  }
  // App Check (Debug pour tests locaux; passe à PlayIntegrity/DeviceCheck en prod)
  try {
    final androidProv = kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug;
    final appleProv = kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug;
    await FirebaseAppCheck.instance.activate(
      androidProvider: androidProv,
      appleProvider: appleProv,
    );
    try {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (_) {}
    debugPrint('🛡️ Firebase App Check activé (android=$androidProv, apple=$appleProv)');
  } catch (e) {
    debugPrint('⚠️ App Check non activé: $e');
  }

  // Langue FR pour Firebase Auth (utile pour e-mails/sms)
  try {
    await FirebaseAuth.instance.setLanguageCode('fr');
  } catch (e) {
    debugPrint('⚠️ Langue Auth non définie: $e');
  }

  // Initialisation Google Mobile Ads (mobile uniquement) + préchargement Rewarded
  if (!kIsWeb) {
    try {
      final InitializationStatus status = await MobileAds.instance.initialize();
      debugPrint('📢 Google Mobile Ads initialisé: ${status.adapterStatuses.keys.join(', ')}');
      // Précharger une Rewarded au démarrage
      // ignore: unawaited_futures
      AdService.instance.preloadRewarded();
    } catch (e) {
      debugPrint('⚠️ Mobile Ads non initialisé: $e');
    }
  }

  // Démarrer l'écouteur d'auth pour synchroniser automatiquement le profil utilisateur
  await AuthService.startAuthSync();

  // Charger les cadrages sauvegardés AVANT de rendre l'UI
  try {
    // Charger seulement les alignements locaux (les défauts sont en code)
    await BirdImageAlignments.loadSavedAlignments();
    debugPrint('🎯 Alignements d\'images chargés');
  } catch (e) {
    debugPrint('⚠️ Alignements non chargés: $e');
  }

  // Log de boot rapide (supprimé)

  // Démarrage de l'app
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
        '/abonnement/gerer': (context) => GererMonAbonnementPage(titleHorizontalOffset: 8),
        '/abonnement/bienvenue': (context) => const EnvolWelcomePage(),
        // route '/abonnement/annulation-motif' supprimée
      },
    ).withAutoLock();
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
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Boot premium-aware: lire l'abonnement courant AVANT d'afficher l'UI
          final currentRef = FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(user.uid)
              .collection('abonnement')
              .doc('current');
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: currentRef.get(),
            builder: (context, aboSnap) {
              if (!aboSnap.hasData) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final m = aboSnap.data?.data() ?? <String, dynamic>{};
              final String etat = (m['etat'] as String?) ?? '';
              final String phase = (m['phase'] as String?) ?? '';
              final bool accesAutorise = m['accesAutorise'] == true || etat == 'ACTIVE';
              // Mettre en cohérence profil/vie pour affichage immédiat
              try {
                FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).set({
                  'profil': {'estPremium': accesAutorise},
                  'vie': {'livesInfinite': accesAutorise},
                }, SetOptions(merge: true));
              } catch (_) {}

              // Toujours afficher la Home au démarrage; la page de bienvenue n'apparaît que juste après l'achat (flux paywall)
              return const HomeScreen();
            },
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const RegisterScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
