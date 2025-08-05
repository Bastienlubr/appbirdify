import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/bird.dart';
import '../theme/colors.dart';
import '../services/image_cache_service.dart';
import 'quiz_page.dart';

/// Écran de chargement temporaire pour précharger les images des bonnes réponses
class MissionLoadingScreen extends StatefulWidget {
  final String missionId;
  final String missionName;

  const MissionLoadingScreen({
    super.key,
    required this.missionId,
    required this.missionName,
  });

  @override
  State<MissionLoadingScreen> createState() => _MissionLoadingScreenState();
}

class _MissionLoadingScreenState extends State<MissionLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  String _currentStep = 'Initialisation...';
  List<String> _birdNames = [];
  final Map<String, Bird> _birdCache = {};
  int _loadedImages = 0;
  int _totalImages = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startLoading();
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

  Future<void> _startLoading() async {
    try {
      if (kDebugMode) debugPrint('🔄 Début du chargement de la mission: ${widget.missionId}');

      // Étape 1: Charger les données de la mission
      await _updateProgress('Chargement des données mission...', 0.1);
      final missionData = await _loadMissionData();
      if (missionData.isEmpty) {
        throw Exception('Aucune donnée trouvée pour la mission ${widget.missionId}');
      }

      // Étape 2: Extraire les noms des bonnes réponses
      await _updateProgress('Analyse des bonnes réponses...', 0.2);
      _birdNames = _extractGoodAnswers(missionData);
      _totalImages = _birdNames.length;
      
      if (kDebugMode) debugPrint('🐦 ${_birdNames.length} bonnes réponses trouvées: $_birdNames');

      // Étape 3: Charger les données Birdify
      await _updateProgress('Chargement de la base de données...', 0.3);
      await _loadBirdifyData();

      // Étape 4: Précharger les images des bonnes réponses
      await _updateProgress('Préchargement des images...', 0.4);
      await _preloadGoodAnswerImages();

      // Étape 5: Finalisation
      await _updateProgress('Finalisation...', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Navigation vers le quiz avec les données préchargées
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizPage(
              missionId: widget.missionId,
              preloadedBirds: _birdCache,
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
      final csvPath = 'assets/Missionhome/questionMission/${widget.missionId}.csv';
      final csvString = await rootBundle.loadString(csvPath);
      
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      if (csvTable.isEmpty) return [];
      
      final headers = csvTable[0].map((e) => e.toString()).toList();
      final missionData = <Map<String, String>>[];
      
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;
        
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          csvRow[headers[j]] = row[j]?.toString() ?? '';
        }
        
        // Ne garder que les lignes avec des bonnes réponses
        if (csvRow['bonne_reponse']?.isNotEmpty == true) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.quiz,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // Titre
              Text(
                'Préparation de la mission',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontFamily: 'Quicksand',
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Nom de la mission
              Text(
                widget.missionName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                  fontFamily: 'Quicksand',
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Barre de progression
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Étape actuelle
              Text(
                _currentStep,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                  fontFamily: 'Quicksand',
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              // Progression détaillée
              if (_totalImages > 0)
                Text(
                  '$_loadedImages/$_totalImages images chargées',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Quicksand',
                  ),
                  textAlign: TextAlign.center,
                ),
              
              // Message d'erreur
              if (_errorMessage != null) ...[
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.accent,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          fontFamily: 'Quicksand',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.accent,
                          fontFamily: 'Quicksand',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                                             ElevatedButton(
                         onPressed: () {
                           setState(() {
                             _errorMessage = null;
                             _loadedImages = 0;
                             _birdCache.clear();
                           });
                           _startLoading();
                         },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Réessayer',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 