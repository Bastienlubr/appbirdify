import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

/// Service pour gérer le cache des images préchargées
/// Permet d'avoir des images instantanément disponibles pour les animations
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Cache des images préchargées
  final Map<String, ImageProvider> _imageCache = {};
  final Map<String, bool> _loadingStatus = {};

  // Mappings pour images locales (fusion de LocalImageService)
  final Map<String, String> _localImageCache = {};
  final Map<String, String> _birdNameToCodeCache = {};

  // Configuration des images locales
  static const String _localImagePrefix = 'assets/Missionhome/Images/';
  static const List<String> _supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];

  /// Précharge une image et la stocke en cache
  Future<void> preloadImage(String imageUrl, BuildContext context) async {
    final String url = _sanitizeUrlForWeb(imageUrl);
    if (_imageCache.containsKey(url)) {
      if (kDebugMode) debugPrint('✅ Image déjà en cache: $url');
      return;
    }

    if (_loadingStatus[url] == true) {
      if (kDebugMode) debugPrint('⏳ Image en cours de chargement: $url');
      return;
    }

    try {
      _loadingStatus[url] = true;
      
      if (kDebugMode) debugPrint('🔄 Préchargement image: $url');
      
      final imageProvider = NetworkImage(url);
      await precacheImage(imageProvider, context);
      
      _imageCache[url] = imageProvider;
      _loadingStatus[url] = false;
      
      if (kDebugMode) debugPrint('✅ Image préchargée et mise en cache: $url');
      
    } catch (e) {
      _loadingStatus[url] = false;
      if (kDebugMode) debugPrint('❌ Erreur préchargement image $url: $e');
      rethrow;
    }
  }

  /// Précharge plusieurs images en parallèle
  Future<void> preloadImages(List<String> imageUrls, BuildContext context) async {
    final futures = <Future<void>>[];
    
    for (final imageUrl in imageUrls) {
      futures.add(preloadImage(imageUrl, context));
    }
    
    await Future.wait(futures);
  }

  /// Récupère une image du cache
  ImageProvider? getCachedImage(String imageUrl) {
    return _imageCache[imageUrl];
  }

  /// Vérifie si une image est en cache
  bool isImageCached(String imageUrl) {
    return _imageCache.containsKey(imageUrl);
  }

  /// Vérifie si une image est en cours de chargement
  bool isImageLoading(String imageUrl) {
    return _loadingStatus[imageUrl] == true;
  }

  /// Nettoie le cache
  void clearCache() {
    _imageCache.clear();
    _loadingStatus.clear();
    if (kDebugMode) debugPrint('🗑️ Cache d\'images nettoyé');
  }

  /// Retourne le nombre d'images en cache
  int get cacheSize => _imageCache.length;

  /// Retourne toutes les URLs en cache
  List<String> get cachedUrls => _imageCache.keys.toList();

  // === Fonctions issues de LocalImageService (mappings locaux) ===

  /// Initialise les mappings d'images locales depuis les CSV (missions et questions)
  Future<void> initializeLocalMappings() async {
    try {
      await _loadLocalImageMappings();
    } catch (_) {}
  }

  Future<void> _loadLocalImageMappings() async {
    try {
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
          final imageCode = _generateImageCode(missionId, i);
          _birdNameToCodeCache[birdName] = imageCode;
          final localImagePath = await _findLocalImage(imageCode);
          if (localImagePath != null) {
            _localImageCache[birdName] = localImagePath;
          }
        }
      }
    } catch (_) {}
  }

  String _generateImageCode(String missionId, int index) {
    final prefix = missionId.substring(0, 1);
    final number = index.toString().padLeft(2, '0');
    return '$prefix$number';
  }

  Future<String?> _findLocalImage(String imageCode) async {
    for (final extension in _supportedExtensions) {
      final imagePath = '$_localImagePrefix$imageCode$extension';
      try {
        await rootBundle.load(imagePath);
        return imagePath;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String? getLocalImagePath(String birdName) {
    return _localImageCache[birdName];
  }

  bool hasLocalImage(String birdName) {
    return _localImageCache.containsKey(birdName);
  }

  ImageProvider? getImageProvider(String birdName) {
    final localPath = getLocalImagePath(birdName);
    if (localPath != null) {
      return AssetImage(localPath);
    }
    return null;
  }

  /// ImageProvider priorisant local > réseau > placeholder
  ImageProvider getOptimizedImageProvider({required String birdName, String? networkUrl, String placeholder = 'assets/Images/Milieu/placeholder_bird.png'}) {
    final localPath = getLocalImagePath(birdName);
    if (localPath != null) {
      return AssetImage(localPath);
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return NetworkImage(_sanitizeUrlForWeb(networkUrl));
    }
    return AssetImage(placeholder);
  }

  /// Encode minimal pour éviter les erreurs navigateur (apostrophe, espace)
  String _sanitizeUrlForWeb(String raw) {
    if (!kIsWeb) return raw;
    String url = raw;
    if (url.contains("'")) url = url.replaceAll("'", '%27');
    if (url.contains(' ')) url = url.replaceAll(' ', '%20');
    return url;
  }
} 