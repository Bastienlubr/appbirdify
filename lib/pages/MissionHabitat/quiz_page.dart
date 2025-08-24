import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:animations/animations.dart';
import 'package:rive/rive.dart' as rive;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/Mission/communs/commun_generateur_quiz.dart';
import '../../services/Users/user_orchestra_service.dart';
import '../../services/Mission/communs/commun_gestionnaire_assets.dart';
import '../../ui/responsive/responsive.dart';
import '../../models/mission.dart';
import '../../models/bird.dart';
import '../../models/answer_recap.dart';
// removed unused import
import '../mission_unloading_screen.dart';

class QuizPage extends StatefulWidget {
  final String missionId;
  final Mission? mission;
  final Map<String, Bird>? preloadedBirds;
  final List<QuizQuestion>? preloadedQuestions;
  
  const QuizPage({
    super.key,
    required this.missionId,
    this.mission,
    this.preloadedBirds,
    this.preloadedQuestions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  List<QuizQuestion> _questions = [];
  String? _selectedAnswer;
  bool _showFeedback = false;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  double _progressFrom = 0.0;
  double _progressTo = 0.0;
  AnimationController? _progressBurstController;
  final List<_ProgressDroplet> _droplets = [];
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;
  AnimationController? _shineController;
  
  final List<String> _wrongBirds = []; // Nouvelle liste pour stocker les noms des oiseaux manqués
  final List<AnswerRecap> _recapEntries = [];

  int _visibleLives = 5;
  bool _isLivesSyncing = false;
  
  late AudioPlayer _audioPlayer;
  String _currentAudioUrl = '';
  bool _isAudioLooping = false;
  bool _audioAnimationOn = true;
  
  bool _showCorrectAnswerImage = false;
  String _correctAnswerImageUrl = '';
  
  // Système de préchargement de la prochaine question
  String _nextAudioUrl = '';
  String _nextImageUrl = '';
  bool _isPreloadingNext = false;
  
  


  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioLooping();
    _progressBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _droplets.clear();
        }
      });
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController!,
      curve: Curves.easeOutCubic,
    );
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    // Si des questions sont préchargées, les utiliser immédiatement pour éviter tout écran de chargement
    if (widget.preloadedQuestions != null && widget.preloadedQuestions!.isNotEmpty) {
      _questions = widget.preloadedQuestions!;
      _isLoading = false; // éviter l'écran "Chargement du quiz..."
      _currentQuestionIndex = 0;
      _score = 0;
      _audioAnimationOn = true;
      _progressFrom = 0.0;
      _progressTo = _questions.isNotEmpty ? (1.0 / _questions.length) : 0.0;
      _prepareDroplets();
      // Charger les vies en arrière-plan; l'UI affichera 5 par défaut puis se mettra à jour
      _loadLivesWithRetry();
      // Lancer l'audio après le premier frame pour ne pas bloquer le rendu
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_questions.isNotEmpty) {
          _loadAndPlayAudio(_questions[0].audioUrl);
        }
      });
    } else {
      _initializeQuiz();
    }
  }

  void _setupAudioLooping() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _isAudioLooping && mounted) {
        Future.microtask(() => _restartAudioAtRandomPosition());
      }
    });
  }

  Future<void> _initializeQuiz() async {
    await _loadLivesWithRetry();

    // Si des questions sont déjà préchargées (depuis MissionLoadingScreen), les utiliser directement
    if (widget.preloadedQuestions != null && widget.preloadedQuestions!.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Utilisation des questions préchargées (${widget.preloadedQuestions!.length} questions)');
      setState(() {
        _questions = widget.preloadedQuestions!;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _score = 0;
        _audioAnimationOn = true;
      });
      if (_questions.isNotEmpty) {
        _loadAndPlayAudio(_questions[0].audioUrl);
        // Précharger la question suivante dès le début
        Future.microtask(() => _preloadNextQuestion());
      }
      return;
    }

    if (widget.preloadedBirds != null && widget.preloadedBirds!.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Utilisation des oiseaux préchargés (${widget.preloadedBirds!.length} oiseaux)');
      
      for (final entry in widget.preloadedBirds!.entries) {
        MissionPreloader.addBirdToCache(entry.key, entry.value);
      }
    } else {
      try {
        if (kDebugMode) debugPrint('🔄 Préchargement complet de la mission ${widget.missionId}...');
        await MissionPreloader.preloadMission(widget.missionId);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur lors du préchargement: $e');
      }
    }
    
    _loadQuiz();
  }

  Future<void> _loadLivesWithRetry() async {
    const maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final uid = UserOrchestra.currentUserId;
        if (uid != null) {
          if (kDebugMode) debugPrint('🔄 Tentative ${retryCount + 1}/$maxRetries de chargement des vies pour $uid');
          
          final lives = await UserOrchestra.checkAndResetLives(uid);
          if (mounted) {
            setState(() {
              _visibleLives = lives;
            });
          }
          return;
        } else {
          if (mounted) {
            setState(() {
              _visibleLives = 5;
            });
          }
          return;
        }
      } catch (e) {
        retryCount++;
        if (kDebugMode) debugPrint('❌ Erreur lors du chargement des vies (tentative $retryCount/$maxRetries): $e');
        
        if (retryCount >= maxRetries) {
          if (mounted) {
            setState(() {
              _visibleLives = 5;
            });
          }
        } else {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _progressBurstController?.dispose();
    _glowController?.dispose();
    _shineController?.dispose();
    super.dispose();
  }





  Widget _buildQuestionPage(QuizQuestion question, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final m = buildResponsiveMetrics(context, constraints);
            final double ui = m.isTablet ? (m.localScale * 1.20).clamp(1.0, 1.5) : 1.0;
            final double topButtonsTop = 30.0 * ui;
            final double topButtonsLeft = 35.0 * ui;
            final double livesTop = 5.0 * ui;
            final double livesRight = 30.0 * ui;
            final double questionCounterTop = 30.0 * ui;
            final double progressTop = 70.0 * ui;
            final double progressSide = 20.0 * ui;
            final double progressWidth = m.isTablet ? (m.maxWidth * 0.66) : (300.0 * ui);
            final double progressHeight = (14.0 * ui).toDouble();
            final double baseAudioSize = m.isTablet ? (m.shortest * 0.30).clamp(220.0, 300.0) : (160.0 * ui);
            final double audioSize = baseAudioSize;
            final double audioTop = m.isTablet ? 230.0 * ui : 185.0;
            // Mobile: conserver le rendu d'origine (3:4, 195x260). Tablette: 4:3 agrandi
            // Exiger un format portrait 3:4 (vertical) sur tous les écrans
            final double imageAspect = (3.0 / 4.0); // width / height
            // Removed unused imageBaseHeight/imageBaseWidth (kept explicit sizes where needed)
            // Sur mobile (A54): conserver base 260x195 (3:4 portrait).
            // Sur tablette: viser 4:3, dimensionné principalement par la largeur pour un rendu "plein" sans letterbox.
            // Mobile: conserver strictement l'emplacement et la taille d'origine (195x260, 3:4)
            final double imageWidth;
            final double imageHeight;
            if (m.isTablet) {
              // Déterminer la hauteur d'abord (portrait), puis calculer la largeur via 3:4
              final double targetHeight = math.min(m.box.height * 0.42, m.shortest * 0.80)
                  .clamp(380.0, 720.0);
              imageHeight = targetHeight;
              imageWidth = (imageHeight * imageAspect);
            } else {
              // Mobile A54: taille optimisée
              imageWidth = 220.0;
              imageHeight = 290.0;
            }
            final double titleFont = m.isTablet ? m.font(28, tabletFactor: 1.2, min: 24, max: 40) : 28.0;
            final double titleTopSpacer = m.isTablet ? 35.0 * ui : 13.0 * ui;
            final int optionCount = question.options.length;
            final double approxAnswersHeight = (optionCount * (50.0 * ui)) + ((optionCount - 1) * (12.0 * ui));
            // Espace souhaité sous le bloc 3 (juste milieu)
            final double bottomGap = math.max(64.0 * ui, m.box.height * 0.08);
            // Hauteur approximative du titre (2 lignes max)
            final double titleHeightApprox = (titleFont * 2.0 * 1.15);
            final double usedBeforeSpacer = (80.0 * ui) + titleTopSpacer + titleHeightApprox;
            final double answersTopSpacer = m.isTablet
                ? ((m.box.height - approxAnswersHeight - bottomGap) - usedBeforeSpacer).clamp(200.0 * ui, 480.0 * ui)
                : 320.0 * ui;
            final double answerHeight = 50.0 * ui;
            final double answerFont = 22.0 * ui;
            // Rayon des coins proportionnel à la taille de l'image - juste milieu
            final double imageRadius = m.isTablet
                ? (imageWidth * 0.055).clamp(21.0, 38.0)
                : 18.0;

            return Stack(
              children: [
            // Boutons de test discrets (à enlever en production)
            if (kDebugMode) ...[
              Positioned(
                top: 180,
                left: 20,
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () => _testCorrectAnswer(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFABC270),
                          padding: EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('✓', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () => _testWrongAnswer(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC27070),
                          padding: EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('✗', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Effet d'auréole animé: se révèle du bas vers le haut
            if (_showFeedback)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowController!,
                  builder: (context, child) {
                    final double t = _glowAnimation?.value ?? _glowController!.value;
                    // Intensité lumineuse progressive, plus douce au départ
                    final double intensity = Curves.easeIn.transform(t).clamp(0.0, 1.0);
                    final bool isCorrect = _selectedAnswer == question.correctAnswer;
                    final double boost = isCorrect ? 1.15 : 1.0; // léger boost pour le vert uniquement
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: ShaderMask(
                        shaderCallback: (Rect rect) {
                          final double revealRadius = (0.001 + 1.8 * t).clamp(0.0, 1.8);
                          const double feather = 0.28; // bords très adoucis
                          final double innerStop = (1.0 - feather).clamp(0.0, 1.0);
                          return RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: revealRadius,
                            colors: const [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, innerStop, 1.0],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.bottomCenter,
                              radius: 1.8,
                              colors: [
                                (isCorrect ? const Color(0xFF6A994E) : const Color(0xFFBC4749))
                                    .withValues(alpha: math.min(1.0, 0.35 * intensity * boost)),
                                (isCorrect ? const Color(0xFF6A994E) : const Color(0xFFBC4749))
                                    .withValues(alpha: math.min(1.0, 0.22 * intensity * boost)),
                                (isCorrect ? const Color(0xFF6A994E) : const Color(0xFFBC4749))
                                    .withValues(alpha: math.min(1.0, 0.12 * intensity * boost)),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.3, 0.6, 0.9],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Zone supérieure avec bouton échappe
            Positioned(
              top: topButtonsTop,
              left: topButtonsLeft,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Quitter le quiz
                      _exitQuiz();
                    },
                    child: SvgPicture.asset(
                      "assets/Images/cross.svg",
                      width: 30 * ui,
                      height: 30 * ui,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF473C33),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 20 * ui),
                  
                  // Bouton de test caché (pour simuler une réussite)
                  GestureDetector(
                    onTap: _simulateQuizSuccess,
                    child: Container(
                      width: 100 * ui,
                      height: 32 * ui,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange, width: 1.5 * ui),
                      ),
                      child: const Center(
                        child: Text(
                          '🎯 Test',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Icône de vie avec compteur en haut à droite
            Positioned(
              top: livesTop,
              right: livesRight,
              child: _LivesDisplayWidget(
                lives: _visibleLives,
                isSyncing: _isLivesSyncing,
                uiScale: ui,
              ),
            ),
            

            
            // Compteur de questions centré horizontalement en haut
            Align(
              alignment: Alignment.topCenter,
        child: Padding(
                padding: EdgeInsets.only(top: questionCounterTop),
                child: Opacity(
                  opacity: 0.6,
                  child: Text(
                    '${_currentQuestionIndex + 1} sur ${_questions.length}',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 20 * ui,
                      fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                  ),
                ),
              ),
            ),
            
            // Barre de progression animée (plus épaisse + barre intérieure en relief)
            Positioned(
              top: progressTop,
              left: progressSide,
              right: progressSide,
              child: Column(
                children: [
                  SizedBox(height: 8 * ui),
                  Center(
                    child: SizedBox(
                      width: progressWidth,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 450),
                        tween: Tween<double>(
                          begin: _progressFrom,
                          end: _progressTo,
                        ),
                        onEnd: () {
                          _progressFrom = _progressTo;
                          _triggerProgressBurst(progressWidth * _progressTo);
                        },
                        builder: (context, value, child) {
                          final double fillWidth = progressWidth * value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Barre (track + remplissage) avec clip uniquement sur la barre
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    // Track
                                    Container(
                                      width: progressWidth,
                                      height: progressHeight,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF473C33),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    // Remplissage
                                    SizedBox(
                                      width: fillWidth,
                                      height: progressHeight,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFABC270),
                                              ),
                                            ),
                                            Positioned(
                                              left: 4,
                                              right: 4,
                                              top: 3.5 * ui,
                                              child: Container(
                                                height: 3.5 * ui,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFC2D78D),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Peinture des gouttes en dehors de la barre (overlay non clipé)
                              Positioned(
                                left: 0,
                                top: -18 * ui,
                                width: progressWidth,
                                height: 50 * ui,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _DropletPainter(
                                      droplets: _droplets,
                                      t: _progressBurstController?.value ?? 0.0,
                                      originX: fillWidth,
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
                  SizedBox(height: 8 * ui),
                ],
              ),
            ),
            
            // Bouton audio en overlay (position fixe)
            Positioned(
              top: audioTop,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleAudio,
                  child: _AudioAnimationWidget(
                    isOn: _audioAnimationOn,
                    size: audioSize,
                  ),
                ),
              ),
            ),
            
            // Image de la bonne réponse en overlay (par-dessus le bouton audio)
            Positioned(
              top: audioTop,
              left: 0,
              right: 0,
              child: Center(
                                  child: Builder(
                  builder: (context) {
                    return IgnorePointer(
                      ignoring: !_showCorrectAnswerImage, // Ignorer les interactions quand l'image n'est pas visible
                      child: _showCorrectAnswerImage
                          ? Builder(
                              builder: (context) {
                                // Déterminer la couleur du cadre selon la réponse
                                final bool isCorrect = _selectedAnswer == _questions[_currentQuestionIndex].correctAnswer;
                                final Color borderColor = isCorrect 
                                    ? const Color(0xFFABC270) // Vert pour bonne réponse
                                    : const Color(0xFFC27070); // Rouge pour mauvaise réponse
                                
                                // Widget complet préparé d'avance pour apparition instantanée
                                final Widget fullElement = SizedBox(
                                  width: imageWidth,
                                  height: imageHeight,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Contour en arrière-plan - positionné précisément
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(imageRadius),
                                            border: Border.all(
                                              color: borderColor,
                                              width: 10.0,
                                            ),
                                            // Ombre subtile pour les mauvaises réponses (flat design)
                                            boxShadow: !isCorrect ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                offset: const Offset(3, 3),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                              BoxShadow(
                                                color: borderColor.withValues(alpha: 0.2),
                                                offset: const Offset(1, 1),
                                                blurRadius: 3,
                                                spreadRadius: 0,
                                              ),
                                            ] : null,
                                          ),
                                          // Effet d'ombrage flat design pour les mauvaises réponses
                                          child: !isCorrect ? ClipRRect(
                                            borderRadius: BorderRadius.circular(imageRadius),
                                            child: Stack(
                                              children: [
                                                // Ombrage général subtil
                                                AnimatedBuilder(
                                                  animation: _shineController!,
                                                  builder: (context, child) {
                                                    final progress = _shineController!.value;
                                                    // Mouvement cyclique très subtil
                                                    final offset = math.sin(progress * math.pi * 2) * 0.5;
                                                    
                                                    return Positioned.fill(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(imageRadius - 10),
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                            colors: [
                                                              Colors.transparent,
                                                              const Color(0xFFC87E7E).withValues(alpha: 0.25 + offset * 0.1),
                                                              const Color(0xFFC87E7E).withValues(alpha: 0.4 + offset * 0.15),
                                                              const Color(0xFFC87E7E).withValues(alpha: 0.2 + offset * 0.08),
                                                            ],
                                                            stops: const [0.0, 0.3, 0.6, 1.0],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                // Ligne courbe dans le coin haut-droite
                                                Positioned(
                                                  top: 12,
                                                  right: 12,
                                                  child: AnimatedBuilder(
                                                    animation: _shineController!,
                                                    builder: (context, child) {
                                                      final progress = _shineController!.value;
                                                      final shimmer = math.sin(progress * math.pi * 2) * 0.4 + 0.6;
                                                      
                                                      return CustomPaint(
                                                        size: Size(40, 40),
                                                        painter: _CurvedLinePainter(
                                                          color: const Color(0xFFC87E7E).withValues(alpha: shimmer),
                                                          radius: imageRadius * 0.3,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                // Point décoratif
                                                Positioned(
                                                  top: 22,
                                                  right: 18,
                                                  child: AnimatedBuilder(
                                                    animation: _shineController!,
                                                    builder: (context, child) {
                                                      final progress = _shineController!.value;
                                                      final shimmer = math.sin(progress * math.pi * 2 + 1) * 0.3 + 0.7;
                                                      
                                                      return Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFC87E7E).withValues(alpha: shimmer),
                                                          shape: BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: const Color(0xFFC87E7E).withValues(alpha: shimmer * 0.5),
                                                              blurRadius: 3,
                                                              spreadRadius: 1,
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ) : null,
                                        ),
                                      ),
                                      // Effet de brillance UNIQUEMENT pour les bonnes réponses - 2 bandes
                                      if (isCorrect)
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(imageRadius),
                                            child: AnimatedBuilder(
                                              animation: _shineController!,
                                              builder: (context, child) {
                                                final progress = _shineController!.value;
                                                
                                                // Bande 1 - première bande verte simple
                                                final band1Start = 0.0;
                                                final band1End = 0.6;
                                                final band1Progress = ((progress - band1Start) / (band1End - band1Start)).clamp(0.0, 1.0);
                                                final position1 = Tween<double>(begin: -0.8, end: 1.8)
                                                    .transform(Curves.easeInOut.transform(band1Progress));
                                                
                                                // Bande 2 - deuxième bande avec décalage
                                                final band2Start = 0.2; // Décalage de 20%
                                                final band2End = 0.8;
                                                final band2Progress = ((progress - band2Start) / (band2End - band2Start)).clamp(0.0, 1.0);
                                                final position2 = Tween<double>(begin: -0.8, end: 1.8)
                                                    .transform(Curves.easeInOut.transform(band2Progress));
                                                
                                                return Stack(
                                                  children: [
                                                    // Bande 1 - De haut-gauche à bas-droite
                                                    if (band1Progress > 0)
                                                      Positioned(
                                                        left: -imageWidth * 0.3 + (position1 * (imageWidth + imageWidth * 0.6)),
                                                        top: -imageHeight * 0.3 + (position1 * (imageHeight + imageHeight * 0.6)),
                                                        child: Transform.rotate(
                                                          angle: math.atan2(imageHeight, imageWidth), // Angle exact de la diagonale
                                                          child: Container(
                                                            width: imageWidth * 0.15,
                                                            height: math.sqrt(imageWidth * imageWidth + imageHeight * imageHeight),
                                                            color: const Color(0xFFD2DBB2).withValues(alpha: 0.7),
                                                          ),
                                                        ),
                                                      ),
                                                    // Bande 2 - Même trajectoire avec décalage
                                                    if (band2Progress > 0)
                                                      Positioned(
                                                        left: -imageWidth * 0.3 + (position2 * (imageWidth + imageWidth * 0.6)),
                                                        top: -imageHeight * 0.3 + (position2 * (imageHeight + imageHeight * 0.6)),
                                                        child: Transform.rotate(
                                                          angle: math.atan2(imageHeight, imageWidth), // Même angle exact
                                                          child: Container(
                                                            width: imageWidth * 0.12,
                                                            height: math.sqrt(imageWidth * imageWidth + imageHeight * imageHeight),
                                                            color: const Color(0xFFD2DBB2).withValues(alpha: 0.6),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      // Image au-dessus du contour - positionnée précisément
                                      Positioned(
                                        left: 10.0,
                                        top: 10.0,
                                        right: 10.0,
                                        bottom: 10.0,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(imageRadius - 10.0),
                                          clipBehavior: Clip.antiAliasWithSaveLayer,
                                          child: _buildCachedImage(fit: BoxFit.cover),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                
                                // Animation d'apparition sur l'élément complet
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutBack,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: fullElement,
                                    );
                                  },
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
            
                        // Contenu principal du quiz
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0 * ui, vertical: 0.0),
              child: Column(
                children: [
                  // Espace supplémentaire pour éviter le chevauchement avec la barre de progression
                  SizedBox(height: 80 * ui),
              
                  SizedBox(height: titleTopSpacer),
              
              // Titre principal
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: m.isTablet ? (m.maxWidth * 0.68) : double.infinity,
                  ),
                  child: Text(
                'Quel oiseau se cache derrière ce son ?',
                                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: titleFont,
                    fontWeight: FontWeight.w900, // Plus gras que bold
                    color: Color(0xFF344356),
                    letterSpacing: 0.5, // Espacement entre les lettres
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1 * ui),
                        blurRadius: 2 * ui,
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                      ),
                    ],
                  ),
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 2,
                ),
              ),
              ),
              
                  const SizedBox(height: 0),
              
              const SizedBox(height: 0),
              
              SizedBox(height: answersTopSpacer),
              
              // Options de réponse positionnées vers le centre de l'écran
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 5 * ui),
                  
                  ...List.generate(question.options.length, (optionIndex) {
                    final option = question.options[optionIndex];
                    final isSelected = _selectedAnswer == option;
                    final isCorrectAnswer = option == question.correctAnswer;

                    Color backgroundColor = Colors.white;
                    Color borderColor = const Color(0xFFE0E0E0);
                    Color textColor = Colors.black;

                    if (_showFeedback) {
                      if (isSelected) {
                        if (isCorrectAnswer) {
                          backgroundColor = const Color(0xFF6A994E);
                          borderColor = const Color(0xFF6A994E);
                          textColor = Colors.white;
                        } else {
                          backgroundColor = const Color(0xFFBC4749);
                          borderColor = const Color(0xFFBC4749);
                          textColor = Colors.white;
                        }
                      } else if (isCorrectAnswer) {
                        backgroundColor = const Color(0xFF6A994E).withValues(alpha: 0.2);
                        borderColor = const Color(0xFF6A994E);
                      }
                    }

                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.0 * ui),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 250),
                        tween: Tween<double>(
                          begin: 1.0,
                          end: (isSelected && _showFeedback) ? 1.05 : 1.0,
                        ),
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: _showFeedback ? null : () => _onAnswerSelected(option),
                          child: Container(
                            height: answerHeight,
                            width: m.isTablet ? (m.maxWidth * 0.85) : MediaQuery.of(context).size.width * 0.85,
                            padding: EdgeInsets.symmetric(horizontal: 16 * ui),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 2 * ui),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromRGBO(0, 0, 0, 0.04),
                                  blurRadius: 4 * ui,
                                  offset: Offset(0, 2 * ui),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: answerFont,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              
              SizedBox(height: 20 * ui),
            ],
          ),
            ),
          ],
        );
          },
        ),
      ),
    );
  }

  Future<void> _loadQuiz() async {
    try {
      // 1) Essayer de charger la mission depuis Firestore (collection 'missions')
      try {
        final doc = await FirebaseFirestore.instance.collection('missions').doc(widget.missionId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final questions = await QuizGenerator.generateQuizFromFirestoreAndCsv(widget.missionId, data);
          if (!mounted) return;
          setState(() {
            _questions = questions;
            _isLoading = false;
            _currentQuestionIndex = 0;
            _score = 0;
            _audioAnimationOn = true;
            _progressFrom = 0.0;
            _progressTo = _questions.isNotEmpty ? (1.0 / _questions.length) : 0.0;
            _prepareDroplets();
          });
          if (questions.isNotEmpty) {
            _loadAndPlayAudio(questions[0].audioUrl);
          }
          return;
        }
      } catch (_) {
        // Si Firestore échoue, on tombera sur le fallback CSV
      }

      // 2) Fallback: charger depuis le CSV d'assets
      final questions = await QuizGenerator.generateQuizFromCsv(widget.missionId);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _score = 0;
        _audioAnimationOn = true; // Animation "on" au démarrage
        _progressFrom = 0.0;
        _progressTo = _questions.isNotEmpty ? (1.0 / _questions.length) : 0.0;
        _prepareDroplets();
      });
      
      // Charger et lancer l'audio de la première question
      if (questions.isNotEmpty) {
        _loadAndPlayAudio(questions[0].audioUrl);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorDialog('Erreur lors du chargement du quiz: $e');
    }
  }

  Future<void> _loadAndPlayAudio(String audioUrl) async {
    try {
      if (audioUrl.isEmpty) {
        _showAudioErrorDialog('Aucun fichier audio disponible pour cette question.');
        return;
      }
      
      final currentQuestion = _questions[_currentQuestionIndex];
      final birdName = currentQuestion.correctAnswer;
      final preloadedAudio = MissionPreloader.getPreloadedAudio(birdName);
      
      if (preloadedAudio != null) {
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(preloadedAudio.audioSource!);
        
        _isAudioLooping = true;
        await _playAudioAtRandomPosition();
        
        if (!mounted) return;
        setState(() {
          _currentAudioUrl = audioUrl;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        
        _isAudioLooping = true;
        await _playAudioAtRandomPosition();
        
        if (!mounted) return;
        setState(() {
          _currentAudioUrl = audioUrl;
        });
      }
    } catch (e) {
      _showAudioErrorDialog('Impossible de charger l\'audio. Vérifiez votre connexion internet.');
    }
  }
  


  Future<void> _playAudioAtRandomPosition() async {
    try {
      if (_audioPlayer.audioSource == null) {
        return;
      }
      
      await _audioPlayer.play();
      
      final duration = _audioPlayer.duration;
      if (duration != null && duration.inSeconds > 0) {
        final maxStartPosition = (duration.inSeconds * 0.7).round();
        final randomPosition = maxStartPosition > 0 
            ? Duration(seconds: _getRandomInt(0, maxStartPosition))
            : Duration.zero;
        
        if (randomPosition < duration) {
          await _audioPlayer.seek(randomPosition);
        }
      }
    } catch (e) {
      try {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      } catch (fallbackError) {
        // Erreur fallback ignorée
      }
    }
  }

  Future<void> _precacheAnswerImage(String url) async {
    if (url.isEmpty) return;
    final normalized = _normalizeImageUrl(url);
    // Choisir correctement le provider (réseau vs asset local)
    final ImageProvider provider = (normalized.startsWith('http://') || normalized.startsWith('https://'))
        ? NetworkImage(normalized)
        : AssetImage(normalized) as ImageProvider;
    // Utiliser precacheImage pour charger avant affichage, ignorer les erreurs
    try {
      await precacheImage(provider, context);
    } catch (_) {}
  }

  // Préchargement de la prochaine question
  Future<void> _preloadNextQuestion() async {
    if (_isPreloadingNext || _questions.isEmpty) return;
    
    final nextIndex = _currentQuestionIndex + 1;
    if (nextIndex >= _questions.length) return; // Pas de question suivante
    
    _isPreloadingNext = true;
    
    try {
      final nextQuestion = _questions[nextIndex];
      
      // 1. Précharger l'audio de la prochaine question
      if (nextQuestion.audioUrl.isNotEmpty) {
        _nextAudioUrl = nextQuestion.audioUrl;
        // Précharger l'audio sans le jouer
        try {
          final tempPlayer = AudioPlayer();
          await tempPlayer.setUrl(_nextAudioUrl);
          await tempPlayer.dispose();
        } catch (_) {}
      }
      
      // 2. Précharger l'image de la bonne réponse de la prochaine question
      String nextImageUrl = '';
      try {
        final birdData = MissionPreloader.getBirdData(nextQuestion.correctAnswer)
            ?? MissionPreloader.findBirdByName(nextQuestion.correctAnswer);
        if (birdData != null && birdData.urlImage.isNotEmpty) {
          nextImageUrl = birdData.urlImage;
        }
      } catch (_) {}
      
      if (nextImageUrl.isNotEmpty) {
        _nextImageUrl = nextImageUrl;
        // Précharger l'image
        await _precacheAnswerImage(_nextImageUrl);
      }
      
    } catch (e) {
      // Gérer silencieusement les erreurs de préchargement
    } finally {
      _isPreloadingNext = false;
    }
  }

  Future<void> _setAnswerImageSafely(String url) async {
    if (!mounted) return;
    
    final normalizedUrl = _normalizeImageUrl(url);
    
    // Utiliser l'image préchargée si disponible
    if (_nextImageUrl == normalizedUrl && _nextImageUrl.isNotEmpty) {
      // L'image est déjà préchargée, affichage instantané
      setState(() {
        _correctAnswerImageUrl = normalizedUrl;
        _showCorrectAnswerImage = true;
      });
      // Reset l'image préchargée après utilisation
      _nextImageUrl = '';
    } else {
      // Afficher immédiatement l'image; précache en arrière-plan pour les prochaines fois
      setState(() {
        _correctAnswerImageUrl = normalizedUrl;
        // Toujours afficher le conteneur image; _buildCachedImage gère les cas vides/erreurs
        _showCorrectAnswerImage = true;
      });
      // Lancer le précache sans bloquer ni re-set l'état ensuite
      _precacheAnswerImage(_correctAnswerImageUrl);
    }
  }

  Future<void> _restartAudioAtRandomPosition() async {
    if (!_isAudioLooping || !mounted) {
      return;
    }
    
    try {
      await _playAudioAtRandomPosition();
    } catch (e) {
      // Erreur ignorée
    }
  }

  int _getRandomInt(int min, int max) {
    return min + (DateTime.now().millisecondsSinceEpoch % (max - min + 1));
  }

  void _prepareDroplets() {
    _droplets.clear();
    // 2 à 4 gouttes maximum, bien visibles, légèrement dispersées
    final int count = 2 + (DateTime.now().microsecondsSinceEpoch % 2); // 2..3
    final randomSeed = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < count; i++) {
      // Trois profils d'angles typiques vers la droite: léger haut, milieu, léger bas
      final List<double> baseAnglesDeg = [-8, 8, 22];
      final baseDeg = baseAnglesDeg[i % baseAnglesDeg.length];
      final jitter = ((randomSeed >> (i % 8)) & 3) - 1.5; // bruit léger -1.5..+1.5
      final angle = ((baseDeg + jitter) / 180.0) * math.pi;
      // Vitesse courte (proche), avec petite variation
      final speed = 32.0 + ((randomSeed >> (i % 6)) & 5) * 2.0; // ~32..42
      final lifespan = 0.5; // rapide
      // Décalage vertical initial pour varier haut/centre/bas (faible amplitude)
      final yOffsets = [-6.0, 0.0, 6.0];
      final originOffsetY = yOffsets[(i + (randomSeed % 3)) % yOffsets.length];
      // Taille aléatoire légère
      final baseRadius = 1.6 + ((randomSeed >> (i % 5)) & 2) * 0.4; // ~1.6..2.4
      _droplets.add(_ProgressDroplet(
        angle: angle,
        speed: speed,
        lifespan: lifespan,
        color: const Color(0xFFABC270),
        originOffsetY: originOffsetY,
        baseRadius: baseRadius,
      ));
    }
  }

  void _triggerProgressBurst(double xPosition) {
    if (_droplets.isEmpty || _progressBurstController == null) return;
    // Rejouer l'animation depuis 0
    _progressBurstController!.forward(from: 0.0);
  }

  Future<void> _toggleAudio() async {
    try {
      final playingState = _audioPlayer.playing;
      
      setState(() {
        _audioAnimationOn = !_audioAnimationOn;
      });
      
      if (playingState) {
        _isAudioLooping = false;
        
        _audioPlayer.pause().catchError((e) {
          // Erreur ignorée
        });
      } else {
        if (_currentAudioUrl.isNotEmpty) {
          _isAudioLooping = true;
          
          _playAudioAtRandomPosition().catchError((e) {
            // Erreur ignorée
          });
        } else {
          _showAudioErrorDialog('Aucun audio disponible pour cette question.');
        }
      }
    } catch (e) {
      _showAudioErrorDialog('Erreur lors de la lecture audio. Veuillez réessayer.');
    }
  }

  Future<void> _stopAudio() async {
    try {
      _isAudioLooping = false;
      
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      // Erreur ignorée
    }
  }

  Future<void> _onAnswerSelected(String selectedAnswer) async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = selectedAnswer == currentQuestion.correctAnswer;
    
    await _stopAudio();
    
    if (!mounted) return;
    
    String imageUrl = '';
    try {
      // 1) Priorité: mission Firestore si dispo dans la question (audioUrl ou métadonnées annexes)
      // Ici on n'a que audioUrl côté question; on reste sur Birdify cache pour image
      // 2) Recherche stricte puis tolérante (accents/casse)
      final birdData = MissionPreloader.getBirdData(currentQuestion.correctAnswer)
          ?? MissionPreloader.findBirdByName(currentQuestion.correctAnswer);
      if (birdData != null && birdData.urlImage.isNotEmpty) {
        imageUrl = birdData.urlImage;
      } else {
        try {
          await MissionPreloader.loadBirdifyData();
          final retryBirdData = MissionPreloader.getBirdData(currentQuestion.correctAnswer)
              ?? MissionPreloader.findBirdByName(currentQuestion.correctAnswer);
          if (retryBirdData != null && retryBirdData.urlImage.isNotEmpty) {
            imageUrl = retryBirdData.urlImage;
          }
        } catch (_) {}
      }
    } catch (_) {}
    
    // Récupérer au mieux l'URL audio pour le récap (priorité: question.audioUrl, sinon cache birds)
    String recapAudioUrl = currentQuestion.audioUrl;
    if (recapAudioUrl.isEmpty) {
      try {
        final birdData = MissionPreloader.getBirdData(currentQuestion.correctAnswer);
        if (birdData != null && birdData.urlMp3.isNotEmpty) {
          recapAudioUrl = birdData.urlMp3;
        }
      } catch (_) {}
    }

    // Enregistrer l'entrée du récap (dans l'ordre des questions)
    _recapEntries.add(
      AnswerRecap(
        questionBird: currentQuestion.correctAnswer,
        selected: selectedAnswer,
        isCorrect: isCorrect,
        audioUrl: recapAudioUrl,
      ),
    );

    setState(() {
      _selectedAnswer = selectedAnswer;
      _showFeedback = true;
      // défère l'affichage de l'image après précache via _setAnswerImageSafely
      if (isCorrect) {
        _score++;
      } else {
        _visibleLives--;
        _wrongBirds.add(selectedAnswer);
        if (!_wrongBirds.contains(currentQuestion.correctAnswer)) {
          _wrongBirds.add(currentQuestion.correctAnswer);
        }
        _syncLivesImmediately();
      }
    });
    _glowController?.forward(from: 0.0);

    // Lancer le chargement/affichage sécurisé de l'image sans bloquer l'UI
    _setAnswerImageSafely(imageUrl);

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!context.mounted) return;
    
    if (_visibleLives <= 0) {
      _onQuizFailed();
    } else {
      _goToNextQuestion();
    }
  }

  Future<void> _simulateQuizSuccess() async {
    if (!mounted) return;

    await _stopAudio();

    setState(() {
      _score = 10; // Simuler un score de 10
      _visibleLives = 5; // Réinitialiser les vies
      _isLivesSyncing = false; // Désactiver la synchronisation
      // Progresser directement à 100%
      _progressFrom = _progressTo;
      _progressTo = 1.0;
      _prepareDroplets();
    });

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!context.mounted) return;

    _onQuizCompleted();
  }

  Future<void> _syncLivesImmediately() async {
    if (_isLivesSyncing) {
      return;
    }
    
    _isLivesSyncing = true;
    
    try {
      final uid = UserOrchestra.currentUserId;
      if (uid != null) {
        await UserOrchestra.syncLivesAfterQuiz(uid, _visibleLives);
      }
    } catch (e) {
      // Ne pas faire échouer le quiz pour une erreur de synchronisation
    } finally {
      _isLivesSyncing = false;
    }
  }

  // Méthodes de test pour les animations (à enlever en production)
  void _testCorrectAnswer() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    final currentQuestion = _questions[_currentQuestionIndex];
    _onAnswerSelected(currentQuestion.correctAnswer);
  }

  void _testWrongAnswer() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    final currentQuestion = _questions[_currentQuestionIndex];
    final wrongAnswers = currentQuestion.options.where((option) => option != currentQuestion.correctAnswer).toList();
    if (wrongAnswers.isNotEmpty) {
      _onAnswerSelected(wrongAnswers.first);
    }
  }



  Widget _buildCachedImage({BoxFit fit = BoxFit.cover}) {
    if (_correctAnswerImageUrl.isEmpty) {
      return Container(
        width: 300,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text(
                'Image non disponible',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // Choisir asset vs réseau
    final String url = _correctAnswerImageUrl;
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      return Image.asset(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            ),
          );
        },
      );
    }
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        );
      },
    );
  }

  String _normalizeImageUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    // Traitement chemin relatif asset
    if (u.startsWith('assets/')) return u;
    // Certaines sources stockent des chemins relatifs sans le préfixe assets/
    return 'assets/$u';
  }

  void _goToNextQuestion() async {
    if (_currentQuestionIndex >= _questions.length - 1) {
      _onQuizCompleted();
      return;
    }
    
    _isAudioLooping = false;
    
    final nextQuestion = _questions[_currentQuestionIndex + 1];
    
    _loadAndPlayAudio(nextQuestion.audioUrl);
    
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _showFeedback = false;
      _showCorrectAnswerImage = false;
      _correctAnswerImageUrl = '';
      
      _audioAnimationOn = true;
      // Mettre à jour la progression: aller de la valeur atteinte vers la suivante
      final total = _questions.isNotEmpty ? _questions.length : 1;
      _progressFrom = _progressTo;
      _progressTo = (_currentQuestionIndex + 1) / total;
      // Préparer quelques gouttes pour la prochaine animation
      _prepareDroplets();
    });
    _glowController?.stop();
    _glowController?.value = 0.0;
    
    // Déclencher le préchargement de la prochaine question
    Future.microtask(() => _preloadNextQuestion());
  }

  void _exitQuiz() async {
    if (!mounted) return;
    
    await _stopAudio();
    
    if (!_isLivesSyncing) {
      try {
        final uid = UserOrchestra.currentUserId;
        if (uid != null) {
          await UserOrchestra.syncLivesAfterQuiz(uid, _visibleLives);
        }
      } catch (e) {
        // Continuer même en cas d'erreur
      }
    }
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MissionUnloadingScreen(
            livesRemaining: _visibleLives,
            missionId: widget.missionId,
          ),
        ),
      );
    }
  }



  void _onQuizCompleted() async {
    if (!mounted) return;

    await _stopAudio();

    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (context) => MissionUnloadingScreen(
          livesRemaining: _visibleLives,
          missionId: widget.missionId,
          score: _score,
          totalQuestions: _questions.length,
          mission: widget.mission,
          wrongBirds: _wrongBirds,
          recap: _recapEntries,
        ),
      ),
    );
  }

  void _onQuizFailed() async {
    if (!mounted) return;

    await _stopAudio();

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Quiz échoué !',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
            color: Color(0xFFBC4749),
          ),
        ),
        content: Text(
          'Vous avez perdu toutes vos vies !\nScore final : $_score/${_questions.length}',
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MissionUnloadingScreen(
                    livesRemaining: _visibleLives,
                    missionId: widget.missionId,
                  ),
                ),
              );
            },
            child: const Text(
              'Retour',
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: Color(0xFF6A994E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erreur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                'Détails techniques:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mission ID: ${widget.missionId}\n'
                'Chemin attendu: assets/Missionhome/questionMission/${widget.missionId}.csv',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MissionUnloadingScreen(
                      livesRemaining: _visibleLives,
                      missionId: widget.missionId,
                    ),
                  ),
                );
              }
            },
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  void _showAudioErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erreur Audio'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MissionUnloadingScreen(
                      livesRemaining: _visibleLives,
                      missionId: widget.missionId,
                    ),
                  ),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Intercepter le bouton retour du téléphone
  
          _exitQuiz();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        body: _isLoading
            ? const SizedBox.shrink()
            : _questions.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune question disponible',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 18,
                        color: Color(0xFF386641),
                      ),
                    ),
                  )
                : PageTransitionSwitcher(
                    transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                      return FadeThroughTransition(
                        animation: primaryAnimation,
                        secondaryAnimation: secondaryAnimation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_currentQuestionIndex),
                      child: _buildQuestionPage(
                        _questions[_currentQuestionIndex],
                        _currentQuestionIndex,
                      ),
                    ),
                  ),
      ),
    );
  }
}

