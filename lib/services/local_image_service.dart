import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import '../models/bird.dart';

/// Service pour gérer les images locales et fournir des fallbacks
class LocalImageService {
  static final LocalImageService _instance = LocalImageService._internal();
  factory LocalImageService() => _instance;
  LocalImageService._internal();

  // Cache pour les mappings nom d'oiseau -> image locale
  final Map<String, String> _localImageCache = {};
  final Map<String, String> _birdNameToCodeCache = {};
  
  // Configuration des images locales
  static const String _localImagePrefix = 'assets/Missionhome/Images/';
  static const List<String> _supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
  
  /// Initialise le service en chargeant les mappings d'images locales
  Future<void> initialize() async {
    try {
      // Scan optionnel retiré du démarrage; laisser vide pour éviter les logs inutiles.
      await _loadLocalImageMappings();
    } catch (_) {}
  }

  /// Charge les mappings d'images locales depuis les fichiers de mission
  Future<void> _loadLocalImageMappings() async {
    try {
      // Charger le fichier de structure des missions
      final String csvString = await rootBundle.loadString('assets/Missionhome/missions_structure.csv');
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      
      if (csvTable.isEmpty) return;
      
      final headers = csvTable[0].map((e) => e.toString()).toList();
      
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty) continue;
        
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          csvRow[headers[j]] = row[j]?.toString() ?? '';
        }
        
        final missionId = csvRow['id_mission'];
        if (missionId != null && missionId.isNotEmpty) {
          await _loadMissionImages(missionId);
        }
      }
    } catch (_) {}
  }

  /// Charge les images d'une mission spécifique
  Future<void> _loadMissionImages(String missionId) async {
    try {
      final csvPath = 'assets/Missionhome/questionMission/$missionId.csv';
      final csvString = await rootBundle.loadString(csvPath);
      
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      if (csvTable.isEmpty) return;
      
      final headers = csvTable[0].map((e) => e.toString()).toList();
      
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty) continue;
        
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          csvRow[headers[j]] = row[j]?.toString() ?? '';
        }
        
        final birdName = csvRow['bonne_reponse']?.trim();
        if (birdName != null && birdName.isNotEmpty) {
          // Créer un code d'image basé sur la mission et l'index
          final imageCode = _generateImageCode(missionId, i);
          _birdNameToCodeCache[birdName] = imageCode;
          
          // Vérifier si l'image locale existe
          final localImagePath = await _findLocalImage(imageCode);
          if (localImagePath != null) {
            _localImageCache[birdName] = localImagePath;
          }
        }
      }
    } catch (_) {}
  }

  /// Génère un code d'image basé sur l'ID de mission et l'index
  String _generateImageCode(String missionId, int index) {
    // Format: A01, A02, etc. pour les missions A
    // Format: F01, F02, etc. pour les missions F
    // etc.
    final prefix = missionId.substring(0, 1);
    final number = index.toString().padLeft(2, '0');
    return '$prefix$number';
  }

  /// Trouve une image locale pour un code donné
  Future<String?> _findLocalImage(String imageCode) async {
    for (final extension in _supportedExtensions) {
      final imagePath = '$_localImagePrefix$imageCode$extension';
      try {
        // Vérifier si le fichier existe en essayant de le charger
        await rootBundle.load(imagePath);
        return imagePath;
      } catch (e) {
        // Le fichier n'existe pas, continuer avec l'extension suivante
        continue;
      }
    }
    return null;
  }

  /// Récupère le chemin d'une image locale pour un oiseau
  String? getLocalImagePath(String birdName) {
    return _localImageCache[birdName];
  }

  /// Récupère le code d'image pour un oiseau
  String? getImageCode(String birdName) {
    return _birdNameToCodeCache[birdName];
  }

  /// Vérifie si une image locale existe pour un oiseau
  bool hasLocalImage(String birdName) {
    return _localImageCache.containsKey(birdName);
  }

  /// Récupère une ImageProvider pour un oiseau (locale ou fallback)
  ImageProvider? getImageProvider(String birdName) {
    final localPath = getLocalImagePath(birdName);
    if (localPath != null) {
      return AssetImage(localPath);
    }
    return null;
  }

  /// Récupère une ImageProvider avec fallback vers une image par défaut
  ImageProvider getImageProviderWithFallback(String birdName) {
    final localPath = getLocalImagePath(birdName);
    if (localPath != null) {
      return AssetImage(localPath);
    }
    
    // Fallback vers une image par défaut
    return const AssetImage('assets/Images/Milieu/placeholder_bird.png');
  }

  /// Liste tous les oiseaux qui ont des images locales
  List<String> getBirdsWithLocalImages() {
    return _localImageCache.keys.toList();
  }

  /// Nettoie le cache
  void clearCache() {
    _localImageCache.clear();
    _birdNameToCodeCache.clear();
    // Silent
  }

  /// Debug: affiche les mappings d'images
  void debugImageMappings() {
    if (kDebugMode) {
      debugPrint('🔍 Debug mappings images locales:');
      debugPrint('   - Nombre de mappings: ${_localImageCache.length}');
      if (_localImageCache.isNotEmpty) {
        debugPrint('   - Premiers mappings:');
        final entries = _localImageCache.entries.take(5);
        for (final entry in entries) {
          debugPrint('     ${entry.key} -> ${entry.value}');
        }
      }
    }
  }
}

/// Extension pour ajouter des méthodes utilitaires aux objets Bird
extension BirdImageExtension on Bird {
  /// Récupère le chemin d'une image locale pour cet oiseau
  String? get localImagePath {
    return LocalImageService().getLocalImagePath(nomFr);
  }

  /// Vérifie si cet oiseau a une image locale
  bool get hasLocalImage {
    return LocalImageService().hasLocalImage(nomFr);
  }

  /// Récupère une ImageProvider pour cet oiseau (locale ou Firebase)
  ImageProvider get imageProvider {
    final localService = LocalImageService();
    
    // Essayer d'abord l'image locale
    if (localService.hasLocalImage(nomFr)) {
      return localService.getImageProvider(nomFr)!;
    }
    
    // Fallback vers l'image Firebase
    if (urlImage.isNotEmpty) {
      return NetworkImage(urlImage);
    }
    
    // Fallback vers une image par défaut
    return const AssetImage('assets/Images/Milieu/placeholder_bird.png');
  }

  /// Récupère une ImageProvider avec priorité locale
  ImageProvider get optimizedImageProvider {
    final localService = LocalImageService();
    
    // Priorité 1: Image locale
    if (localService.hasLocalImage(nomFr)) {
      return localService.getImageProvider(nomFr)!;
    }
    
    // Priorité 2: Image Firebase
    if (urlImage.isNotEmpty) {
      return NetworkImage(urlImage);
    }
    
    // Priorité 3: Image par défaut
    return const AssetImage('assets/Images/Milieu/placeholder_bird.png');
  }
} 
} 