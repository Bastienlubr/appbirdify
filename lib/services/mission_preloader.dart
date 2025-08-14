import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import '../models/bird.dart';

/// Service pour précharger les éléments nécessaires d'une mission
class MissionPreloader {
  static final Map<String, Bird> _birdCache = {};
  static final Map<String, AudioPlayer> _audioCache = {};
  static final Map<String, bool> _loadingStatus = {};
  static final Map<String, bool> _imageCache = {};
  
  /// Précharge uniquement les éléments nécessaires pour une mission (version ultra-rapide)
  static Future<Map<String, dynamic>> preloadMission(String missionId) async {
    if (kDebugMode) debugPrint('🔄 Début du préchargement optimisé pour la mission: $missionId');
    
    try {
      // 1. Charger les données de la mission
      final missionData = await _loadMissionData(missionId);
      if (missionData.isEmpty) {
        throw Exception('Aucune donnée trouvée pour la mission $missionId');
      }
      
      // 2. Extraire les noms d'oiseaux des bonnes réponses
      final birdNames = _extractBirdNamesFromMission(missionData);
      if (kDebugMode) debugPrint('🐦 Oiseaux à précharger: $birdNames');
      
      // 3. Charger UNIQUEMENT les données Birdify pour ces oiseaux spécifiques
      await _loadBirdifyDataForSpecificBirds(birdNames);
      
      // 4. Précharger les audios et images pour ces oiseaux spécifiques
      final preloadResults = await _preloadAudiosAndImagesForBirds(birdNames);
      
      if (kDebugMode) debugPrint('✅ Préchargement optimisé terminé pour $missionId');
      
      return {
        'missionId': missionId,
        'birdNames': birdNames,
        'preloadedAudios': preloadResults['successfulAudios'],
        'preloadedImages': preloadResults['successfulImages'],
        'failedAudios': preloadResults['failedAudios'],
        'failedImages': preloadResults['failedImages'],
        'totalBirds': birdNames.length,
        'successfulAudioPreloads': preloadResults['successfulAudios']?.length ?? 0,
        'successfulImagePreloads': preloadResults['successfulImages']?.length ?? 0,
      };
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du préchargement: $e');
      rethrow;
    }
  }
  
  /// Charge les données d'une mission depuis le CSV
  static Future<List<Map<String, String>>> _loadMissionData(String missionId) async {
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
        
        // Ne garder que les lignes avec des bonnes réponses (num_question non vide)
        if (csvRow['num_question']?.isNotEmpty == true) {
          missionData.add(csvRow);
        }
      }
      