// CustomPainter pour la ligne courbe décorative
class _CurvedLinePainter extends CustomPainter {
  final Color color;
  final double radius;
  
  _CurvedLinePainter({required this.color, required this.radius});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    
    // Ligne qui épouse la courbure du coin haut-droite
    // Commence du coin et suit la courbe
    path.moveTo(size.width * 0.7, 0);
    path.quadraticBezierTo(
      size.width, 0, // Point de contrôle au coin exact
      size.width, size.height * 0.3, // Point final suivant la courbe
    );
    
    // Deuxième courbe pour plus de richesse
    path.moveTo(size.width * 0.5, size.height * 0.05);
    path.quadraticBezierTo(
      size.width * 0.85, size.height * 0.05,
      size.width * 0.9, size.height * 0.15,
    );
    
    // Petite ligne supplémentaire pour plus de détail
    path.moveTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.12);
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressDroplet {
  final double angle; // direction en radians
  final double speed; // px/s approximatif
  final double lifespan; // secondes
  final Color color;
  final double originOffsetY; // décalage vertical initial (px)
  final double baseRadius; // rayon de base (px)
  _ProgressDroplet({
    required this.angle,
    required this.speed,
    required this.lifespan,
    required this.color,
    required this.originOffsetY,
    required this.baseRadius,
  });
}

