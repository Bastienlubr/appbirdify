import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:csv/csv.dart';
import '../models/bird.dart';
import 'local_image_service.dart';

/// Service centralisé pour le préchargement fiable des assets
/// Gère les images et audios avec gestion robuste des erreurs
class AssetPreloaderService {
  static final AssetPreloaderService _instance = AssetPreloaderService._internal();
  factory AssetPreloaderService() => _instance;
  AssetPreloaderService._internal();

  // Caches pour différents types de ressources
  final Map<String, Bird> _birdCache = {};
  final Map<String, AudioPlayer> _audioCache = {};
  final Map<String, ImageProvider> _imageCache = {};
  final Map<String, bool> _imagePreloadStatus = {};
  final Map<String, bool> _audioPreloadStatus = {};
  
  // État de chargement
  final Map<String, bool> _loadingStatus = {};
  
  // Services
  final LocalImageService _localImageService = LocalImageService();
  
  // Configuration
  static const Duration _defaultImageTimeout = Duration(seconds: 8);
  static const Duration _defaultAudioTimeout = Duration(seconds: 5);
  static const int _maxConcurrentLoads = 3;

  /// Précharge tous les assets nécessaires pour une mission
  /// Retourne un résultat détaillé avec succès/échecs
  Future<AssetPreloadResult> preloadMissionAssets({
    required String missionId,
    Duration? imageTimeout,
    Duration? audioTimeout,
    Duration? dataTimeout,
    int? maxConcurrentLoads,
    Function(String step, double progress)? onProgress,
  }) async {
    if (kDebugMode) debugPrint('🔄 Début préchargement mission: $missionId');
    
    final startTime = DateTime.now();
    final result = AssetPreloadResult(missionId: missionId);
    
    try {
      // Marquer comme en cours de chargement
      _loadingStatus[missionId] = true;
      
      // 1. Charger les données de la mission
      onProgress?.call('Chargement des données mission...', 0.1);
      
      final missionData = await _loadMissionData(missionId);
      if (missionData.isEmpty) {
        throw Exception('Aucune donnée trouvée pour la mission $missionId');
      }
      
      // 2. Extraire les noms d'oiseaux
      onProgress?.call('Analyse des oiseaux...', 0.2);
      
      final birdNames = _extractBirdNamesFromMission(missionData);
      if (kDebugMode) debugPrint('🐦 Oiseaux à précharger: $birdNames');
      
      // 3. Charger les données Birdify
      onProgress?.call('Chargement des données oiseaux...', 0.3);
      
      await _loadBirdifyDataIfNeeded();
      await _localImageService.initialize();
      
      // 4. Précharger les images
      onProgress?.call('Préchargement des images...', 0.4);
      
      final imageResults = await _preloadImages(
        birdNames,
        timeout: imageTimeout ?? _defaultImageTimeout,
        maxConcurrent: maxConcurrentLoads ?? _maxConcurrentLoads,
        onProgress: (progress) {
          onProgress?.call('Préchargement des images...', 0.4 + (progress * 0.3));
        },
      );
      
      result.successfulImages.addAll(imageResults.successful);
      result.failedImages.addAll(imageResults.failed);
      
      // 5. Précharger les audios
      onProgress?.call('Préchargement des audios...', 0.7);
      
      final audioResults = await _preloadAudios(
        birdNames,
        timeout: audioTimeout ?? _defaultAudioTimeout,
        maxConcurrent: maxConcurrentLoads ?? _maxConcurrentLoads,
        onProgress: (progress) {
          onProgress?.call('Préchargement des audios...', 0.7 + (progress * 0.2));
        },
      );
      
      result.successfulAudios.addAll(audioResults.successful);
      result.failedAudios.addAll(audioResults.failed);
      
      // 6. Finalisation
      onProgress?.call('Finalisation...', 1.0);
      
      final duration = DateTime.now().difference(startTime);
      result.duration = duration;
      result.isSuccess = result.failedImages.isEmpty && result.failedAudios.isEmpty;
      
      if (kDebugMode) {
        debugPrint('✅ Préchargement terminé:');
        debugPrint('   - Images: ${result.successfulImages.length}/${result.totalImages}');
        debugPrint('   - Audios: ${result.successfulAudios.length}/${result.totalAudios}');
        debugPrint('   - Durée: ${duration.inMilliseconds}ms');
        debugPrint('   - Succès: ${result.isSuccess}');
      }
      
    } catch (e) {
      result.error = e.toString();
      result.isSuccess = false;
      if (kDebugMode) debugPrint('❌ Erreur préchargement: $e');
    } finally {
      _loadingStatus[missionId] = false;
    }
    
    return result;
  }

