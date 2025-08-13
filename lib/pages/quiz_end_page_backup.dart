import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
import '../services/mission_management_service.dart';
import '../models/mission.dart';
import '../ui/responsive/responsive.dart';
import '../ui/scaffold/adaptive_scaffold.dart';
import 'package:lottie/lottie.dart';
import 'package:just_audio/just_audio.dart';
import '../models/answer_recap.dart';
import 'home_screen.dart';

class _EndLayout {
  final double ringSize;
  final double stroke;
  final double scale;
  final double localScale;
  final double spacing;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonTop;
  final double ringStackHeight;
  final double checkTop;
  final double scoreTop;
  final double checkSizeFactor; // Taille relative du Lottie "Check"
  final double recapFontBase;   // Base de la taille du texte du bouton "Récapitulatif"

  const _EndLayout({
    required this.ringSize,
    required this.stroke,
    required this.scale,
    required this.localScale,
    required this.spacing,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.buttonTop,
    required this.ringStackHeight,
    required this.checkTop,
    required this.scoreTop,
    required this.checkSizeFactor,
    required this.recapFontBase,
  });
}

class QuizEndPage extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final Mission? mission; // Mission associée au quiz (peut être null)
  final List<String> wrongBirds; // Nouveau champ pour les oiseaux manqués
  final List<AnswerRecap> recap;

  const QuizEndPage({
    super.key,
    required this.score,
    required this.totalQuestions,
    this.mission,
    this.wrongBirds = const [], // Valeur par défaut
    this.recap = const [],
  });

  @override
  State<QuizEndPage> createState() => _QuizEndPageState();
}

class _QuizEndPageState extends State<QuizEndPage> with TickerProviderStateMixin {
  AnimationController? _ringController;
  Animation<double>? _ringAnimation;
  AnimationController? _checkController;
  AnimationController? _checkGlowController;
  Animation<double>? _checkScale;
  Animation<double>? _checkFade;
  Animation<double>? _checkGlowFade;
  
  // Contrôleurs pour les animations de confetti
  AnimationController? _confetti1Controller;
  AnimationController? _confetti2Controller;
  
  final String _lottiePath = 'assets/PAGE/Score resultat/Check.json';
  final String _confetti1Path = 'assets/PAGE/Score resultat/Confetti.json';
  final String _confetti2Path = 'assets/PAGE/Score resultat/Confetti (1).json';
  
  Future<String>? _lottiePathFuture;
  Future<String>? _confetti1PathFuture;
  Future<String>? _confetti2PathFuture;
  
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _recapPlayer = AudioPlayer();
  String _recapPlayingUrl = '';
  bool _recapIsPlaying = false;
  int _lottieVersion = 0; // permet de forcer le rechargement de l'animation Lottie
  bool _showBlockBorders = false; // Nouvel état pour les bordures temporaires
  
  // Cache pour les phrases du CSV
  Map<int, Map<String, String>>? _csvPhrases;
  
  // Variable pour forcer le refresh des messages aléatoires
  bool _forceMessageRefresh = false;
  
  // Clé unique pour forcer la reconstruction de l'anneau
  int _ringKey = 0;
  
