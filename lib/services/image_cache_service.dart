import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer le cache des images préchargées
/// Permet d'avoir des images instantanément disponibles pour les animations
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Cache des images préchargées
  final Map<String, ImageProvider> _imageCache = {};
  final Map<String, bool> _loadingStatus = {};

  /// Précharge une image et la stocke en cache
  Future<void> preloadImage(String imageUrl, BuildContext context) async {
    if (_imageCache.containsKey(imageUrl)) {
      if (kDebugMode) debugPrint('✅ Image déjà en cache: $imageUrl');
      return;
    }

    if (_loadingStatus[imageUrl] == true) {
      if (kDebugMode) debugPrint('⏳ Image en cours de chargement: $imageUrl');
      return;
    }

    try {
      _loadingStatus[imageUrl] = true;
      
      if (kDebugMode) debugPrint('🔄 Préchargement image: $imageUrl');
      
      final imageProvider = NetworkImage(imageUrl);
      await precacheImage(imageProvider, context);
      
      _imageCache[imageUrl] = imageProvider;
      _loadingStatus[imageUrl] = false;
      
      if (kDebugMode) debugPrint('✅ Image préchargée et mise en cache: $imageUrl');
      
    } catch (e) {
      _loadingStatus[imageUrl] = false;
      if (kDebugMode) debugPrint('❌ Erreur préchargement image $imageUrl: $e');
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
} 