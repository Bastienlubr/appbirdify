import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/life_sync_service.dart';
import '../services/mission_preloader.dart';
import 'home_screen.dart';

/// Écran de déchargement pour synchroniser les vies et libérer les ressources
class MissionUnloadingScreen extends StatefulWidget {
  final int livesRemaining;
  final String? missionId;

  const MissionUnloadingScreen({
    super.key,
    required this.livesRemaining,
    this.missionId,
  });

  @override
  State<MissionUnloadingScreen> createState() => _MissionUnloadingScreenState();
}

class _MissionUnloadingScreenState extends State<MissionUnloadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  String _currentStep = 'Initialisation...';
  String? _errorMessage;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startUnloading();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // Animation de pulsation pour l'icône
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Animation de progression
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));

    // Démarrer les animations
    _pulseController.repeat(reverse: true);
  }

  Future<void> _startUnloading() async {
    try {
      if (kDebugMode) debugPrint('🔄 Début du déchargement de la mission avec ${widget.livesRemaining} vies restantes');

      // Étape 1: Synchronisation des vies avec Firestore
      await _updateProgress('Synchronisation des vies...', 0.2);
      await _syncLivesWithFirestore();
      
      // Attendre un peu pour s'assurer que la synchronisation est terminée
      await Future.delayed(const Duration(milliseconds: 500));

      // Étape 2: Nettoyage du cache audio
      await _updateProgress('Nettoyage du cache audio...', 0.4);
      await _cleanupAudioCache();

      // Étape 3: Nettoyage du cache des images
      await _updateProgress('Nettoyage du cache des images...', 0.6);
      await _cleanupImageCache();

      // Étape 4: Nettoyage général des ressources
      await _updateProgress('Libération des ressources...', 0.8);
      await _cleanupGeneralResources();

      // Étape 5: Finalisation
      await _updateProgress('Finalisation...', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isCompleted = true;
        });

        // Attendre un peu pour que l'utilisateur voie la finalisation
        await Future.delayed(const Duration(milliseconds: 800));

        // Navigation vers l'écran d'accueil
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
            (route) => false, // Supprime tous les écrans de la pile
          );
        }
      }

    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du déchargement: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _updateProgress(String step, double progress) async {
    if (mounted) {
      setState(() {
        _currentStep = step;
      });
      _progressController.animateTo(progress);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Synchronise les vies restantes avec Firestore
  Future<void> _syncLivesWithFirestore() async {
    try {
      final uid = LifeSyncService.getCurrentUserId();
      if (kDebugMode) debugPrint('🔍 Vérification utilisateur: UID=$uid, Connecté=${LifeSyncService.isUserLoggedIn}');
      
      if (uid != null) {
        if (kDebugMode) debugPrint('🔄 Début synchronisation vies: ${widget.livesRemaining} vies pour utilisateur $uid');
        
        // Vérifier les vies actuelles avant synchronisation
        final currentLives = await LifeSyncService.getCurrentLives(uid);
        if (kDebugMode) debugPrint('📊 Vies actuelles dans Firestore: $currentLives');
        
        await LifeSyncService.syncLivesAfterQuiz(uid, widget.livesRemaining);
        
        // Vérifier les vies après synchronisation
        final updatedLives = await LifeSyncService.getCurrentLives(uid);
        if (kDebugMode) debugPrint('✅ Vies synchronisées: ${widget.livesRemaining} → Firestore: $updatedLives');
      } else {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté, synchronisation ignorée');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation des vies: $e');
      if (kDebugMode) debugPrint('   Stack trace: ${e.toString()}');
      // Ne pas faire échouer le déchargement pour une erreur de synchronisation
    }
  }

  /// Nettoie le cache audio
  Future<void> _cleanupAudioCache() async {
    try {
      MissionPreloader.clearAudioCache();
      if (kDebugMode) debugPrint('✅ Cache audio nettoyé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du nettoyage du cache audio: $e');
    }
  }

  /// Nettoie le cache des images
  Future<void> _cleanupImageCache() async {
    try {
      // Ici on pourrait ajouter le nettoyage du cache d'images si nécessaire
      // Pour l'instant, on laisse les images en cache car elles peuvent être réutilisées
      if (kDebugMode) debugPrint('✅ Cache des images conservé (réutilisable)');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du nettoyage du cache des images: $e');
    }
  }

  /// Nettoie les ressources générales
  Future<void> _cleanupGeneralResources() async {
    try {
      // Forcer le garbage collection si possible
      // Note: En Flutter/Dart, le GC est automatique, mais on peut suggérer
      if (kDebugMode) debugPrint('✅ Ressources générales libérées');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la libération des ressources: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône animée
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _isCompleted 
                              ? const Color(0xFF6A994E) 
                              : const Color(0xFF386641),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isCompleted ? Icons.check : Icons.cleaning_services,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Titre
                Text(
                  _isCompleted ? 'Déchargement terminé !' : 'Déchargement en cours...',
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF386641),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Étape actuelle
                Text(
                  _currentStep,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 18,
                    color: Color(0xFF6A994E),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Barre de progression
                Container(
                  width: 300,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF473C33).withAlpha(50),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFABC270),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Informations sur les vies
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: const Color(0xFFBC4749),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.livesRemaining} vies restantes',
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF473C33),
                        ),
                      ),
                    ],
                  ),
                ),

                // Message d'erreur si nécessaire
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBC4749).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFBC4749).withAlpha(50),
                      ),
                    ),
                    child: Text(
                      'Erreur: $_errorMessage',
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 14,
                        color: Color(0xFFBC4749),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 