class _DropletPainter extends CustomPainter {
  final List<_ProgressDroplet> droplets;
  final double t; // 0.0 -> 1.0 progression de l'animation
  final double originX; // position de l'extrémité de la barre (0..300)
  _DropletPainter({required this.droplets, required this.t, this.originX = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (droplets.isEmpty || t <= 0) return;
    final origin = Offset(originX, size.height / 2); // extrémité de la barre
    for (final d in droplets) {
      final double life = (t).clamp(0.0, 1.0);
      // Distance en fonction de la vie
      final double dist = d.speed * life * 0.22; // très proche de la barre
      final dx = math.cos(d.angle) * dist;
      final dy = math.sin(d.angle) * dist * 0.7; // légère présence haut/bas
      final pos = origin + Offset(dx, dy + d.originOffsetY);

      // Moins présent visuellement à gauche (dx<0)
      final double baseAlpha = (1.0 - life).clamp(0.0, 1.0);
      final double sideFactor = dx < 0 ? 0.7 : 1.0; // côté gauche moins pénalisé
      final double alpha = (baseAlpha * sideFactor).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = d.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      // Taille décroissante et légère ovalisation au cours du temps
      final double r = d.baseRadius + (d.baseRadius * 0.7) * (1.0 - life); // base size
      final double ovalFactor = 1.0 + 0.18 * life; // commence rond (1.0) → légèrement ovale
      final double rx = r * ovalFactor;      // rayon dans l'axe du déplacement
      final double ry = r * (2.0 - ovalFactor); // compense légèrement sur l'axe perpendiculaire

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(d.angle);
      final Rect ovalRect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
      canvas.drawOval(ovalRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DropletPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.droplets != droplets;
  }
}

class _AudioAnimationWidget extends StatefulWidget {
  final bool isOn;
  final double? size;
  
  const _AudioAnimationWidget({
    required this.isOn,
    this.size,
  });

  @override
  State<_AudioAnimationWidget> createState() => _AudioAnimationWidgetState();
}

class _AudioAnimationWidgetState extends State<_AudioAnimationWidget> {
  Widget? _onAnimation;
  Widget? _offAnimation;
  bool _animationsInitialized = false;
  // Garder les animations qui tournent mais optimiser le switch

  @override
  void initState() {
    super.initState();
    _initializeAnimationsIfNeeded();
  }

  void _initializeAnimationsIfNeeded() {
    if (_animationsInitialized) return;
    // Précharger et conserver les deux animations
    _onAnimation = rive.RiveAnimation.asset(
      'assets/animations/audio_on.riv',
      fit: BoxFit.contain,
    );
    _offAnimation = rive.RiveAnimation.asset(
      'assets/animations/audio_off.riv',
      fit: BoxFit.contain,
    );
    _animationsInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _initializeAnimationsIfNeeded();
    
    // Switch ultra-rapide avec AnimatedSwitcher mais durée minimale
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1), // Presque instantané
      switchInCurve: Curves.linear, // Pas de courbe d'animation
      switchOutCurve: Curves.linear,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Transition directe sans effet
        return child;
      },
      child: SizedBox(
        key: ValueKey('audio_${widget.isOn ? 'on' : 'off'}'),
        width: widget.size ?? 160,
        height: widget.size ?? 160,
        child: widget.isOn 
            ? _onAnimation!
            : _offAnimation!,
      ),
    );
  }
}

class _LivesDisplayWidget extends StatefulWidget {
  final int lives;
  final bool isSyncing;
  final double uiScale;
  
  const _LivesDisplayWidget({
    required this.lives,
    required this.isSyncing,
    this.uiScale = 1.0,
  });

  @override
  State<_LivesDisplayWidget> createState() => _LivesDisplayWidgetState();
}

 

class _LivesDisplayWidgetState extends State<_LivesDisplayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void didUpdateWidget(_LivesDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.lives != oldWidget.lives) {
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double ui = widget.uiScale;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: SizedBox(
            width: 80 * ui,
            height: 80 * ui,
            child: Stack(
              children: [
                Image.asset(
                  'assets/Images/Bouton/barvie.png',
                  width: 100 * ui,
                  height: 100 * ui,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80 * ui,
                      height: 80 * ui,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(188, 71, 73, 0.2),
                        borderRadius: BorderRadius.circular(40 * ui),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFFBC4749),
                        size: 40,
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(18 * ui, -0.5 * ui),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        widget.lives.toString(),
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 34 * ui,
                          fontWeight: FontWeight.w900,
                          color: widget.lives <= 1 
                              ? const Color(0xFFBC4749)
                              : const Color(0xFF473C33),
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        );
      },
    );
  }
}