  /// Charge les données d'une mission depuis le CSV
  Future<List<Map<String, String>>> _loadMissionData(String missionId) async {
    try {
      final csvPath = 'assets/Missionhome/questionMission/$missionId.csv';
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

  /// Extrait les noms d'oiseaux des bonnes réponses
  List<String> _extractBirdNamesFromMission(List<Map<String, String>> missionData) {
    final birdNames = <String>{};
    
    for (final row in missionData) {
      final bonneReponse = row['bonne_reponse']?.trim();
      if (bonneReponse != null && bonneReponse.isNotEmpty) {
        birdNames.add(bonneReponse);
      }
    }
    
    return birdNames.toList();
  }

  /// Charge les données Birdify si pas déjà en cache
  Future<void> _loadBirdifyDataIfNeeded() async {
    if (_birdCache.isNotEmpty) {
      if (kDebugMode) debugPrint('📦 Données Birdify déjà en cache (${_birdCache.length} oiseaux)');
      return;
    }
    
    try {
      if (kDebugMode) debugPrint('🔄 Chargement des données Birdify...');
      
      final String csvString = await rootBundle.loadString('assets/data/Database birdify.csv');
      final List<String> lines = const LineSplitter().convert(csvString);
      
      if (lines.isEmpty) {
        throw Exception('Le fichier CSV Birdify est vide');
      }
      
      final List<String> headers = _parseCsvLine(lines[0]);
      
      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final List<String> values = _parseCsvLine(line);
            final Map<String, String> csvRow = _createCsvRow(headers, values);
            final Bird bird = Bird.fromCsvRow(csvRow);
            _birdCache[bird.nomFr] = bird;
          } catch (e) {
            // Ignorer les lignes malformées
            if (kDebugMode) debugPrint('⚠️ Ligne $i ignorée: $e');
          }
        }
      }
      
      if (kDebugMode) debugPrint('✅ ${_birdCache.length} oiseaux chargés depuis Birdify');
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement Birdify: $e');
      rethrow;
    }
  }

  /// Précharge les images pour une liste d'oiseaux
  Future<PreloadResult> _preloadImages(
    List<String> birdNames, {
    Duration? timeout,
    int? maxConcurrent,
    Function(double progress)? onProgress,
  }) async {
    final semaphore = Semaphore(maxConcurrent ?? _maxConcurrentLoads);
    final successful = <String>[];
    final failed = <String>[];
    
    final futures = <Future<void>>[];
    
    for (int i = 0; i < birdNames.length; i++) {
      final birdName = birdNames[i];
      final future = _preloadSingleImage(birdName, semaphore, timeout ?? _defaultImageTimeout)
          .then((_) {
        successful.add(birdName);
        if (kDebugMode) debugPrint('✅ Image préchargée: $birdName');
      }).catchError((e) {
        failed.add(birdName);
        if (kDebugMode) debugPrint('❌ Erreur préchargement image pour $birdName: $e');
      });
      
      futures.add(future);
      
      // Mettre à jour le progrès
      if (onProgress != null) {
        final progress = (i + 1) / birdNames.length;
        onProgress(progress);
      }
    }
    
    await Future.wait(futures);
    
    return PreloadResult(successful: successful, failed: failed);
  }

  /// Précharge une seule image
  Future<void> _preloadSingleImage(String birdName, Semaphore semaphore, Duration timeout) async {
    await semaphore.acquire();
    
    try {
      final bird = _birdCache[birdName];
      if (bird == null) {
        throw Exception('Oiseau non trouvé: $birdName');
      }
      
      if (bird.urlImage.isEmpty) {
        throw Exception('URL image vide pour: $birdName');
      }
      
      if (_imageCache.containsKey(birdName)) {
        return; // Déjà préchargée
      }
      
      // Précharger l'image
      final imageProvider = NetworkImage(bird.urlImage);
      imageProvider.resolve(const ImageConfiguration());
      
      _imageCache[birdName] = imageProvider;
      _imagePreloadStatus[birdName] = true;
      
    } finally {
      semaphore.release();
    }
  }

  /// Précharge les audios pour une liste d'oiseaux
  Future<PreloadResult> _preloadAudios(
    List<String> birdNames, {
    Duration? timeout,
    int? maxConcurrent,
    Function(double progress)? onProgress,
  }) async {
    final semaphore = Semaphore(maxConcurrent ?? _maxConcurrentLoads);
    final successful = <String>[];
    final failed = <String>[];
    
    final futures = <Future<void>>[];
    
    for (int i = 0; i < birdNames.length; i++) {
      final birdName = birdNames[i];
      final future = _preloadSingleAudio(birdName, semaphore, timeout ?? _defaultAudioTimeout)
          .then((_) {
        successful.add(birdName);
        if (kDebugMode) debugPrint('✅ Audio préchargé: $birdName');
      }).catchError((e) {
        failed.add(birdName);
        if (kDebugMode) debugPrint('❌ Erreur préchargement audio pour $birdName: $e');
      });
      
      futures.add(future);
      
      // Mettre à jour le progrès
      if (onProgress != null) {
        final progress = (i + 1) / birdNames.length;
        onProgress(progress);
      }
    }
    
    await Future.wait(futures);
    
    return PreloadResult(successful: successful, failed: failed);
  }

  /// Précharge un seul audio
  Future<void> _preloadSingleAudio(String birdName, Semaphore semaphore, Duration timeout) async {
    await semaphore.acquire();
    
    try {
      final bird = _birdCache[birdName];
      if (bird == null) {
        throw Exception('Oiseau non trouvé: $birdName');
      }
      
      if (bird.urlMp3.isEmpty) {
        throw Exception('URL audio vide pour: $birdName');
      }
      
      if (_audioCache.containsKey(birdName)) {
        return; // Déjà préchargé
      }
      
      // Précharger l'audio
      final audioPlayer = AudioPlayer();
      await audioPlayer.setUrl(bird.urlMp3).timeout(timeout);
      
      _audioCache[birdName] = audioPlayer;
      _audioPreloadStatus[birdName] = true;
      
    } finally {
      semaphore.release();
    }
  }

  /// Vérifie si une image est préchargée
  bool isImagePreloaded(String birdName) {
    return _imagePreloadStatus[birdName] ?? false;
  }

  /// Récupère une image préchargée
  ImageProvider? getPreloadedImage(String birdName) {
    return _imageCache[birdName];
  }

  /// Vérifie si un audio est préchargé
  bool isAudioPreloaded(String birdName) {
    return _audioPreloadStatus[birdName] ?? false;
  }

  /// Récupère un audio préchargé
  AudioPlayer? getPreloadedAudio(String birdName) {
    return _audioCache[birdName];
  }

  /// Récupère les données d'un oiseau
  Bird? getBirdData(String birdName) {
    return _birdCache[birdName];
  }

  /// Vérifie si une mission est en cours de chargement
  bool isLoading(String missionId) {
    return _loadingStatus[missionId] ?? false;
  }

  /// Nettoie le cache audio
  void clearAudioCache() {
    for (final player in _audioCache.values) {
      player.dispose();
    }
    _audioCache.clear();
    _audioPreloadStatus.clear();
    if (kDebugMode) debugPrint('🗑️ Cache audio nettoyé');
  }

  /// Nettoie tout le cache
  void clearAllCache() {
    clearAudioCache();
    _birdCache.clear();
    _imageCache.clear();
    _imagePreloadStatus.clear();
    _loadingStatus.clear();
    if (kDebugMode) debugPrint('🗑️ Tout le cache nettoyé');
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
}

/// Résultat du préchargement des assets
class AssetPreloadResult {
  final String missionId;
  final List<String> successfulImages = [];
  final List<String> failedImages = [];
  final List<String> successfulAudios = [];
  final List<String> failedAudios = [];
  String? error;
  bool isSuccess = false;
  Duration? duration;
  String currentStep = '';
  double progress = 0.0;

  AssetPreloadResult({required this.missionId});

  int get totalImages => successfulImages.length + failedImages.length;
  int get totalAudios => successfulAudios.length + failedAudios.length;
  
  // Getters pour la compatibilité
  List<String> get successful => successfulImages;
  List<String> get failed => failedImages;
}

/// Résultat simple pour les préchargements
class PreloadResult {
  final List<String> successful;
  final List<String> failed;

  PreloadResult({required this.successful, required this.failed});
}

/// Sémaphore pour limiter le nombre de chargements concurrents
class Semaphore {
  final int _maxCount;
  int _currentCount = 0;
  final List<Completer<void>> _waiters = [];

  Semaphore(this._maxCount);

  Future<void> acquire() async {
    if (_currentCount < _maxCount) {
      _currentCount++;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      waiter.complete();
    } else {
      _currentCount--;
    }
  }
} 