  // Variables de test pour simuler différents scores
  int _testScore = 0;
  bool _useTestScore = false;
  final List<int> _testScores = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  int _currentTestScoreIndex = 0;

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
      debugPrint('🎯 QuizEndPage.initState() appelé');
      debugPrint('   Mission: ${widget.mission?.id ?? "NULL"}');
      debugPrint('   Score: ${widget.score}/${widget.totalQuestions}');
    }
    
    // Mettre à jour les étoiles si une mission est fournie
    if (widget.mission != null) {
      if (kDebugMode) debugPrint('✅ Mission trouvée, appel de _updateMissionStars()');
      _updateMissionStars();
    } else {
      if (kDebugMode) debugPrint('❌ Aucune mission fournie à QuizEndPage');
    }

    // Prépare l'animation (initialisation paresseuse également assurée au build)
    _initRingAnimationIfNeeded();
    _initCheckAnimationIfNeeded(); // initialise sans démarrer
    _lottiePathFuture = _resolveLottiePath();
    
    // Initialise les animations de confetti
    _initConfettiAnimations();
    _confetti1PathFuture = _resolveConfettiPath(_confetti1Path);
    _confetti2PathFuture = _resolveConfettiPath(_confetti2Path);
    
    // Charge les phrases du CSV
    _loadCSVPhrases();
  }

  /// Met à jour complètement la progression de la mission dans Firestore
  Future<void> _updateMissionStars() async {
    try {
      if (widget.mission == null) {
        if (kDebugMode) debugPrint('⚠️ Aucune mission fournie');
        return;
      }

      if (kDebugMode) {
        debugPrint('🚀 Début de la mise à jour de la progression pour ${widget.mission!.id}');
        debugPrint('   Score: ${widget.score}/10');
        debugPrint('   Mission ID: ${widget.mission!.id}');
      }

      // Calculer la durée de la partie (approximative)
      final Duration dureePartie = DateTime.now().difference(DateTime.now().subtract(const Duration(minutes: 5)));

      if (kDebugMode) {
        debugPrint('📊 Appel du service MissionManagementService...');
      }

      // Utiliser le nouveau service complet de gestion des missions
      await MissionManagementService.updateMissionProgress(
        missionId: widget.mission!.id,
        score: widget.score,
        totalQuestions: widget.totalQuestions,
        dureePartie: dureePartie,
        wrongBirds: widget.wrongBirds, // Nouveau paramètre
      );
      
      if (kDebugMode) {
        debugPrint('✅ Progression complète mise à jour pour ${widget.mission!.id}');
        debugPrint('   Score: ${widget.score}/10');
        debugPrint('   Durée: ${dureePartie.inSeconds}s');
        debugPrint('   Service appelé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour de la progression: $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🎨 QuizEndPage.build() appelé');
      debugPrint('   Mission: ${widget.mission?.id ?? "NULL"}');
      debugPrint('   Score: ${widget.score}/${widget.totalQuestions}');
    }
    
    final s = useScreenSize(context);
    return AdaptiveScaffold(
      body: Container(
        color: const Color(0xFFF3F5F9),
        child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
              // === Ratios et dimensions HARMONISÉS pour tous les écrans ===
            final Size box = constraints.biggest;
            final double shortest = box.shortestSide;
            final bool isWide = box.aspectRatio >= 0.70; // tablette paysage / desktop
            final bool isLarge = s.isMD || s.isLG || s.isXL;
            final bool isTablet = shortest >= 600; // Supporte téléphone + tablette

            _EndLayout _layout() {
              // 1) Ring size
              final double baseFactor = isTablet
                  ? (isWide ? 0.46 : 0.54)  // légèrement plus grand pour tablettes
                  : (isLarge ? 0.58 : 0.62);
              double ringSize = (shortest * baseFactor);
              if (isTablet) {
                ringSize *= isWide ? 0.88 : 0.96; // ajuste fin sur tablette paysage/portrait
              } else if (!isWide && !isLarge) {
                ringSize *= 0.98;
              }
              ringSize = ringSize.clamp(170.0, isTablet ? 420.0 : 420.0);

              // 2) Stroke
              final double stroke = (ringSize * 0.082).clamp(10.0, 22.0);

              // 3) Scales
              final double scale = s.textScale();
              final double localScale = isTablet
                  ? (shortest / 800.0).clamp(0.85, 1.2)
                  : (shortest / 600.0).clamp(0.92, 1.45);

              // 4) Spacing
              final double spacing = (s.spacing() * localScale * (isTablet ? 1.15 : 1.0))
                  .clamp(14.0, isTablet ? 46.0 : 40.0)
                  .toDouble();

              // 5) Button size/pos
              final double buttonWidth = (ringSize * (isTablet ? 0.98 : 1.00)).clamp(180.0, ringSize).toDouble();
              final double buttonHeight = (56.0 * scale * localScale * (isTablet ? 1.18 : 1.00))
                  .clamp(54.0, 94.0)
                  .toDouble();
              final double buttonStrokeFactor = isTablet ? (isWide ? 1.38 : 2.4) : 1.50;
              final double buttonTop = (ringSize - (buttonStrokeFactor * stroke) + s.buttonOverlapPx())
                  .clamp(0.0, ringSize);
              final double ringStackHeight = (ringSize + buttonHeight * (isTablet ? 0.64 : 0.50)).toDouble();

              // 6) Check & score offsets
              final double checkTop = (stroke * (isTablet ? (isWide ? -0.58 : -1.50) : -0.50));
              final double scoreTop = isTablet ? (ringSize * 0.55) : (ringSize * 0.55);

              // 7) Taille du "Check" et base de fonte du bouton "Récap"
              final double checkSizeFactor = isTablet ? 0.94 : 0.46; // agrandir sur tablette, un peu plus gros sur mobile
              final double recapFontBase = isTablet ? 42 : 25;       // texte du bouton "Récapitulatif"

              return _EndLayout(
                ringSize: ringSize,
                stroke: stroke,
                scale: scale,
                localScale: localScale,
                spacing: spacing,
                buttonWidth: buttonWidth,
                buttonHeight: buttonHeight,
                buttonTop: buttonTop,
                ringStackHeight: ringStackHeight,
                checkTop: checkTop,
                scoreTop: scoreTop,
                checkSizeFactor: checkSizeFactor,
                recapFontBase: recapFontBase,
              );
            }

            final layout = _layout();

            return Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                                  padding: EdgeInsets.only(
                    top: isTablet ? layout.spacing * 0.5 : 0, // Plus d'espace en haut sur tablettes
                    left: layout.spacing,
                    right: layout.spacing,
                    bottom: layout.spacing,
                  ),
            child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? (isWide ? 900.0 : 800.0) : 720.0, // Plus large sur tablettes
                    ),
                  child: Stack(
                    children: [
                      // Animations de confetti en arrière-plan de toute la page
                      // Première animation de confetti (Confetti.json) - ARRIÈRE-PLAN
                      Positioned.fill(
                        child: FutureBuilder<String>(
                          future: _confetti1PathFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final path = snapshot.data!;
                            return Lottie.asset(
                              path,
                              key: ValueKey('lottie-confetti1-v$_lottieVersion'),
                              fit: BoxFit.cover,
                              repeat: false,
                              controller: _confetti1Controller,
                              onLoaded: (composition) {
                                if (kDebugMode) {
                                  debugPrint('✅ Confetti 1 chargé: duration=${composition.duration}');
                                }
                              },
                              errorBuilder: (context, error, stackTrace) {
                                if (kDebugMode) {
                                  debugPrint('❌ Erreur Confetti 1: $error');
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          },
                        ),
                      ),
                      // Deuxième animation de confetti (Confetti (1).json) - ARRIÈRE-PLAN, après 2 secondes
                      Positioned.fill(
                        child: FutureBuilder<String>(
                          future: _confetti2PathFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final path = snapshot.data!;
                            return Lottie.asset(
                              path,
                              key: ValueKey('lottie-confetti2-v$_lottieVersion'),
                              fit: BoxFit.cover,
                              repeat: false,
                              controller: _confetti2Controller,
                              onLoaded: (composition) {
                                if (kDebugMode) {
                                  debugPrint('✅ Confetti 2 chargé: duration=${composition.duration}');
                                }
                              },
                              errorBuilder: (context, error, stackTrace) {
                                if (kDebugMode) {
                                  debugPrint('❌ Erreur Confetti 2: $error');
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          },
                        ),
                      ),
                      // Contenu principal au premier plan
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Bloc 1: Header "C'est terminé"
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(layout.spacing, layout.spacing * 0.1, layout.spacing, layout.spacing), // Moins de padding en haut pour remonter
                            decoration: BoxDecoration(
                              border: _showBlockBorders ? Border.all(color: Colors.red, width: 2) : null,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "C'est terminé !",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w900,
                                    fontSize: (28 * layout.scale).clamp(26.0, 40.0).toDouble(),
                                    color: const Color(0xFF334355),
                                  ),
                                ),
                                SizedBox(height: layout.spacing / 2),
                                Text(
                                  "Petit bilan de ta session ornitho",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w500,
                                    fontSize: (18 * layout.scale).clamp(16.0, 24.0).toDouble(),
                                    color: const Color(0xFF6A7280),
                                  ),
                                ),
                              ],
                            ),
                          ),

                           SizedBox(height: layout.spacing),

                          // Bloc 2: Score + Anneau + Bouton récap
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(layout.spacing),
                            decoration: BoxDecoration(
                              border: _showBlockBorders ? Border.all(color: Colors.red, width: 2) : null,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                  // Indicateur de mode test
                                  if (_useTestScore)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: layout.spacing * 0.5, vertical: layout.spacing * 0.3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.science,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                           SizedBox(width: layout.spacing * 0.3),
                                          Text(
                                            'Mode test: Score $_testScore/10',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Quicksand',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                   SizedBox(height: _useTestScore ? layout.spacing * 0.5 : 0),
                                SizedBox(
                                   width: layout.ringSize,
                                   height: layout.ringStackHeight,
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                      clipBehavior: Clip.none,
                                    children: [
                                      // Anneau + texte central
                                      SizedBox(
                                         width: layout.ringSize,
                                         height: layout.ringSize,
                                        child: Stack(
                                          alignment: Alignment.center,
                                            clipBehavior: Clip.none,
                                          children: [
                                            // Anneau - baissé
                                            Positioned(
                                               top: layout.ringSize * 0.13, // Baisse l'anneau de 15% de sa taille
                                              child: (_ringAnimation == null)
                                                  ? CustomPaint(
                                                      key: ValueKey('ring-static-$_ringKey'),
                                                       size: Size(layout.ringSize, layout.ringSize),
                                                      painter: _TwoSemiCircleRingPainter(
                                                        color: const Color(0xFFABC270), // tu gardes ta couleur
                                                        backgroundColor: const Color(0xFFE3E9EE),
                                                         strokeWidth: layout.stroke,
                                                        progress: 0.0,
                                                        deadZoneAngleRad: 0.97,
                                                        deadZoneTopAngleRad: 0.40,
                                                      ),
                                                    )
                                                  : AnimatedBuilder(
                                                      animation: _ringAnimation!,
                                                      builder: (context, _) {
                                                        return CustomPaint(
                                                          key: ValueKey('ring-animated-$_ringKey'),
                                                           size: Size(layout.ringSize, layout.ringSize),
                                                          painter: _TwoSemiCircleRingPainter(
                                                            color: const Color(0xFFABC270),
                                                            backgroundColor: const Color(0xFFE3E9EE),
                                                             strokeWidth: layout.stroke,
                                                            progress: _ringAnimation!.value,
                                                            deadZoneAngleRad: 0.97,
                                                            deadZoneTopAngleRad: 0.40,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                            ),
                                            // Texte central "X sur Y" - baissé avec l'anneau
                                            Positioned(
                                               top: layout.scoreTop, // Centre + offset pour suivre l'anneau
                                              child: SizedBox(
                                                 width: layout.ringSize * 0.7,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                      '${_useTestScore ? _testScore : widget.score} sur ${widget.totalQuestions}',
                                                    textAlign: TextAlign.center,
                        style: TextStyle(
                                                      color: const Color(0xFF334355),
                                                       fontSize: (layout.ringSize * 0.18).clamp(18.0, 58.0).toDouble(),
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Animation check (Lottie) — offset affiné pour tablettes
                                            Positioned(
                                              top: layout.checkTop,
                                              child: FadeTransition(
                                                opacity: _checkFade ?? const AlwaysStoppedAnimation(0.0),
                                                child: ScaleTransition(
                                                  scale: _checkScale ?? const AlwaysStoppedAnimation(0.8),
                                                  child: SizedBox(
                                                    width: (layout.ringSize * layout.checkSizeFactor).clamp(28.0, 210.0).toDouble(),
                                                    height: (layout.ringSize * layout.checkSizeFactor).clamp(28.0, 210.0).toDouble(),
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        alignment: Alignment.center,
                                                        children: [
                                                          // Halo discret derrière le check
                                                          Positioned.fill(
                                                            child: FadeTransition(
                                                              opacity: _checkGlowFade ?? const AlwaysStoppedAnimation(0.0),
                                                              child: DecoratedBox(
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  boxShadow: const [
                                                                    BoxShadow(
                                                                      color: Color(0x33ABC270), // ~20% alpha, même couleur que l'anneau
                                                                      blurRadius: 22,
                                                                      offset: Offset(0, 2),
                                                                      spreadRadius: 1,
                                                                    ),
                                                                    BoxShadow(
                                                                      color: Color(0x1AABC270), // ~10% alpha
                                                                      blurRadius: 36,
                                                                      offset: Offset(0, 2),
                                                                      spreadRadius: 0,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          FutureBuilder<String>(
                                                      future: _lottiePathFuture,
                                                      builder: (context, snapshot) {
                                                        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                                                          return const SizedBox.shrink();
                                                        }
                                                        final path = snapshot.data!;
                                                        return Lottie.asset(
                                                          path,
                                                          key: ValueKey('lottie-check-v$_lottieVersion'),
                                                          fit: BoxFit.contain,
                                                          repeat: false,
                                                          onLoaded: (composition) {
                                                            if (kDebugMode) {
                                                              debugPrint('✅ Lottie chargé: duration=${composition.duration}');
                                                            }
                                                          },
                                                          errorBuilder: (context, error, stackTrace) {
                                                            if (kDebugMode) {
                                                              debugPrint('❌ Erreur Lottie: $error');
                                                            }
                                                            return const SizedBox.shrink();
                                                          },
                                                        );
                                                      },
                                                      ),
                                                    ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                        // Bouton collé au bord inférieur de l'anneau (sans dépasser)
                                      Positioned(
                                        top: layout.buttonTop,
                                        left: (layout.ringSize - layout.buttonWidth) / 2,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints.tightFor(
                                             width: layout.buttonWidth,
                                             height: layout.buttonHeight,
                                          ),
                                          child: DecoratedBox(
                                            decoration: ShapeDecoration(
                                              color: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(26.5),
                                              ),
                                              shadows: const [
                                                BoxShadow(
                                                    color: Color(0x1AFEC868), // léger halo chaud, ~10% alpha
                                                    blurRadius: 24,
                                                    offset: Offset(0, 10),
                                                    spreadRadius: 1,
                                                  ),
                                                  BoxShadow(
                                                    color: Color(0x0DFEC868), // très diffus, ~5% alpha
                                                    blurRadius: 36,
                                                    offset: Offset(0, 14),
                                                  spreadRadius: 0,
                                                  ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  if (kDebugMode) debugPrint('📊 Bouton Récapitulatif cliqué');
                                                    _openRecapSheet(context);
                                                },
                                                borderRadius: BorderRadius.circular(26.5),
                                                child: Center(
                                                  child: Text(
                                                    'Récapitulatif',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: const Color(0xFFFEC868),
                                                      fontSize: (layout.recapFontBase * layout.scale * layout.localScale)
                                                          .clamp(18.0, 36.0)
                                                          .toDouble(),
                            fontFamily: 'Quicksand',
                                                      fontWeight: FontWeight.w900,
                                                      height: 1.40,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                            // Plus d'espace entre le bloc 2 et le bloc 3 pour donner de l'air aux phrases
                            SizedBox(height: isTablet ? layout.spacing * 0.2 : layout.spacing * 0.4), // Plus d'espace sur mobile

                          // Bloc 3: Textes de félicitations
                          Container(
                            width: double.infinity,
                              padding: EdgeInsets.all(layout.spacing * 0.8), // Padding réduit mais suffisant
                            decoration: BoxDecoration(
                              border: _showBlockBorders ? Border.all(color: Colors.red, width: 2) : null,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min, // S'adapte au contenu
                              children: [
                                  // Titre principal avec gestion du débordement
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      _getTitleMessage(_useTestScore ? _testScore : widget.score, widget.totalQuestions),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF334355),
                                    fontSize: (22 * layout.scale * layout.localScale).clamp(20.0, 38.0).toDouble(),
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w700,
                                    height: 1.40,
                                  ),
                                      overflow: TextOverflow.visible,
                                      softWrap: true,
                                      maxLines: null, // Permet plusieurs lignes
                                    ),
                                  ),
                                   SizedBox(height: layout.spacing * 0.6), // Espacement entre titre et sous-titre
                                  // Sous-titre avec gestion du débordement
                                  SizedBox(
                                    width: double.infinity,
                                    child: Opacity(
                                  opacity: 0.80,
                        child: Text(
                                    _getSubtitleMessage(_useTestScore ? _testScore : widget.score, widget.totalQuestions),
                      textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF334355),
                                    fontSize: (19 * layout.scale * layout.localScale).clamp(17.0, 32.0).toDouble(),
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w500,
                                    height: 1.40,
                                      ),
                                      overflow: TextOverflow.visible,
                                      softWrap: true,
                                      maxLines: null, // Permet plusieurs lignes
                        ),
                      ),
                    ),
                  ],
                ),
              ),

                // Espacement dynamique après le bloc 3 selon la longueur des phrases
                SizedBox(height: _getDynamicSpacing(_useTestScore ? _testScore : widget.score, widget.totalQuestions, layout.spacing, isTablet)),
                
                // Espacement supplémentaire pour mobile pour éviter que le bouton soit trop proche
                if (!isTablet) SizedBox(height: layout.spacing * 0.3),

              // Bloc 4: Bouton continuer (design login)
                Center(
                  child: Container(
                    width: 300, // Largeur fixe au lieu de double.infinity pour un bouton moins large
                decoration: BoxDecoration(
                  border: _showBlockBorders ? Border.all(color: Colors.red, width: 2) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  height: (layout.buttonHeight * 1.05).clamp(52.0, 96.0).toDouble(),
                  child: Stack(
                    children: [
                      Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                                    (route) => false,
                                  );
                                },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A994E),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Align(
                                      alignment: Alignment.center, // Centré au lieu d'aligné à gauche
                              child: Text(
                                'Continuer',
                                style: TextStyle(
                                  fontSize: (20 * layout.scale).clamp(18.0, 28.0).toDouble(),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Quicksand',
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 16,
                                top: 12,
                                bottom: 12,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Color(0xFF6A994E),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                              ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton pour afficher/masquer les bordures
          Container(
            width: 56,
            height: 56,
      decoration: BoxDecoration(
              color: _showBlockBorders ? Colors.red : Colors.grey,
              shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
                onTap: () {
                  setState(() {
                    _showBlockBorders = !_showBlockBorders;
                  });
                },
                borderRadius: BorderRadius.circular(28),
                child: Icon(
                  _showBlockBorders ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Bouton de rafraîchissement existant
          FloatingActionButton(
            onPressed: _resetView,
            backgroundColor: const Color(0xFF6A994E),
            tooltip: 'Tester différents scores (0-10)',
            child: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Charge les phrases du fichier CSV
  Future<void> _loadCSVPhrases() async {
    try {
      final String csvData = await rootBundle.loadString('assets/PAGE/Score resultat/phrases_fin_quiz_complet.csv');
      final List<String> lines = csvData.split('\n');
      
      _csvPhrases = {};
      
      // Ignorer la première ligne (en-têtes)
      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isNotEmpty) {
          final List<String> columns = _parseCSVLine(line);
          if (columns.length >= 5) {
            final int note = int.tryParse(columns[0]) ?? 0;
            _csvPhrases![note] = {
              'titre': columns[1].trim(),
              'sous-titre1': columns[2].trim(),
              'sous-titre2': columns[3].trim(),
              'sous-titre3': columns[4].trim(),
              'sous-titre4': columns.length > 5 ? columns[5].trim() : '',
            };
          }
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ CSV chargé avec ${_csvPhrases!.length} notes');
        debugPrint('📚 Contenu du CSV:');
        _csvPhrases!.forEach((note, phrases) {
          debugPrint('  Note $note:');
          debugPrint('    Titre: "${phrases['titre']}"');
          debugPrint('    Sous-titre2: "${phrases['sous-titre2']}"');
          debugPrint('    Sous-titre3: "${phrases['sous-titre3']}"');
          debugPrint('    Sous-titre4: "${phrases['sous-titre4']}"');
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du chargement du CSV: $e');
      }
      _csvPhrases = null;
    }
  }

  /// Parse une ligne CSV en respectant les guillemets
  List<String> _parseCSVLine(String line) {
    final List<String> columns = [];
    final StringBuffer currentColumn = StringBuffer();
    bool insideQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        // Gérer les guillemets échappés (double guillemet)
        if (i + 1 < line.length && line[i + 1] == '"') {
          currentColumn.write('"');
          i++; // Sauter le prochain guillemet
        } else {
          // Basculer l'état insideQuotes
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        // Virgule de séparation (pas à l'intérieur des guillemets)
        columns.add(currentColumn.toString());
        currentColumn.clear();
      } else {
        // Ajouter le caractère à la colonne courante
        currentColumn.write(char);
      }
    }
    
    // Ajouter la dernière colonne
    columns.add(currentColumn.toString());
    
    return columns;
  }

  /// Génère le titre selon le score en utilisant le CSV
  String _getTitleMessage(int score, int totalQuestions) {
    final percentage = (score / totalQuestions) * 100;
    
    // Déterminer la note (0-10) basée sur le pourcentage avec une logique plus équilibrée
    int note;
    if (percentage >= 95) {
      note = 10;
    } else if (percentage >= 90) {
      note = 9;
    } else if (percentage >= 80) {
      note = 8;
    } else if (percentage >= 70) {
      note = 7;
    } else if (percentage >= 60) {
      note = 6;
    } else if (percentage >= 50) {
      note = 5;
    } else if (percentage >= 40) {
      note = 4;
    } else if (percentage >= 30) {
      note = 3;
    } else if (percentage >= 20) {
      note = 2;
    } else if (percentage >= 10) {
      note = 1;
    } else {
      note = 0;
    }
    
    if (kDebugMode) {
      debugPrint('🎯 _getTitleMessage: score=$score/$totalQuestions (${percentage.toStringAsFixed(1)}%) → note=$note');
      debugPrint('📚 CSV disponible: ${_csvPhrases != null ? "OUI" : "NON"}');
      if (_csvPhrases != null) {
        debugPrint('📚 CSV contient la note $note: ${_csvPhrases!.containsKey(note)}');
        if (_csvPhrases!.containsKey(note)) {
          debugPrint('📚 Titre CSV: "${_csvPhrases![note]!['titre']}"');
        }
      }
    }
    
    // Utiliser le CSV si disponible, sinon fallback
    if (_csvPhrases != null && _csvPhrases!.containsKey(note)) {
      final csvTitle = _csvPhrases![note]!['titre'];
      if (csvTitle != null && csvTitle.isNotEmpty) {
        if (kDebugMode) debugPrint('✅ Utilisation du titre CSV: "$csvTitle"');
        return csvTitle;
      } else {
        if (kDebugMode) debugPrint('⚠️ Titre CSV vide ou null, utilisation du fallback');
      }
    } else {
      if (kDebugMode) debugPrint('⚠️ CSV non disponible ou note $note non trouvée, utilisation du fallback');
    }
    
    return _getFallbackTitle(percentage);
  }
  
  /// Titre de fallback si le CSV n'est pas chargé
  String _getFallbackTitle(double percentage) {
    if (percentage >= 90) {
      return "Tu es prêt(e) pour la nature !";
    } else if (percentage >= 80) {
      return "C'est presque parfait.";
    } else if (percentage >= 70) {
      return "Belle écoute !";
    } else if (percentage >= 60) {
      return "Tu tiens le rythme.";
    } else if (percentage >= 50) {
      return "À mi-chemin !";
    } else if (percentage >= 40) {
      return "Ça vient doucement.";
    } else if (percentage >= 30) {
      return "L'oreille s'ouvre.";
    } else if (percentage >= 20) {
      return "Tu progresses déjà.";
    } else if (percentage >= 10) {
      return "Tu t'es lancé.";
    } else {
      return "C'est un début.";
    }
  }

  /// Génère le sous-titre selon le score en utilisant le CSV avec logique aléatoire
  String _getSubtitleMessage(int score, int totalQuestions) {
    final percentage = (score / totalQuestions) * 100;
    
    // Déterminer la note (0-10) basée sur le pourcentage avec la même logique que _getTitleMessage
    int note;
    if (percentage >= 95) {
      note = 10;
    } else if (percentage >= 90) {
      note = 9;
    } else if (percentage >= 80) {
      note = 8;
    } else if (percentage >= 70) {
      note = 7;
    } else if (percentage >= 60) {
      note = 6;
    } else if (percentage >= 50) {
      note = 5;
    } else if (percentage >= 40) {
      note = 4;
    } else if (percentage >= 30) {
      note = 3;
    } else if (percentage >= 20) {
      note = 2;
    } else if (percentage >= 10) {
      note = 1;
    } else {
      note = 0;
    }
    
    if (kDebugMode) {
      debugPrint('🎯 _getSubtitleMessage: score=$score/$totalQuestions (${percentage.toStringAsFixed(1)}%) → note=$note');
      debugPrint('📚 CSV disponible: ${_csvPhrases != null ? "OUI" : "NON"}');
      if (_csvPhrases != null) {
        debugPrint('📚 CSV contient la note $note: ${_csvPhrases!.containsKey(note)}');
        if (_csvPhrases!.containsKey(note)) {
          debugPrint('📚 Sous-titres disponibles: sous-titre2="${_csvPhrases![note]!['sous-titre2']}", sous-titre3="${_csvPhrases![note]!['sous-titre3']}", sous-titre4="${_csvPhrases![note]!['sous-titre4']}"');
        }
      }
    }
    
    // Utiliser le CSV si disponible avec logique aléatoire
    if (_csvPhrases != null && _csvPhrases!.containsKey(note)) {
      // Utiliser _forceMessageRefresh pour forcer l'aléatoire à chaque restart
      final random = math.Random(_forceMessageRefresh.hashCode + DateTime.now().millisecondsSinceEpoch);
      final choice = random.nextInt(3); // 0, 1, ou 2
      
      if (kDebugMode) debugPrint('🎲 Choix aléatoire: $choice (0=sous-titre2, 1=sous-titre3, 2=sous-titre4)');
      
      // Choisir aléatoirement entre sous-titre2, sous-titre3, sous-titre4
      String? selectedSubtitle;
      if (choice == 0) {
        selectedSubtitle = _csvPhrases![note]!['sous-titre2'];
        if (kDebugMode) debugPrint('🎲 Sélection du sous-titre2: "$selectedSubtitle"');
      } else if (choice == 1) {
        selectedSubtitle = _csvPhrases![note]!['sous-titre3'];
        if (kDebugMode) debugPrint('🎲 Sélection du sous-titre3: "$selectedSubtitle"');
      } else {
        selectedSubtitle = _csvPhrases![note]!['sous-titre4'];
        if (kDebugMode) debugPrint('🎲 Sélection du sous-titre4: "$selectedSubtitle"');
      }
      
      if (selectedSubtitle != null && selectedSubtitle.isNotEmpty) {
        if (kDebugMode) debugPrint('✅ Utilisation du sous-titre CSV: "$selectedSubtitle"');
        return selectedSubtitle;
      } else {
        if (kDebugMode) debugPrint('⚠️ Sous-titre CSV vide ou null, utilisation du fallback');
      }
    } else {
      if (kDebugMode) debugPrint('⚠️ CSV non disponible ou note $note non trouvée, utilisation du fallback');
    }
    
    // Fallback si le CSV n'est pas chargé ou si la phrase est vide
    return _getFallbackSubtitle(note);
  }
  
  /// Sous-titre de fallback si le CSV n'est pas chargé
  String _getFallbackSubtitle(int note) {
    // Utiliser _forceMessageRefresh pour forcer l'aléatoire à chaque restart
    final random = math.Random(_forceMessageRefresh.hashCode + DateTime.now().millisecondsSinceEpoch);
    final choice = random.nextInt(3); // 0, 1, ou 2
    
    if (note >= 8) {
      if (choice == 0) {
        return "Continue comme ça, tu progresses bien !";
      } else if (choice == 1) {
        return "Tu as l'oreille affûtée !";
      } else {
        return "Impressionnant, la forêt devient ton terrain de jeu !";
      }
    } else if (note >= 6) {
      if (choice == 0) {
        return "Pas mal, tu tiens le rythme !";
      } else if (choice == 1) {
        return "Tu te rapproches du sans-faute !";
      } else {
        return "Ton oreille s'éveille, continue !";
      }
    } else if (note >= 4) {
      if (choice == 0) {
        return "C'est un bon début, continue !";
      } else if (choice == 1) {
        return "Tu construis ton oreille !";
    } else {
        return "La nature est patiente, sois-le aussi !";
      }
    } else {
      if (choice == 0) {
        return "Ne te décourage pas, la prochaine fois sera la bonne !";
      } else if (choice == 1) {
        return "Chaque pro a commencé en entendant juste du bruit !";
      } else {
        return "La nature est patiente, sois-le aussi !";
      }
    }
  }
  
  /// Récupère le score à afficher (dynamique ou original)
  int get displayScore => widget.score;
  
  /// Récupère le total de questions à afficher (dynamique ou original)
  int get displayTotalQuestions => widget.totalQuestions;

  @override
  void dispose() {
    _ringController?.dispose();
    _checkController?.dispose();
    _checkGlowController?.dispose();
    _confetti1Controller?.dispose();
    _confetti2Controller?.dispose();
    _recapPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Réinitialise toute la page (animations + scroll + Lottie)
  void _resetView() {
    // 1) Scroll en haut
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    
    // 2) Changer le score de test pour tester différentes animations
    _currentTestScoreIndex = (_currentTestScoreIndex + 1) % _testScores.length;
    _testScore = _testScores[_currentTestScoreIndex];
    _useTestScore = true;
    
    if (kDebugMode) {
      debugPrint('🧪 Test avec le score: $_testScore/10');
    }
    
    // 3) Anneau: recréer avec le score de test
    _initRingAnimationIfNeeded();
    // 4) Check: sera déclenché à la fin de l'anneau; on le remet à 0
    if (_checkController != null) {
      _checkController!.stop();
      _checkController!.reset();
    } else {
      _initCheckAnimationIfNeeded();
      _checkController!.reset();
    }
    // 4bis) Glow du check: reset pour qu'il ne soit pas visible avant
    if (_checkGlowController != null) {
      _checkGlowController!.stop();
      _checkGlowController!.reset();
    }
    // 4ter) Confettis: reset et relance
    if (_confetti1Controller != null) {
      _confetti1Controller!.stop();
      _confetti1Controller!.reset();
      _confetti1Controller!.forward();
    }
    if (_confetti2Controller != null) {
      _confetti2Controller!.stop();
      _confetti2Controller!.reset();
      // Relancer après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _confetti2Controller!.forward();
        }
      });
    }
    // 5) Forcer le rechargement de Lottie (rejouer depuis le début)
    // 6) Forcer la régénération des messages aléatoires
    // 7) Forcer la reconstruction de l'anneau
    setState(() {
      _lottieVersion++;
      // Force la régénération des messages en changeant un état
      _forceMessageRefresh = !_forceMessageRefresh;
      // Force la reconstruction de l'anneau
      _ringKey++;
    });
  }

  void _initRingAnimationIfNeeded() {
    // Toujours recréer l'animation pour s'assurer qu'elle reflète le bon score
    if (_ringController != null) {
      _ringController!.dispose();
      _ringController = null;
      _ringAnimation = null;
    }
    
    // Utiliser le score de test si activé, sinon le VRAI score de la mission
    final int currentScore = _useTestScore ? _testScore : widget.score;
    final int currentTotal = widget.totalQuestions;
    
    final double targetProgress = (currentTotal > 0)
        ? (currentScore / currentTotal).clamp(0.0, 1.0)
        : 0.0;
    
    if (kDebugMode) {
      if (_useTestScore) {
        debugPrint('🧪 Animation anneau: SCORE DE TEST=$currentScore/$currentTotal → progress=${(targetProgress * 100).toStringAsFixed(0)}%');
      } else {
        debugPrint('🎯 Animation anneau: VRAI score=$currentScore/$currentTotal → progress=${(targetProgress * 100).toStringAsFixed(0)}%');
      }
    }
    
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringAnimation = Tween<double>(begin: 0.0, end: targetProgress).animate(
      CurvedAnimation(parent: _ringController!, curve: Curves.easeOutCubic),
    );
    
    // Flag pour éviter les logs répétés
    int lastLoggedPercent = -1;
    
    _ringAnimation!.addListener(() {
      if (kDebugMode) {
        // Log moins fréquent : seulement tous les 20% de progression, une seule fois
        final int progressPercent = (_ringAnimation!.value * 100).round();
        if ((progressPercent % 20 == 0 || progressPercent == 100) && progressPercent != lastLoggedPercent) {
          debugPrint('🔄 Ring progress: $progressPercent%');
          lastLoggedPercent = progressPercent;
        }
      }
      
      // Déclencher l'animation du check de manière intelligente
      // Soit à 90% de l'animation, soit quand on est proche de la fin
      final double progress = _ringAnimation!.value;
      final bool shouldTriggerCheck = (progress >= 0.80) || 
                                     (progress >= targetProgress * 0.85) ||
                                     (progress >= targetProgress - 0.1);
      
      if (shouldTriggerCheck && _checkController != null && _checkController!.status == AnimationStatus.dismissed) {
        if (kDebugMode) debugPrint('🚀 Check déclenché à ${(progress * 100).toStringAsFixed(0)}% de l\'anneau');
        _initCheckAnimationIfNeeded();
        _checkController?.forward(from: 0.0);
      }
    });
    _ringController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (kDebugMode) debugPrint('✅ Ring animation completed');
        // Le check est déjà déclenché à 90%, pas besoin de le relancer
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ringController!.forward();
    });
  }

  void _initCheckAnimationIfNeeded() {
    if (_checkController != null && _checkScale != null && _checkFade != null && _checkGlowController != null && _checkGlowFade != null) return;
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(parent: _checkController!, curve: Curves.easeOutBack);
    _checkFade = CurvedAnimation(parent: _checkController!, curve: Curves.easeOut);
    // Contrôleur dédié à la lueur, qui démarrera uniquement quand le check est terminé
    _checkGlowController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _checkGlowFade = CurvedAnimation(parent: _checkGlowController!, curve: Curves.easeOut);
    // Démarre le glow uniquement à la fin de l'anim du check
    _checkController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkGlowController?.forward(from: 0.0);
      }
    });
  }

  Future<String> _resolveLottiePath() async {
    try {
      await rootBundle.load(_lottiePath);
      if (kDebugMode) debugPrint('✅ Lottie path OK: $_lottiePath');
      return _lottiePath;
    } catch (e) {
      final fallback = 'assets/animations/Check.json';
      try {
        await rootBundle.load(fallback);
        if (kDebugMode) debugPrint('ℹ️ Lottie fallback path used: $fallback');
        return fallback;
      } catch (e2) {
        if (kDebugMode) debugPrint('❌ Aucun asset Lottie valide (primary/fallback)');
        return _lottiePath; // laisser vide, FutureBuilder rendra un SizedBox
      }
    }
  }

  /// Initialise les contrôleurs de confetti
  void _initConfettiAnimations() {
    _confetti1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _confetti2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Démarrer la première animation de confetti immédiatement
    _confetti1Controller?.forward();
    
    // Démarrer la deuxième animation de confetti après 2 secondes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _confetti2Controller?.forward();
      }
    });
  }

  /// Résout le chemin d'un asset Lottie pour les confettis
  Future<String> _resolveConfettiPath(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      if (kDebugMode) debugPrint('✅ Confetti path OK: $assetPath');
      return assetPath;
    } catch (e) {
      final fallback = 'assets/animations/Confetti.json';
      try {
        await rootBundle.load(fallback);
        if (kDebugMode) debugPrint('ℹ️ Confetti fallback path used: $fallback');
        return fallback;
      } catch (e2) {
        if (kDebugMode) debugPrint('❌ Aucun asset Confetti valide (primary/fallback)');
        return assetPath; // laisser vide, FutureBuilder rendra un SizedBox
      }
    }
  }

  /// Détermine l'espacement dynamique après le bloc 3 en fonction de la longueur des phrases
  double _getDynamicSpacing(int score, int totalQuestions, double spacing, bool isTablet) {
    final percentage = (score / totalQuestions) * 100;
    
    // Espacement de base selon la note
    double baseSpacing;
    if (percentage >= 90) {
      baseSpacing = spacing * 0.8; // Phrases d'excellence - plus d'espace
    } else if (percentage >= 70) {
      baseSpacing = spacing * 0.6; // Phrases moyennes - espacement moyen
    } else if (percentage >= 50) {
      baseSpacing = spacing * 0.5; // Phrases de progression - espacement réduit
    } else {
      baseSpacing = spacing * 0.4; // Phrases d'encouragement - espacement minimal
    }
    
    // Sur mobile, augmenter l'espacement pour éviter que le bouton soit trop proche
    if (!isTablet) {
      baseSpacing *= 1.5; // +50% d'espacement sur mobile
    }
    
    return baseSpacing;
  }

  void _openRecapSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final height = media.size.height * 0.85;
        final padding = media.viewInsets + const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

        // Données minimales: on affiche les mauvaises réponses (si fournies) et, si possible, les bonnes (pool Firestore)
        final entries = widget.recap;

        return SizedBox(
          height: height,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Récapitulatif',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Color(0xFF334355),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.isEmpty ? 1 : entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (entries.isEmpty) {
                        return _RecapCard(
                          indexOneBased: 1,
                          isCorrect: true,
                          displayName: 'Rien à afficher',
                          expected: '',
                          selected: '',
                          audioUrl: '',
                          isActive: false,
                          onToggle: _toggleRecapAudio,
                        );
                      }
                      final a = entries[index];
                      final bool correct = a.isCorrect;
                      // Affichage: montrer le nom attendu (oiseau correct). En dessous, si faux, "Vous avez mis <selected>".
                      return _RecapCard(
                        indexOneBased: index + 1,
                        isCorrect: correct,
                        displayName: a.questionBird,
                        expected: a.questionBird,
                        selected: a.selected,
                        audioUrl: a.audioUrl,
                        isActive: (_recapPlayingUrl == a.audioUrl) && _recapIsPlaying,
                        onToggle: _toggleRecapAudio,
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleRecapAudio(String url) async {
    if (url.isEmpty) return;
    try {
      // Si on clique sur le même son et qu'il joue, on stoppe
      if (_recapIsPlaying && _recapPlayingUrl == url) {
        await _recapPlayer.stop();
        setState(() {
          _recapIsPlaying = false;
        });
        return;
      }
      // Sinon on (re)lance ce son
      await _recapPlayer.stop();
      await _recapPlayer.setUrl(url);
      await _recapPlayer.play();
      setState(() {
        _recapPlayingUrl = url;
        _recapIsPlaying = true;
      });
    } catch (_) {
      setState(() {
        _recapIsPlaying = false;
      });
    }
  }
}

class _RecapCard extends StatelessWidget {
  final int indexOneBased;
  final bool isCorrect;
  final String displayName; // affiché en titre (nom de l'oiseau correct)
  final String expected; // nom correct
  final String selected; // réponse de l'utilisateur
  final String audioUrl;
  final bool isActive;
  final Future<void> Function(String url) onToggle;

  const _RecapCard({
    required this.indexOneBased,
    required this.isCorrect,
    required this.displayName,
    required this.expected,
    required this.selected,
    required this.audioUrl,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isCorrect ? const Color(0xFF6A994E) : const Color(0xFFBC4749);
    final Color chipColor = isCorrect ? const Color(0x1A6A994E) : const Color(0x1ABC4749);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Numéro de question
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: chipColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                indexOneBased.toString(),
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: borderColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: chipColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334355),
                      fontSize: 16,
                    ),
                  ),
                  if (!isCorrect) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Vous avez mis "$selected"',
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                        color: Color(0x80334355),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PlayAudioButton(color: borderColor, audioUrl: audioUrl, isActive: isActive, onToggle: onToggle),
          ],
        ),
      ),
    );
  }
}

class _PlayAudioButton extends StatefulWidget {
  final Color color;
  final String audioUrl;
  final bool isActive;
  final Future<void> Function(String url) onToggle;
  const _PlayAudioButton({required this.color, required this.audioUrl, required this.isActive, required this.onToggle});

  @override
  State<_PlayAudioButton> createState() => _PlayAudioButtonState();
}

class _PlayAudioButtonState extends State<_PlayAudioButton> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: (_loading || widget.audioUrl.isEmpty) ? null : _onToggleTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(10.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.isActive ? Icons.stop : Icons.mic,
                color: widget.audioUrl.isEmpty ? widget.color.withOpacity(0.4) : widget.color),
      ),
    );
  }

  Future<void> _onToggleTap() async {
    setState(() => _loading = true);
    try {
      await widget.onToggle(widget.audioUrl);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// Peintre des deux demi-anneaux de progression avec lueur
class _TwoSemiCircleRingPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double progress; // 0.0 → 1.0
  final double deadZoneAngleRad; // zone morte centrée en bas (radians)
  final double deadZoneTopAngleRad; // zone morte centrée en haut (radians)

  _TwoSemiCircleRingPainter({
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.progress,
    this.deadZoneAngleRad = 0.0,
    this.deadZoneTopAngleRad = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Glow style "BoxShadow": puissant près du trait, diffus vers l'extérieur (simple et progressif)
    const double _boxShadowBlurRadius = 35.8; // comme BoxShadow(blurRadius: 35.8)
    final double _sigma = _boxShadowBlurRadius * 0.57735 + 0.5; // conversion radius -> sigma
    final Paint glowShadow = Paint()
      ..color = color.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma)
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(strokeWidth / 2);

    // Calcul des angles disponibles pour le dessin
    final double bottomGap = deadZoneAngleRad.clamp(0.0, math.pi / 3);
    final double topGap = deadZoneTopAngleRad.clamp(0.0, math.pi / 3);

    // Angle total disponible pour chaque demi-cercle (en excluant les zones mortes)
    final double availableSweep = (math.pi - bottomGap - topGap).clamp(0.0, math.pi);

    if (availableSweep <= 0) return; // rien à dessiner si gaps trop grands

    // Progression effective basée sur le score (0.0 à 1.0)
    final double clamped = progress.clamp(0.0, 1.0);
    final double sweep = availableSweep * clamped;

    // Fond gris (deux demi-cercles complets moins les zones mortes)
    // Demi-cercle droit (horaire)
    canvas.drawArc(arcRect, math.pi / 2 + bottomGap, availableSweep, false, bgPaint);
    // Demi-cercle gauche (anti-horaire)
    canvas.drawArc(arcRect, math.pi / 2 - bottomGap, -availableSweep, false, bgPaint);

    // Progression verte proportionnelle au score + lueur
    if (clamped > 0) {
      // Lueur sous-jacente
      canvas.drawArc(arcRect, math.pi / 2 + bottomGap, sweep, false, glowShadow);
      canvas.drawArc(arcRect, math.pi / 2 - bottomGap, -sweep, false, glowShadow);
      // Trait principal
      canvas.drawArc(arcRect, math.pi / 2 + bottomGap, sweep, false, fgPaint);
      canvas.drawArc(arcRect, math.pi / 2 - bottomGap, -sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TwoSemiCircleRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progress != progress ||
        oldDelegate.deadZoneAngleRad != deadZoneAngleRad ||
        oldDelegate.deadZoneTopAngleRad != deadZoneTopAngleRad;
  }
}

