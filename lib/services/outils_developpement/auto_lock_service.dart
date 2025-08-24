import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../data/bird_image_alignments.dart';
import '../../data/bird_alignment_storage.dart';

/// Service d'auto-verrouillage des alignements d'images
/// 
/// Ce service vérifie au démarrage de l'application si des alignements
/// ont été calibrés et passe automatiquement en mode production.
/// 
/// UTILISATION:
/// - Appelez AutoLockService.initialize() dans main() ou dans initState() 
///   de votre widget principal
/// - Le système sera automatiquement verrouillé si des calibrations existent
class AutoLockService {
  static bool _isInitialized = false;
  
  /// Initialise le service d'auto-verrouillage
  /// 
  /// Cette méthode doit être appelée une seule fois au démarrage de l'application
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    try {
      await _checkAndLockIfNeeded();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'initialisation du service d\'auto-verrouillage: $e');
      }
    }
  }
  
  /// Vérifie s'il faut verrouiller le système
  static Future<void> _checkAndLockIfNeeded() async {
    // Vérifier le mode actuel
    final currentMode = await BirdAlignmentStorage.getCurrentMode();
    
    // Si déjà en mode production, rien à faire
    if (currentMode == BirdAlignmentStorage.MODE_PRODUCTION) {
      if (kDebugMode) {
        debugPrint('🔒 Système déjà en mode production');
      }
      return;
    }
    
    // Vérifier s'il y a des alignements calibrés
    final stats = await BirdAlignmentStorage.getStats();
    final totalCalibratedAlignments = stats['total_calibrated'] as int;
    
    if (totalCalibratedAlignments > 0) {
      // Il y a des alignements calibrés, verrouiller le système
      await BirdImageAlignments.lockAllAlignments();
      
      if (kDebugMode) {
        debugPrint('🔒 Système automatiquement verrouillé en mode production');
        debugPrint('📊 Alignements conservés: $totalCalibratedAlignments espèces');
      }
    } else {
      if (kDebugMode) {
        debugPrint('🔓 Aucun alignement calibré, reste en mode développement');
      }
    }
  }
  
  /// Force le verrouillage du système (même sans alignements calibrés)
  static Future<void> forceLock() async {
    await BirdImageAlignments.lockAllAlignments();
    
    if (kDebugMode) {
      debugPrint('🔒 Système forcé en mode production');
    }
  }
  
  /// Force le déverrouillage du système (retour en mode développement)
  static Future<void> forceUnlock() async {
    await BirdImageAlignments.enableDevMode();
    
    if (kDebugMode) {
      debugPrint('🔓 Système forcé en mode développement');
    }
  }
  
  /// Obtient le statut actuel du système
  static Future<Map<String, dynamic>> getSystemStatus() async {
    final mode = await BirdAlignmentStorage.getCurrentMode();
    final stats = await BirdAlignmentStorage.getStats();
    final isProduction = mode == BirdAlignmentStorage.MODE_PRODUCTION;
    
    return {
      'mode': mode,
      'is_production': isProduction,
      'is_development': !isProduction,
      'total_calibrated': stats['total_calibrated'],
      'left_aligned': stats['left_aligned'],
      'right_aligned': stats['right_aligned'],
      'center_aligned': stats['center_aligned'],
      'auto_locked': _isInitialized && isProduction,
    };
  }
  
  /// Affiche un rapport complet du système
  static Future<void> printSystemReport() async {
    if (!kDebugMode) return;
    
    final status = await getSystemStatus();
    
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════╗');
    debugPrint('║           RAPPORT SYSTÈME CADRAGE        ║');
    debugPrint('╠═══════════════════════════════════════════╣');
    debugPrint('║ Mode: ${status['mode'].toString().padRight(35)}║');
    debugPrint('║ État: ${(status['is_production'] ? 'PRODUCTION (verrouillé)' : 'DÉVELOPPEMENT (calibrage)').padRight(35)}║');
    debugPrint('║ Auto-verrouillé: ${(status['auto_locked'] ? 'OUI' : 'NON').padRight(27)}║');
    debugPrint('╠═══════════════════════════════════════════╣');
    debugPrint('║ Total calibré: ${status['total_calibrated'].toString().padRight(29)}║');
    debugPrint('║ Alignés à gauche: ${status['left_aligned'].toString().padRight(25)}║');
    debugPrint('║ Alignés à droite: ${status['right_aligned'].toString().padRight(25)}║');
    debugPrint('║ Alignés au centre: ${status['center_aligned'].toString().padRight(24)}║');
    debugPrint('╚═══════════════════════════════════════════╝');
    debugPrint('');
  }
}

/// Extension pour faciliter l'utilisation dans main.dart
extension AutoLockInitializer on Widget {
  /// Initialise automatiquement le service d'auto-verrouillage
  /// 
  /// Utilisez cette extension dans votre widget principal :
  /// ```dart
  /// class MyApp extends StatelessWidget {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return MaterialApp(...).withAutoLock();
  ///   }
  /// }
  /// ```
  Widget withAutoLock() {
    // Initialiser le service en arrière-plan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AutoLockService.initialize();
    });
    
    return this;
  }
}
