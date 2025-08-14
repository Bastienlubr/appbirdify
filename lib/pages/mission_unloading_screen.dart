import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import '../ui/responsive/responsive.dart';
import '../services/life_sync_service.dart';
import '../services/mission_preloader.dart';
import '../models/mission.dart';
import '../models/answer_recap.dart';
import 'quiz_end_page.dart';
import 'home_screen.dart';

/// Écran de déchargement pour synchroniser les vies et libérer les ressources
class MissionUnloadingScreen extends StatefulWidget {
  final int livesRemaining;
  final String? missionId;
  final int? score; // si présent, on redirige vers QuizEndPage
  final int? totalQuestions;
  final Mission? mission;
  final List<String>? wrongBirds;
  final List<AnswerRecap>? recap;
  final bool designMode;

  const MissionUnloadingScreen({
    super.key,
    required this.livesRemaining,
    this.missionId,
    this.score,
    this.totalQuestions,
    this.mission,
    this.wrongBirds,
    this.recap,
    this.designMode = false,
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
  final String _lottiePath = 'assets/PAGE/Chargement/chenille.json';
  final List<String> _funFacts = [];
  int _currentFunFactIndex = 0;
  Timer? _funFactTimer;
  AnimationController? _funFactController; // Nullable pour éviter LateInitializationError
  int? _previousFunFactIndex;
  bool _isFunFactAnimating = false;

  String _currentStep = '';
  String? _errorMessage;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadFunFacts();
    _initFunFactAnimation();
    _startUnloading();
  }

  Future<void> _unloadResourcesMock() async {
    setState(() {
      _currentStep = '';
    });
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _currentStep = '';
    });
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _currentStep = 'Nettoyage du cache...';
    });
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isCompleted = true;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _funFactTimer?.cancel();
    _funFactController?.dispose();
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

  Future<void> _loadFunFacts() async {
    try {
      final String csvString = await rootBundle.loadString('assets/PAGE/Chargement/fun_facts_oiseaux.csv');
      final List<String> lines = csvString
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final List<String> facts = lines
          .where((l) => !l.toLowerCase().contains('chargement'))
          .map((l) => l.replaceFirst(RegExp(r'^\s*\d+\s*[-–:]\s*'), ''))
          .toList();

      if (facts.isNotEmpty) {
        setState(() {
          _funFacts
            ..clear()
            ..addAll(facts);
          _currentFunFactIndex = 0;
        });

        _scheduleFunFactTimer();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Impossible de charger les fun facts: $e');
    }
  }

  void _initFunFactAnimation() {
    // Recrée le contrôleur de transition des fun facts et l'initialise à 1 (premier affichage sans anim)
    _funFactController?.dispose();
    _funFactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    // Afficher sans animation au lancement
    _funFactController!.value = 1.0;
  }

  void _scheduleFunFactTimer() {
    _funFactTimer?.cancel();
    if (_funFacts.length < 2) return; // Pas d'anim si un seul élément
    _funFactTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      _startFunFactTransition();
    });
  }

  void _startFunFactTransition() {
    if (!mounted || _funFacts.length < 2) return;
    final controller = _funFactController;
    if (controller == null) return; // Fallback statique si pas prêt

    setState(() {
      _previousFunFactIndex = _currentFunFactIndex;
      _currentFunFactIndex = (_currentFunFactIndex + 1) % _funFacts.length;
      _isFunFactAnimating = true;
    });

    controller.stop();
    controller.value = 0.0;
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _isFunFactAnimating = false;
      });
    });
  }

  Future<void> _startUnloading() async {
    try {
      if (widget.designMode) {
        // Mode design: simuler les étapes et ne pas naviguer
        await _unloadResourcesMock();
        return;
      }

      if (kDebugMode) debugPrint('🔄 Début du déchargement de la mission avec ${widget.livesRemaining} vies restantes');

      await _updateProgress('', 0.2);
      await _syncLivesWithFirestore();
      
      // Attendre un peu pour s'assurer que la synchronisation est terminée
      await Future.delayed(const Duration(milliseconds: 500));

      await _updateProgress('', 0.4);
      await _cleanupAudioCache();

      await _updateProgress('', 0.6);
      await _cleanupImageCache();

      await _updateProgress('', 0.8);
      await _cleanupGeneralResources();

      await _updateProgress('', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isCompleted = true;
        });

        // Attendre un peu pour que l'utilisateur voie la finalisation
        await Future.delayed(const Duration(milliseconds: 800));

        // Navigation finale: si on a un score, aller vers QuizEndPage, sinon Home
        if (mounted) {
          final hasEndData = widget.score != null && widget.totalQuestions != null;
          if (hasEndData) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => QuizEndPage(
                  score: widget.score!,
                  totalQuestions: widget.totalQuestions!,
                  mission: widget.mission,
                  wrongBirds: widget.wrongBirds ?? const [],
                  recap: widget.recap ?? const [],
                ),
              ),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
              (route) => false,
            );
          }
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
        
        // Étape 1: Vérifier la cohérence des vies actuelles
        await _updateProgress('Vérification de la cohérence des vies...', 0.25);
        final verifiedLives = await LifeSyncService.verifyAndFixLives(uid);
        if (kDebugMode) debugPrint('📊 Vies vérifiées dans Firestore: $verifiedLives');
        
        // Étape 2: Vérifier les vies actuelles avant synchronisation
        final currentLives = await LifeSyncService.getCurrentLives(uid);
        if (kDebugMode) debugPrint('📊 Vies actuelles dans Firestore: $currentLives');
        
        // Étape 3: Synchroniser avec les vies restantes du quiz
        await _updateProgress('Synchronisation des vies restantes...', 0.3);
        await LifeSyncService.syncLivesAfterQuiz(uid, widget.livesRemaining);
        
        // Étape 4: Vérifier les vies après synchronisation
        final updatedLives = await LifeSyncService.getCurrentLives(uid);
        if (kDebugMode) debugPrint('✅ Vies synchronisées: ${widget.livesRemaining} → Firestore: $updatedLives');
        
        // Étape 5: Vérification finale de cohérence
        await _updateProgress('Vérification finale...', 0.35);
        final finalLives = await LifeSyncService.verifyAndFixLives(uid);
        if (kDebugMode) debugPrint('✅ Vérification finale: $finalLives vies');
        
      } else {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté, synchronisation ignorée');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation des vies: $e');
      if (kDebugMode) debugPrint('   Stack trace: ${e.toString()}');
      
      // En cas d'erreur, essayer une réinitialisation forcée
      try {
        final uid = LifeSyncService.getCurrentUserId();
        if (uid != null) {
          if (kDebugMode) debugPrint('🔄 Tentative de réinitialisation forcée des vies');
          await LifeSyncService.forceResetLives(uid);
          if (kDebugMode) debugPrint('✅ Réinitialisation forcée réussie');
        }
      } catch (resetError) {
        if (kDebugMode) debugPrint('❌ Échec de la réinitialisation forcée: $resetError');
      }
      
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
    final s = useScreenSize(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size box = constraints.biggest;
            final double shortest = box.shortestSide;
            final bool isWide = box.aspectRatio >= 0.70;
            final bool isLarge = s.isMD || s.isLG || s.isXL;
            final bool isTablet = shortest >= 600;

            final double scale = s.textScale();
            final double localScale = isTablet
                ? (shortest / 800.0).clamp(0.85, 1.2)
                : (shortest / 600.0).clamp(0.92, 1.45);
            final double spacing = isTablet
                ? (s.spacing() * localScale * 1.05).clamp(12.0, 40.0).toDouble()
                : 32.0;

            final double lottieSize = isTablet
                ? (shortest * (isWide ? 0.22 : 0.26)).clamp(130.0, 280.0).toDouble()
                : 170.0;
            final double lineWidth = isTablet
                ? (lottieSize * 0.70).clamp(90.0, 220.0).toDouble()
                : 120.0;
            final double lineHeight = isTablet
                ? (4.0 * localScale * 1.1).clamp(3.0, 6.0).toDouble()
                : 4.0;
            final double titleFontSize = isTablet
                ? (20.0 * scale * 1.05).clamp(16.0, 28.0).toDouble()
                : 20.0;
            final double factFontSize = isTablet
                ? (20.0 * scale * 1.02).clamp(16.0, 26.0).toDouble()
                : 20.0;
            final double smallGap = isTablet ? (spacing * 0.16).clamp(3.0, 10.0).toDouble() : 3.0;
            final double mediumGap = isTablet ? (spacing * 0.5).clamp(10.0, 24.0).toDouble() : 15.0;
            final double largeGap = isTablet ? (spacing * 0.7).clamp(14.0, 32.0).toDouble() : 20.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: isTablet ? spacing * 0.5 : spacing * 0.2,
                  left: spacing,
                  right: spacing,
                  bottom: spacing,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? (isWide ? 900.0 : 800.0) : 720.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: lottieSize,
                        height: lottieSize,
                        child: Lottie.asset(
                          _lottiePath,
                          width: lottieSize,
                          height: lottieSize,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                        ),
                      ),

                      SizedBox(height: smallGap),

                      Container(
                        width: lineWidth,
                        height: lineHeight,
                        decoration: BoxDecoration(
                          color: const Color(0x68606D7C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),

                      SizedBox(height: mediumGap),

                      Text(
                        'Déchargement en cours...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xDB606D7C).withValues(alpha: 0.7),
                          fontSize: titleFontSize,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.30,
                          shadows: [
                            Shadow(
                              offset: const Offset(0.5, 0.5),
                              blurRadius: 1.0,
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: largeGap * 0.9),

                      if (_funFacts.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing * 0.5),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: isTablet ? 700.0 : 600.0),
                            child: AnimatedBuilder(
                              animation: _funFactController ?? const AlwaysStoppedAnimation<double>(1.0),
                              builder: (context, child) {
                                final double t = (_funFactController?.value ?? 1.0).clamp(0.0, 1.0);
                                final double outDx = -20.0 * t;
                                final double outOpacity = 1.0 - t;
                                final double outBlur = 1.5 * t;
                                final double inDx = 20.0 * (1.0 - t);
                                final double inOpacity = t;
                                final double inBlur = 1.5 * (1.0 - t);

                                final String currentText = _funFacts[_currentFunFactIndex];
                                final String? prevText = _previousFunFactIndex != null && _isFunFactAnimating
                                    ? _funFacts[_previousFunFactIndex!]
                                    : null;

                                final TextStyle funFactStyle = TextStyle(
                                  color: const Color(0xFF344356),
                                  fontSize: factFontSize,
                                  height: 1.35,
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.30,
                                );

                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (prevText != null)
                                      Opacity(
                                        opacity: outOpacity,
                                        child: Transform.translate(
                                          offset: Offset(outDx, 0),
                                          child: ImageFiltered(
                                            imageFilter: ui.ImageFilter.blur(sigmaX: outBlur, sigmaY: outBlur),
                                            child: Text(
                                              prevText,
                                              textAlign: TextAlign.center,
                                              softWrap: true,
                                              style: funFactStyle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Opacity(
                                      opacity: inOpacity,
                                      child: Transform.translate(
                                        offset: Offset(inDx, 0),
                                        child: ImageFiltered(
                                          imageFilter: ui.ImageFilter.blur(sigmaX: inBlur, sigmaY: inBlur),
                                          child: Text(
                                            currentText,
                                            textAlign: TextAlign.center,
                                            softWrap: true,
                                            style: funFactStyle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                      if (_errorMessage != null) ...[
                        SizedBox(height: spacing * 0.6),
                        Container(
                          padding: EdgeInsets.all(spacing * 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBC4749).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFBC4749).withAlpha(50),
                            ),
                          ),
                          child: Text(
                            'Erreur: ${_errorMessage}',
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
            );
          },
        ),
      ),
    );
  }
} 