import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../services/dev_tools_service.dart';
// import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import supprimé en double
import '../../models/mission.dart';
import '../../ui/responsive/responsive.dart';
import '../../ui/scaffold/adaptive_scaffold.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/answer_recap.dart';
import '../../pages/home_screen.dart';
import '../../widgets/recap_button.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../../pages/RecompensesUtiles/recompenses_utiles_page.dart';
import '../../services/Users/recompenses_utiles_service.dart';
// import '../../services/Users/firestore_service.dart';
import '../Mission/communs/commun_gestion_mission.dart';

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
  final String _lottiePath = 'assets/PAGE/Score resultat/Check.json';
  Future<String>? _lottiePathFuture;
  final ScrollController _scrollController = ScrollController();
  
  // Variables pour capturer les étoiles avant et après mise à jour
  int? _starsBeforeUpdate;
  int? _starsAfterUpdate;
  final AudioPlayer _recapPlayer = AudioPlayer();
  String _recapPlayingUrl = '';
  String _recapPlayingKey = '';
  bool _recapIsPlaying = false;
  bool _recapBusy = false;
  int _lottieVersion = 0; // permet de forcer le rechargement de l'animation Lottie
  bool _showBlockBorders = false; // Nouvel état pour les bordures temporaires
  StreamSubscription<PlayerState>? _recapPlayerStateSub;
  
  // Confettis: deux animations en plein écran, la seconde démarre après 1 seconde
  final bool _showConfetti1 = true; // démarre immédiatement
  bool _showConfetti2 = false; // démarre après 1s
  int _confettiVersion = 0; // pour forcer le redémarrage des confettis
  
  // Cache pour les phrases du CSV
  Map<int, Map<String, String>>? _csvPhrases;
  
  // Variable pour forcer le refresh des messages aléatoires
  bool _forceMessageRefresh = false;
  
  // Clé unique pour forcer la reconstruction de l'anneau
  int _ringKey = 0;
  
  // Messages sélectionnés une seule fois à l'arrivée
  String? _chosenTitleMessage;
  String? _chosenSubtitleMessage;
  bool _messagesLocked = false;
  
  // Variables de test pour simuler différents scores
  int _testScore = 0;
  bool _useTestScore = false;
  final List<int> _testScores = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  int _currentTestScoreIndex = 0;

  // Services pour la navigation intelligente
  // final FirestoreService _firestoreService = FirestoreService();
  final RecompensesUtilesService _recompensesService = RecompensesUtilesService();

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
    
    // Charge les phrases du CSV
    _loadCSVPhrases();

    // Démarrer la seconde animation de confettis après 1 seconde
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _showConfetti2 = true;
      });
    });

    // Sélectionner les messages une seule fois à l'arrivée
    _selectMessagesOnce();

    // Écouter l'état du player pour tenir l'UI à jour et stopper à la fin
    _recapPlayerStateSub = _recapPlayer.playerStateStream.listen((state) {
      final bool isPlayingNow = state.playing;
      if (!mounted) return;
      if (!isPlayingNow && _recapIsPlaying) {
        setState(() {
          _recapIsPlaying = false;
        });
      } else if (isPlayingNow && !_recapIsPlaying) {
        setState(() {
          _recapIsPlaying = true;
        });
      }
      if (state.processingState == ProcessingState.completed) {
        // Assurer l'arrêt complet à la fin
        _recapPlayer.stop();
        setState(() {
          _recapIsPlaying = false;
        });
      }
    });
  }

  void _selectMessagesOnce() {
    if (_messagesLocked) return;
    final int scoreVal = _useTestScore ? _testScore : widget.score;
    final int totalVal = widget.totalQuestions;
    _chosenTitleMessage = _getTitleMessage(scoreVal, totalVal);
    _chosenSubtitleMessage = _getSubtitleMessage(scoreVal, totalVal);
    _messagesLocked = true;
  }

  /// Met à jour complètement la progression de la mission dans Firestore
  Future<void> _updateMissionStars() async {
    try {
      if (widget.mission == null) {
        if (kDebugMode) debugPrint('⚠️ Aucune mission fournie');
        return;
      }

      // 🎯 CAPTURER LES ÉTOILES AVANT mise à jour
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final progressionData = await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(currentUser.uid)
              .collection('progression_missions')
              .doc(widget.mission!.id)
              .get();
          _starsBeforeUpdate = progressionData.exists
              ? (progressionData.data()?['etoiles'] ?? 0)
              : 0;
        }
      } catch (e) {
        _starsBeforeUpdate = 0;
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

      // 🎯 CAPTURE DES ÉTOILES APRÈS MISE À JOUR
      if (kDebugMode) debugPrint('🔥🔥🔥 CAPTURE ÉTOILES APRÈS - DÉBUT 🔥🔥🔥');
      
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (kDebugMode) debugPrint('👤 Utilisateur pour capture APRÈS: ${currentUser?.uid ?? "NULL"}');
        
        if (currentUser != null) {
          if (kDebugMode) debugPrint('📡 Requête Firestore APRÈS pour ${widget.mission!.id}...');
          
          final progressionDataAfter = await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(currentUser.uid)
              .collection('progression_missions')
              .doc(widget.mission!.id)
              .get();
          
          _starsAfterUpdate = progressionDataAfter.exists 
              ? (progressionDataAfter.data()?['etoiles'] ?? 0) 
              : 0;
              
          if (kDebugMode) {
            debugPrint('📊 Progression APRÈS exists: ${progressionDataAfter.exists}');
            debugPrint('📊 Raw data APRÈS: ${progressionDataAfter.data()}');
            debugPrint('⭐⭐⭐ ÉTOILES APRÈS: $_starsAfterUpdate ⭐⭐⭐');
            debugPrint('🎯🎯🎯 COMPARAISON NAVIGATION CRITIQUE:');
            debugPrint('   - AVANT: $_starsBeforeUpdate');
            debugPrint('   - APRÈS: $_starsAfterUpdate'); 
            debugPrint('   - GAGNÉES: ${(_starsAfterUpdate ?? 0) - (_starsBeforeUpdate ?? 0)}');
            debugPrint('   - DEVRAIT ALLER AUX RÉCOMPENSES?: ${((_starsAfterUpdate ?? 0) - (_starsBeforeUpdate ?? 0)) > 0}');
          }
        } else {
          if (kDebugMode) debugPrint('❌ CurrentUser APRÈS est NULL !');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('💥 ERREUR capture APRÈS: $e');
      }
      
      // 🎯 CAPTURER LES ÉTOILES APRÈS mise à jour
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final progressionDataAfter = await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(currentUser.uid)
              .collection('progression_missions')
              .doc(widget.mission!.id)
              .get();
          _starsAfterUpdate = progressionDataAfter.exists
              ? (progressionDataAfter.data()?['etoiles'] ?? 0)
              : 0;
        }
      } catch (e) {
        _starsAfterUpdate = 0;
      }
      
      if (kDebugMode) {
        debugPrint('✅ Progression complète mise à jour pour ${widget.mission!.id}');
        debugPrint('   Score: ${widget.score}/10');
        debugPrint('   Durée: ${dureePartie.inSeconds}s');
        debugPrint('   Service appelé avec succès');
        debugPrint('🎯 ÉTOILES: AVANT=$_starsBeforeUpdate → APRÈS=$_starsAfterUpdate');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour de la progression: $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }
    }
  }

  

  

  /// Navigation vers la page d'accueil
  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  /// Action du bouton "Continuer" après l'écran de score
  /// Affiche la page Récompenses si des étoiles ont été gagnées, sinon retourne à l'accueil
  Future<void> _handleContinueButton() async {
    try {
      // Si pas de mission ou données insuffisantes, fallback vers l'accueil
      if (widget.mission == null) {
        _navigateToHome();
        return;
      }

      final int before = _starsBeforeUpdate ?? 0;
      // Préférer la valeur Firestore déjà capturée si disponible; sinon calcul local
      final int? afterFromServer = _starsAfterUpdate;
      final int afterLocal = MissionManagementService.calculateStars(
        widget.score,
        widget.totalQuestions,
        before,
      );
      final int after = afterFromServer ?? afterLocal;
      final int gained = after - before;

      if (gained > 0) {
        final TypeEtoile rewardType = (after == 1)
            ? TypeEtoile.uneEtoile
            : (after == 2)
                ? TypeEtoile.deuxEtoiles
                : TypeEtoile.troisEtoiles;
        // Met à jour le service des récompenses pour que la page affiche le bon état
        await _recompensesService.simulerEtoiles(rewardType, missionId: widget.mission?.id ?? 'MISSION');
        _navigateToRewards(forcedType: rewardType);
      } else {
        _navigateToHome();
      }
    } catch (_) {
      _navigateToHome();
    }
  }

  /// Navigation vers la page des Récompenses Utiles
  void _navigateToRewards({TypeEtoile? forcedType}) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => RecompensesUtilesPage(forcedType: forcedType)),
      (route) => false,
    );
  }

  

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🎨 QuizEndPage.build() appelé');
      debugPrint('   Mission: ${widget.mission?.id ?? "NULL"}');
      debugPrint('   Score: ${widget.score}/${widget.totalQuestions}');
      debugPrint('🔥🔥🔥 MODIFICATION TEST - VERSION CORRIGÉE ! 🔥🔥🔥');
    }
    
    final s = useScreenSize(context);
    return AdaptiveScaffold(
      body: Stack(
        children: [
          // Couleur de fond
          Positioned.fill(child: Container(color: const Color(0xFFF3F5F9))),
          // Couche confettis plein écran (au-dessus du fond)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: SafeArea(
                child: Stack(
                  children: [
                    if (_showConfetti1)
                      Positioned.fill(
                        child: FractionalTranslation(
                          translation: const Offset(-0.20, 0.0), // encore plus à gauche
                          child: Lottie.asset(
                            'assets/PAGE/Score resultat/Confetti.json',
                            key: ValueKey('confetti-1-v$_confettiVersion'),
                            fit: BoxFit.cover,
                            alignment: Alignment.centerLeft,
                            repeat: false,
                          ),
                        ),
                      ),
                    if (_showConfetti2)
                      Positioned.fill(
                        child: Lottie.asset(
                          'assets/PAGE/Score resultat/Confetti (1).json',
                          key: ValueKey('confetti-2-v$_confettiVersion'),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          repeat: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Contenu principal
          SafeArea(
            child: LayoutBuilder(
          builder: (context, constraints) {
              // === Ratios et dimensions HARMONISÉS pour tous les écrans ===
            final Size box = constraints.biggest;
            final double shortest = box.shortestSide;
            final bool isWide = box.aspectRatio >= 0.70; // tablette paysage / desktop
            final bool isLarge = s.isMD || s.isLG || s.isXL;
            final bool isTablet = shortest >= 600; // Supporte téléphone + tablette

            _EndLayout calculateLayout() {
              // 1) Ring size
              final double baseFactor = isTablet
                  ? (isWide ? 0.54 : 0.61)  // taille de base plus grande pour tablettes
                  : (isLarge ? 0.65 : 0.69);
              double ringSize = (shortest * baseFactor);
              if (isTablet) {
                ringSize *= isWide ? 0.88 : 0.96; // ajuste fin sur tablette paysage/portrait
              } else if (!isWide && !isLarge) {
                ringSize *= 0.98;
              }
              ringSize = ringSize.clamp(180.0, isTablet ? 520.0 : 460.0);

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
              final double buttonHeight = (56.0 * scale * localScale * (isTablet ? 1.30 : 1.10))
                  .clamp(56.0, 104.0)
                  .toDouble();
              final double buttonStrokeFactor = isTablet ? (isWide ? 1.38 : 2.4) : 1.50;
              final double buttonTop = (ringSize - (buttonStrokeFactor * stroke) + s.buttonOverlapPx())
                  .clamp(0.0, ringSize);
              final double ringStackHeight = (ringSize + buttonHeight * (isTablet ? 0.74 : 0.60)).toDouble();

              // 6) Check & score offsets
              final double checkTop = (stroke * (isTablet ? (isWide ? -0.58 : -1.50) : -0.50));
              final double scoreTop = isTablet ? (ringSize * 0.55) : (ringSize * 0.55);

              // 7) Taille du "Check" et base de fonte du bouton "Récap"
              final double checkSizeFactor = isTablet ? 0.96 : 0.52; // agrandir sur tablette et mobile
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

            final layout = calculateLayout();

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
                  child: Column(
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
                            DefaultTextStyle(
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w700,
                              ),
                              child: Text(
                                "C'est terminé !",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: (32 * layout.scale).clamp(26.0, 40.0).toDouble(),
                                  color: const Color(0xFF334355),
                                  letterSpacing: 0.5,
                                ),
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
                                          fontSize: 56,
                                          fontWeight: FontWeight.w500,
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
                                             width: layout.ringSize * 0.90,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: DefaultTextStyle(
                                                style: const TextStyle(
                                                  fontFamily: 'Fredoka',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                child: Text(
                                                    '${_useTestScore ? _testScore : widget.score} sur ${widget.totalQuestions}',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: const Color(0xFF334355),
                                                     fontSize: (layout.ringSize * 0.21).clamp(18.0, 64.0).toDouble(),
                                                    height: 1.1,
                                                    letterSpacing: 0.5,
                                                  ),
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
                                      child: SizedBox(
                                        width: layout.buttonWidth,
                                        height: layout.buttonHeight,
                                        child: RecapButton(
                                          text: 'Récapitulatif',
                                          size: RecapButtonSize.small,
                                          fontSize: 30,
                                          onPressed: () {
                                            if (kDebugMode) debugPrint('📊 Bouton Récapitulatif cliqué');
                                            _openRecapSheet(context);
                                          },
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
                                  _chosenTitleMessage ?? _getTitleMessage(_useTestScore ? _testScore : widget.score, widget.totalQuestions),
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
                                    _chosenSubtitleMessage ?? _getSubtitleMessage(_useTestScore ? _testScore : widget.score, widget.totalQuestions),
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
                                        onTap: () => _handleContinueButton(),
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
                ],
              ),
            ),
          ),
            );
          },
           ),
         ),
         ],
      ),
      floatingActionButton: kDebugMode
          ? ValueListenableBuilder<bool>(
              valueListenable: DevVisibilityService.overlaysEnabled,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();
                return Row(
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
                );
              },
            )
          : null,
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
    _recapPlayer.dispose();
    _recapPlayerStateSub?.cancel();
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
    // 5) Forcer le rechargement de Lottie (rejouer depuis le début)
    // 6) Forcer la régénération des messages aléatoires
    // 7) Forcer la reconstruction de l'anneau
    setState(() {
      _lottieVersion++;
      // Confettis: redémarrer en réinitialisant l'état et en incrémentant la version
      _confettiVersion++;
      _showConfetti2 = false;
      // Force la régénération des messages en changeant un état
      _forceMessageRefresh = !_forceMessageRefresh;
      // Force la reconstruction de l'anneau
      _ringKey++;
      // Réinitialiser les messages pour la prochaine mission/test
      _chosenTitleMessage = null;
      _chosenSubtitleMessage = null;
      _messagesLocked = false;
    });

    // Reprogrammer le démarrage de la deuxième animation après 1 seconde
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _showConfetti2 = true;
      });
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
                const SizedBox(height: 6),
                // Barre de saisie (grabber) centrée au-dessus du panel
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1E7EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // En-tête avec titre centré et bouton fermer à droite
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Center(
                        child: Text(
                          'Récapitulatif',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFF334355),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Fermer',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<PlayerState>(
                    stream: _recapPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final bool isPlayingNow = snapshot.data?.playing == true;
                      return ListView.separated(
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
                          final bool isActive = (_normalizeAudioKey(a.audioUrl) == _recapPlayingKey) && (isPlayingNow || _recapBusy);
                          return _RecapCard(
                            indexOneBased: index + 1,
                            isCorrect: correct,
                            displayName: a.questionBird,
                            expected: a.questionBird,
                            selected: a.selected,
                            audioUrl: a.audioUrl,
                            isActive: isActive,
                            onToggle: _toggleRecapAudio,
                          );
                        },
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

  String _normalizeAudioKey(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
      return uri.path;
    } catch (_) {
      return url;
    }
  }

  Future<void> _toggleRecapAudio(String url) async {
    if (url.isEmpty) {
      // Requête explicite d'arrêt (clic sur le même bouton actif)
      try {
        await _recapPlayer.stop();
        await _recapPlayer.seek(Duration.zero);
      } finally {
        if (mounted) {
          setState(() {
            _recapIsPlaying = false;
            _recapPlayingUrl = '';
            _recapPlayingKey = '';
            _recapBusy = false;
          });
        }
      }
      return;
    }
    try {
      final String key = _normalizeAudioKey(url);
      final bool isSame = (_recapPlayingKey == key) || (_recapPlayingUrl == url);

      if (isSame) {
        // Toggle strict on/off sur la même entrée
        if (_recapPlayer.playing || _recapIsPlaying) {
          // ON -> OFF
          await _recapPlayer.pause();
          if (mounted) {
            setState(() {
              _recapIsPlaying = false;
            });
          }
          return;
        } else {
          // OFF -> ON (relance)
          if (mounted) {
            setState(() {
              _recapBusy = true;
              _recapPlayingUrl = url;
              _recapPlayingKey = key;
            });
          }
          try {
            await _recapPlayer.setUrl(url);
            await _recapPlayer.play();
            if (mounted) {
              setState(() {
                _recapIsPlaying = true;
              });
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _recapIsPlaying = false;
              });
            }
          } finally {
            if (mounted) {
              setState(() {
                _recapBusy = false;
              });
            }
          }
          return;
        }
      }

      // Son différent → stopper l’actuel si nécessaire
      await _recapPlayer.stop();
      await _recapPlayer.seek(Duration.zero);

      // Marquer immédiatement l'état comme actif pour assurer le on/off au 2e clic
      if (mounted) {
        setState(() {
          _recapPlayingUrl = url;
          _recapPlayingKey = key;
          _recapIsPlaying = true;
          _recapBusy = true;
        });
      }

      try {
        await _recapPlayer.setUrl(url);
        await _recapPlayer.play();
      } catch (_) {
        if (mounted) {
          setState(() {
            _recapIsPlaying = false;
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _recapBusy = false;
          });
        }
      }
    } catch (_) {
      setState(() {
        _recapIsPlaying = false;
        _recapBusy = false;
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
    // Contour marron (comme le popover "Vies") + couleurs statut (vert/rouge)
    final Color borderColor = const Color(0xFF606D7C);
    final Color statusColor = isCorrect ? const Color(0xFF6A994E) : const Color(0xFFBC4749);
    final Color chipColor = statusColor.withValues(alpha: 0.10);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor, width: 2),
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
                  color: statusColor,
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
                color: statusColor,
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
            _PlayAudioButton(color: statusColor, audioUrl: audioUrl, isActive: isActive, onToggle: onToggle),
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

class _PlayAudioButtonState extends State<_PlayAudioButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _spinController; // nullable pour éviter LateInitializationError sur hot-reload
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: (widget.audioUrl.isEmpty) ? null : _onToggleTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F9),
          shape: BoxShape.circle,
        ),
        child: widget.isActive
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: RotationTransition(
                    turns: _spinController ?? const AlwaysStoppedAnimation(0.0),
                    child: CustomPaint(
                      painter: _RoundedArcSpinnerPainter(
                        color: const Color(0xFF606D7C),
                        strokeWidth: 3.6,
                      ),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(
                  'assets/PAGE/Score resultat/icon micro.svg',
                  colorFilter: ColorFilter.mode(
                    widget.audioUrl.isEmpty
                        ? const Color(0xFF606D7C).withValues(alpha: 0.4)
                        : const Color(0xFF606D7C),
                    BlendMode.srcIn,
                  ),
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }

  Future<void> _onToggleTap() async {
    if (widget.isActive) {
      await widget.onToggle('');
    } else {
      await widget.onToggle(widget.audioUrl);
    }
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.isActive) {
      _spinController!.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PlayAudioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_spinController == null) return;
    if (widget.isActive && !_spinController!.isAnimating) {
      _spinController!.repeat();
    } else if (!widget.isActive && _spinController!.isAnimating) {
      _spinController!.stop();
      _spinController!.reset();
    }
  }

  @override
  void dispose() {
    _spinController?.dispose();
    super.dispose();
  }
}

class _SpinnerDisk extends StatelessWidget {
  const _SpinnerDisk();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33000000), width: 2),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _RoundedArcSpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RoundedArcSpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(strokeWidth / 2);

    final double sweep = math.pi * 1.4; // environ 252°
    canvas.drawArc(arcRect, 0.0, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RoundedArcSpinnerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
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
    const double boxShadowBlurRadius = 35.8; // comme BoxShadow(blurRadius: 35.8)
    final double sigma = boxShadowBlurRadius * 0.57735 + 0.5; // conversion radius -> sigma
    final Paint glowShadow = Paint()
      ..color = color.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
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