      return missionData;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des données de mission: $e');
      return [];
    }
  }
  
  /// Extrait les noms d'oiseaux des bonnes réponses
  static List<String> _extractBirdNamesFromMission(List<Map<String, String>> missionData) {
    final birdNames = <String>{};
    
    for (final row in missionData) {
      final bonneReponse = row['bonne_reponse']?.trim();
      if (bonneReponse != null && bonneReponse.isNotEmpty) {
        birdNames.add(bonneReponse);
      }
    }
    
    return birdNames.toList();
  }
  
  /// Charge UNIQUEMENT les données Birdify pour les oiseaux spécifiques de la mission
  static Future<void> _loadBirdifyDataForSpecificBirds(List<String> birdNames) async {
    if (kDebugMode) debugPrint('🎯 Chargement ciblé pour ${birdNames.length} oiseaux spécifiques');
    
    try {
      final String csvString = await rootBundle.loadString('assets/data/Bank son oiseauxV4.csv');
      final List<String> lines = const LineSplitter().convert(csvString);
      
      if (lines.isEmpty) {
        throw Exception('Le fichier CSV Birdify est vide');
      }
      
      final List<String> headers = _parseCsvLine(lines[0]);
      final Set<String> targetBirdNames = birdNames.toSet();
      int birdsFound = 0;
      
      // Parcourir le CSV et ne charger que les oiseaux nécessaires
      for (int i = 1; i < lines.length && birdsFound < birdNames.length; i++) {
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
              if (kDebugMode) debugPrint('✅ Oiseau ciblé chargé: ${bird.nomFr}');
            }
          } catch (e) {
            // Ignorer les lignes malformées
            if (kDebugMode) debugPrint('⚠️ Ligne $i ignorée: $e');
          }
        }
      }
      
      if (kDebugMode) debugPrint('🎯 $birdsFound/${birdNames.length} oiseaux ciblés chargés');
      
      // Vérifier quels oiseaux n'ont pas été trouvés
      final missingBirds = birdNames.where((name) => !_birdCache.containsKey(name)).toList();
      if (missingBirds.isNotEmpty && kDebugMode) {
        debugPrint('⚠️ Oiseaux non trouvés: $missingBirds');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement Birdify ciblé: $e');
      rethrow;
    }
  }
  
  /// Charge les données Birdify complètes (méthode publique - pour compatibilité)
  static Future<void> loadBirdifyData() async {
    if (_birdCache.isNotEmpty) {
      if (kDebugMode) debugPrint('📦 Données Birdify déjà en cache (${_birdCache.length} oiseaux)');
      return;
    }
    
    try {
      if (kDebugMode) debugPrint('🔄 Chargement complet des données Birdify...');
      
      final String csvString = await rootBundle.loadString('assets/data/Bank son oiseauxV4.csv');
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
  
  /// Précharge les audios et images pour une liste d'oiseaux
  static Future<Map<String, List<String>>> _preloadAudiosAndImagesForBirds(List<String> birdNames) async {
    final successfulAudios = <String>[];
    final failedAudios = <String>[];
    final successfulImages = <String>[];
    final failedImages = <String>[];
    
    // Précharger uniquement les oiseaux de la mission
    for (final birdName in birdNames) {
      try {
        final bird = _birdCache[birdName];
        if (bird != null) {
          // Précharger l'audio
          if (bird.urlMp3.isNotEmpty && !_audioCache.containsKey(birdName)) {
            try {
              final audioPlayer = AudioPlayer();
              await audioPlayer.setUrl(bird.urlMp3).timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException('Timeout audio'),
              );
              _audioCache[birdName] = audioPlayer;
              successfulAudios.add(birdName);
              if (kDebugMode) debugPrint('✅ Audio préchargé: $birdName');
            } catch (e) {
              if (kDebugMode) debugPrint('❌ Erreur préchargement audio pour $birdName: $e');
              failedAudios.add(birdName);
            }
          }
          
          // Précharger l'image
          if (bird.urlImage.isNotEmpty && !_imageCache.containsKey(birdName)) {
            try {
              // Précharger l'image avec un timeout
              await _preloadImage(bird.urlImage).timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw TimeoutException('Timeout image'),
              );
              _imageCache[birdName] = true;
              successfulImages.add(birdName);
              if (kDebugMode) debugPrint('✅ Image préchargée: $birdName');
            } catch (e) {
              if (kDebugMode) debugPrint('❌ Erreur préchargement image pour $birdName: $e');
              failedImages.add(birdName);
            }
          }
        } else {
          failedAudios.add(birdName);
          failedImages.add(birdName);
          if (kDebugMode) debugPrint('❌ Aucune donnée trouvée pour: $birdName');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur générale pour $birdName: $e');
        failedAudios.add(birdName);
        failedImages.add(birdName);
      }
    }
    
    return {
      'successfulAudios': successfulAudios,
      'failedAudios': failedAudios,
      'successfulImages': successfulImages,
      'failedImages': failedImages,
    };
  }
  
  /// Précharge une image depuis une URL
  static Future<void> _preloadImage(String imageUrl) async {
    // Utiliser http pour précharger l'image
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Erreur HTTP ${response.statusCode}');
    }
  }
  
  /// Récupère un AudioPlayer préchargé pour un oiseau
  static AudioPlayer? getPreloadedAudio(String birdName) {
    return _audioCache[birdName];
  }
  
  /// Vérifie si une image est préchargée pour un oiseau
  static bool isImagePreloaded(String birdName) {
    return _imageCache[birdName] ?? false;
  }
  
  /// Récupère les données Bird d'un oiseau
  static Bird? getBirdData(String birdName) {
    return _birdCache[birdName];
  }

  /// Normalise un nom pour comparaison tolérante (minuscules, accents retirés, espaces trim)
  static String _normalizeName(String name) {
    String n = name.toLowerCase().trim();
    const accents = {
      'à':'a','â':'a','ä':'a','á':'a','ã':'a','å':'a',
      'ç':'c',
      'é':'e','è':'e','ê':'e','ë':'e',
      'í':'i','ì':'i','î':'i','ï':'i',
      'ñ':'n',
      'ò':'o','ó':'o','ô':'o','ö':'o','õ':'o',
      'ù':'u','ú':'u','û':'u','ü':'u',
      'ý':'y','ÿ':'y',
      'œ':'oe','æ':'ae',
      '’':'\'','‘':'\'','ʼ':'\'',
    };
    n = n.split('').map((ch) => accents[ch] ?? ch).join();
    n = n.replaceAll(RegExp(r"\s+"), ' ');
    return n;
  }

  /// Recherche tolérante par nom (retire accents/casse) dans le cache
  static Bird? findBirdByName(String name) {
    if (_birdCache.containsKey(name)) return _birdCache[name];
    final target = _normalizeName(name);
    for (final entry in _birdCache.entries) {
      final candidate = _normalizeName(entry.key);
      if (candidate == target) return entry.value;
    }
    // Tentative de correspondance partielle (commence par)
    for (final entry in _birdCache.entries) {
      final candidate = _normalizeName(entry.key);
      if (candidate.startsWith(target) || target.startsWith(candidate)) return entry.value;
    }
    return null;
  }

  /// Ajoute un oiseau au cache (pour les données préchargées)
  static void addBirdToCache(String birdName, Bird bird) {
    _birdCache[birdName] = bird;
    if (kDebugMode) debugPrint('✅ Oiseau ajouté au cache: $birdName');
  }
  
  /// Retourne tous les noms d'oiseaux disponibles dans le cache
  static List<String> getAllBirdNames() {
    return _birdCache.keys.toList();
  }
  
  /// Méthode de test pour vérifier le chargement des données
  static void debugBirdCache() {
    if (kDebugMode) {
      debugPrint('🔍 Debug du cache Birdify:');
      debugPrint('   - Nombre d\'oiseaux en cache: ${_birdCache.length}');
      if (_birdCache.isNotEmpty) {
        debugPrint('   - Oiseaux en cache: ${_birdCache.keys.toList()}');
      }
    }
  }
  
  /// Nettoie le cache audio
  static void clearAudioCache() {
    for (final player in _audioCache.values) {
      player.dispose();
    }
    _audioCache.clear();
    if (kDebugMode) debugPrint('🗑️ Cache audio nettoyé');
  }
  
  /// Nettoie tout le cache
  static void clearAllCache() {
    clearAudioCache();
    _birdCache.clear();
    _imageCache.clear();
    _loadingStatus.clear();
    if (kDebugMode) debugPrint('🗑️ Tout le cache nettoyé');
  }
  
  /// Parse une ligne CSV en tenant compte des guillemets
  static List<String> _parseCsvLine(String line) {
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
  static Map<String, String> _createCsvRow(List<String> headers, List<String> values) {
    final Map<String, String> row = {};
    for (int i = 0; i < headers.length && i < values.length; i++) {
      row[headers[i]] = values[i];
    }
    return row;
  }
  
  /// Vérifie si une mission est en cours de préchargement
  static bool isPreloading(String missionId) {
    return _loadingStatus[missionId] ?? false;
  }
  
  /// Marque une mission comme en cours de préchargement
  static void setPreloadingStatus(String missionId, bool loading) {
    _loadingStatus[missionId] = loading;
  }
} 