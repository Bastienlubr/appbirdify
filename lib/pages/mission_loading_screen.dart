import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/bird.dart';
// Unused colors import removed
import '../services/image_cache_service.dart';
import 'quiz_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mission.dart';
import '../services/mission_loader_service.dart';
import '../services/life_sync_service.dart';
import 'package:lottie/lottie.dart';
import '../services/quiz_generator.dart';
import '../ui/responsive/responsive.dart';

/// Écran de chargement temporaire pour précharger les images des bonnes réponses
class MissionLoadingScreen extends StatefulWidget {
  final String missionId;
  final String missionName;
  final String? missionCsvPath;

  const MissionLoadingScreen({
    super.key,
    required this.missionId,
    required this.missionName,
    this.missionCsvPath,
  });

  @override
  State<MissionLoadingScreen> createState() => _MissionLoadingScreenState();
}

class _MissionLoadingScreenState extends State<MissionLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  final String _lottiePath = 'assets/PAGE/Chargement/chenille.json';
  final List<String> _funFacts = [];
  int _currentFunFactIndex = 0;
  Timer? _funFactTimer;
  AnimationController? _funFactController; // Nullable pour éviter LateInitializationError
  int? _previousFunFactIndex;
  bool _isFunFactAnimating = false;

  String _currentStep = 'Initialisation...';
  List<String> _birdNames = [];
  final Map<String, Bird> _birdCache = {};
  int _loadedImages = 0;
  int _totalImages = 0;
  String? _errorMessage;
  List<QuizQuestion> _preloadedQuestions = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadFunFacts();
    _initFunFactAnimation();
    _startLoading();
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
    // Removed unused _pulseAnimation tween; controller still drives the repeat

    // Animation de progression
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Removed unused _progressAnimation tween; progress is driven directly via controller.animateTo

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
    _funFactController?.dispose();
    _funFactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _funFactController!.value = 1.0;
  }

  void _scheduleFunFactTimer() {
    _funFactTimer?.cancel();
    if (_funFacts.length < 2) return;
    _funFactTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      _startFunFactTransition();
    });
  }

  void _startFunFactTransition() {
    if (!mounted || _funFacts.length < 2) return;
    final controller = _funFactController;
    if (controller == null) return;

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

  Future<void> _startLoading() async {
    try {
      if (kDebugMode) debugPrint('🔄 Début du chargement de la mission: ${widget.missionId}');

      // Étape 1: Charger la mission depuis Firestore si disponible, sinon basculer vers CSV
      await _updateProgress('Chargement de la mission (Firestore)...', 0.1);
      bool loadedFromFirestore = false;
      try {
        final missionDoc = await FirebaseFirestore.instance
            .collection('missions')
            .doc(widget.missionId)
            .get();

        if (missionDoc.exists) {
          final data = missionDoc.data() as Map<String, dynamic>;
          final pool = data['pool'] as Map<String, dynamic>?;
          final List<dynamic> bonnesDetails = (pool?['bonnesDetails'] as List<dynamic>?) ?? [];

          if (bonnesDetails.isNotEmpty) {
            await _updateProgress('Analyse des bonnes réponses (Firestore)...', 0.2);
            _birdNames = bonnesDetails
                .map((e) => (e as Map<String, dynamic>)['nomFrancais']?.toString() ?? '')
                .where((n) => n.isNotEmpty)
                .toList();
            _totalImages = _birdNames.length;

            // Construire le cache oiseau minimal à partir de bonnesDetails
            for (final entry in bonnesDetails) {
              final m = entry as Map<String, dynamic>;
              final nom = (m['nomFrancais'] ?? '').toString();
              if (nom.isEmpty) continue;
              final bird = Bird(
                id: (m['id'] ?? nom).toString(),
                genus: '',
                species: '',
                nomFr: nom,
                urlMp3: (m['urlAudio'] ?? '').toString(),
                urlImage: (m['urlImage'] ?? '').toString(),
                milieux: <String>{},
              );
              _birdCache[nom] = bird;
            }

            if (kDebugMode) debugPrint('🐦 ${_birdNames.length} bonnes réponses (Firestore): $_birdNames');

            // Étape: Précharger les images à partir des URLs Firestore
            await _updateProgress('Préchargement des images...', 0.4);
            await _preloadGoodAnswerImages();
            loadedFromFirestore = true;

            // Précharger aussi les questions pour éviter tout second écran de chargement
            try {
              _preloadedQuestions = await QuizGenerator.generateQuizFromFirestoreAndCsv(widget.missionId, data);
            } catch (_) {}
          }
        }
      } catch (e) {
        // Ne pas échouer l'écran si Firestore est interdit; on bascule vers CSV
        if (kDebugMode) debugPrint('⚠️ Lecture Firestore impossible, bascule vers CSV: $e');
      }

      if (!loadedFromFirestore) {
        // Fallback CSV: ancien flux
        await _updateProgress('Chargement des données mission (CSV)...', 0.1);
        final missionData = await _loadMissionData();
        if (missionData.isEmpty) {
          throw Exception('Aucune donnée trouvée pour la mission ${widget.missionId}');
        }

        await _updateProgress('Analyse des bonnes réponses...', 0.2);
        _birdNames = _extractGoodAnswers(missionData);
        _totalImages = _birdNames.length;
        if (kDebugMode) debugPrint('🐦 ${_birdNames.length} bonnes réponses trouvées: $_birdNames');

        await _updateProgress('Chargement de la base de données...', 0.3);
        await _loadBirdifyData();

        await _updateProgress('Préchargement des images...', 0.4);
        await _preloadGoodAnswerImages();

        // Précharger aussi les questions pour éviter tout second écran de chargement
        try {
          _preloadedQuestions = await QuizGenerator.generateQuizFromCsv(widget.missionId);
        } catch (_) {}
      }

      // Étape 5: Finalisation
      await _updateProgress('Finalisation...', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Récupérer l'objet Mission depuis HomeScreen
        final mission = await _getMissionFromHomeScreen();
        
        if (!mounted) return;
        
        if (kDebugMode) {
          debugPrint('🎯 Mission récupérée pour QuizPage:');
          final missionTitle = mission?.titreMission ?? mission?.title ?? mission?.id ?? 'NULL';
          debugPrint('   ID: ${mission?.id ?? "NULL"}');
          debugPrint('   Nom: $missionTitle');
          debugPrint('   Étoiles: ${mission?.lastStarsEarned ?? "NULL"}');
        }
        
        // Navigation vers le quiz avec les données préchargées
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizPage(
              missionId: widget.missionId,
              mission: mission, // Passer l'objet Mission
              preloadedBirds: _birdCache,
              preloadedQuestions: _preloadedQuestions.isNotEmpty ? _preloadedQuestions : null,
            ),
          ),
        );
      }

    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement: $e');
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
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Charge les données de la mission depuis le CSV
  Future<List<Map<String, String>>> _loadMissionData() async {
    try {
      final csvPath = widget.missionCsvPath ?? 'assets/Missionhome/questionMission/${widget.missionId}.csv';
      final csvString = await rootBundle.loadString(csvPath);
      
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      if (csvTable.isEmpty) return [];
      
      // Normaliser les en-têtes pour être robustes aux variantes
      String normalizeHeader(String raw) {
        String h = raw.toString().trim().toLowerCase();
        h = h
            .replaceAll('é', 'e')
            .replaceAll('è', 'e')
            .replaceAll('ê', 'e')
            .replaceAll('ë', 'e')
            .replaceAll('à', 'a')
            .replaceAll('â', 'a')
            .replaceAll('î', 'i')
            .replaceAll('ï', 'i')
            .replaceAll('ô', 'o')
            .replaceAll('ö', 'o')
            .replaceAll('ù', 'u')
            .replaceAll('û', 'u')
            .replaceAll('ü', 'u')
            .replaceAll('’', "'")
            .replaceAll('‘', "'");
        h = h.replaceAll(RegExp(r"\s+"), '_');
        return h;
      }

      final rawHeaders = csvTable[0].map((e) => e.toString()).toList();
      final headers = rawHeaders.map(normalizeHeader).toList();
      final missionData = <Map<String, String>>[];
      
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;
        
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final key = headers[j];
          final value = row[j]?.toString().trim() ?? '';
          csvRow[key] = value;
        }
        
        // Ne garder que les lignes avec des bonnes réponses (clé normalisée)
        final bonne = csvRow['bonne_reponse'] ?? '';
        if (bonne.isNotEmpty) {
          missionData.add(csvRow);
        }
      }
      
      return missionData;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur chargement données mission: $e');
      return [];
    }
  }

  /// Extrait uniquement les bonnes réponses (pas les mauvaises)
  List<String> _extractGoodAnswers(List<Map<String, String>> missionData) {
    final birdNames = <String>{};
    
    for (final row in missionData) {
      final bonneReponse = row['bonne_reponse']?.trim();
      if (bonneReponse != null && bonneReponse.isNotEmpty) {
        birdNames.add(bonneReponse);
      }
    }
    
    return birdNames.toList();
  }

  /// Charge les données Birdify pour les oiseaux nécessaires
  Future<void> _loadBirdifyData() async {
    try {
      final String csvString = await rootBundle.loadString('assets/data/Database birdify.csv');
      final List<String> lines = const LineSplitter().convert(csvString);
      
      if (lines.isEmpty) {
        throw Exception('Le fichier CSV Birdify est vide');
      }
      
      final List<String> headers = _parseCsvLine(lines[0]);
      final Set<String> targetBirdNames = _birdNames.toSet();
      int birdsFound = 0;
      
      // Parcourir le CSV et ne charger que les oiseaux nécessaires
      for (int i = 1; i < lines.length && birdsFound < _birdNames.length; i++) {
        final String line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final List<String> values = _parseCsvLine(line);
            final Map<String, String> csvRow = _createCsvRow(headers, values);
            final Bird bird = Bird.fromCsvRow(csvRow);
            
            // Ne charger que si l'oiseau est dans la liste cible
            if (targetBirdNames.contains(bird.nomFr)) {
              _birdCache[bird.nomFr] = bird;
              birdsFound++;
              if (kDebugMode) debugPrint('✅ Données oiseau chargées: ${bird.nomFr}');
            }
          } catch (e) {
            // Ignorer les lignes malformées
            if (kDebugMode) debugPrint('⚠️ Ligne $i ignorée: $e');
          }
        }
      }
      
      if (kDebugMode) debugPrint('🎯 $birdsFound/${_birdNames.length} oiseaux trouvés dans Birdify');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement Birdify: $e');
      rethrow;
    }
  }

  /// Précharge les images des bonnes réponses
  Future<void> _preloadGoodAnswerImages() async {
    final imageCacheService = ImageCacheService();
    final imageUrls = <String>[];
    
    // Collecter toutes les URLs d'images
    for (final birdName in _birdNames) {
      final bird = _birdCache[birdName];
      if (bird != null && bird.urlImage.isNotEmpty) {
        imageUrls.add(bird.urlImage);
      }
    }
    
    if (kDebugMode) debugPrint('🔄 Préchargement de ${imageUrls.length} images en parallèle');
    
    // Précharger toutes les images en parallèle
    try {
      await imageCacheService.preloadImages(imageUrls, context);
      
      _loadedImages = imageUrls.length;
      final progress = 0.9; // 90% du progrès
      
      if (mounted) {
        setState(() {
          _currentStep = 'Images préchargées: $_loadedImages/$_totalImages';
        });
        _progressController.animateTo(progress);
      }
      
      if (kDebugMode) debugPrint('✅ $_loadedImages images préchargées dans le cache');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur préchargement images: $e');
      // Continuer même si certaines images échouent
      _loadedImages = imageUrls.length;
    }
  }

  /// Parse une ligne CSV en tenant compte des guillemets
  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    
    result.add(current.toString().trim());
    return result;
  }

  /// Crée une Map à partir des headers et valeurs CSV
  Map<String, String> _createCsvRow(List<String> headers, List<String> values) {
    final Map<String, String> row = {};
    for (int i = 0; i < headers.length && i < values.length; i++) {
      row[headers[i]] = values[i];
    }
    return row;
  }

  String _mapMissionIdToBiomeName(String missionId) {
    if (missionId.isEmpty) return '';
    switch (missionId[0].toUpperCase()) {
      case 'U':
        return 'urbain';
      case 'F':
        return 'forestier';
      case 'A':
        return 'agricole';
      case 'H':
        return 'humide';
      case 'M':
        return 'montagnard';
      case 'L':
        return 'littoral';
      default:
        return '';
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
            // Removed unused isLarge
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
                        _currentStep.isNotEmpty ? _currentStep : 'Chargement en cours...',
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
            );
          },
        ),
      ),
    );
  }
  
  /// Récupère l'objet Mission depuis HomeScreen via MissionLoaderService
  Future<Mission?> _getMissionFromHomeScreen() async {
    try {
      final uid = LifeSyncService.getCurrentUserId();
      if (uid == null) {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté pour récupérer la mission');
        return null;
      }

      final biome = _mapMissionIdToBiomeName(widget.missionId);
      if (biome.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Impossible de déduire le biome depuis ${widget.missionId}');
        return null;
      }

      final missions = await MissionLoaderService.loadMissionsForBiomeWithProgression(uid, biome);
      final mission = missions.firstWhere(
        (m) => m.id == widget.missionId,
        orElse: () => Mission(
          id: widget.missionId,
          milieu: biome,
          index: 1,
          status: 'available',
          questions: const [],
          titreMission: widget.missionName,
        ),
      );

      if (kDebugMode) {
        debugPrint('🎯 Mission trouvée pour ${widget.missionId}:');
        final title = mission.titreMission ?? mission.title ?? mission.id;
        debugPrint('   ID: ${mission.id}');
        debugPrint('   Nom: $title');
        debugPrint('   Étoiles: ${mission.lastStarsEarned}');
        debugPrint('   Statut: ${mission.status}');
      }

      return mission;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la récupération de la mission: $e');
      return null;
    }
  }
} 