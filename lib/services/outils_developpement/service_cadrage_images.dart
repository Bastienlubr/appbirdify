import 'package:flutter/material.dart';
import '../../data/bird_image_alignments.dart';
import '../../data/bird_alignment_storage.dart';
import '../../widgets/alignment_calibration_dialog.dart';
import '../../widgets/alignment_admin_panel.dart';
import '../../models/bird.dart';
import '../../ui/responsive/responsive.dart';

/// Service centralisé pour tous les outils de développement de cadrage d'images
/// 
/// Ce service regroupe :
/// - Interfaces de calibration d'alignement
/// - Panel d'administration  
/// - Logique de verrouillage dev/production
/// - Statistiques et gestion des alignements
/// 
/// ⚠️ OUTIL DE DÉVELOPPEMENT UNIQUEMENT
/// Ces interfaces ne doivent pas être visibles en production
class ServiceCadrageImages {
  
  // ===================================================================
  // VÉRIFICATION MODE ET ACCÈS
  // ===================================================================
  
  /// Vérifie si les outils de développement sont accessibles
  static Future<bool> isAccessible() async {
    return await BirdImageAlignments.isDevModeEnabled();
  }
  
  /// Force l'activation des outils de développement
  static Future<void> enableDevTools() async {
    await BirdImageAlignments.enableDevMode();
  }
  
  /// Désactive définitivement les outils de développement
  static Future<void> disableDevTools() async {
    await BirdImageAlignments.disableDevMode();
  }
  
  // ===================================================================
  // INTERFACES DE CALIBRATION
  // ===================================================================
  
  /// Affiche l'interface de calibration d'alignement pour un oiseau
  static Future<void> showAlignmentCalibration({
    required BuildContext context,
    required Bird bird,
    required Function(Alignment) onAlignmentChanged,
    Function(double)? onPreviewAlignment,
  }) async {
    // Capturer les dépendances UI avant tout await
    final messenger = ScaffoldMessenger.of(context);
    // Vérifier l'accès aux outils de dev
    final accessible = await isAccessible();
    if (!accessible) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Outils de développement désactivés en mode production',
            style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final currentAlignment = BirdImageAlignments.getFineAlignment(bird.genus, bird.species);
    
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlignmentCalibrationDialog(
        bird: bird,
        currentAlignment: currentAlignment,
        onAlignmentChanged: (newAlignment) async {
          // Sauvegarder l'alignement
          await BirdImageAlignments.calibrateAlignment(bird.genus, bird.species, newAlignment);
          
          // Notifier le changement à la page parent
          onAlignmentChanged(Alignment(newAlignment, 0.0));
          
          assert(() {
            debugPrint('🎯 [ServiceCadrage] Alignement sauvegardé: ${bird.nomFr} → ${newAlignment.toStringAsFixed(2)}');
            return true;
          }());
        },
        onPreviewAlignment: onPreviewAlignment,
      ),
    );
  }
  
  /// Affiche le panel d'administration des alignements
  static Future<void> showAdminPanel(BuildContext context) async {
    // Vérifier l'accès aux outils de dev
    final messenger = ScaffoldMessenger.of(context);
    final accessible = await isAccessible();
    if (!accessible) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Outils de développement désactivés en mode production',
            style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => const AlignmentAdminPanel(),
    );
  }
  
  /// Affiche l'indicateur d'alignement pour un oiseau (version développement)
  static Widget buildAlignmentIndicator({
    required BuildContext context,
    required Bird bird,
    required ResponsiveMetrics responsiveMetrics,
    required VoidCallback onSimpleTap,
    required VoidCallback onTripleTap,
  }) {
    final fineValue = BirdImageAlignments.getFineAlignment(bird.genus, bird.species);
    final alignmentDesc = BirdImageAlignments.getAlignmentDescription(bird.genus, bird.species);
    final hasCustom = BirdImageAlignments.hasCustomAlignment(bird.genus, bird.species);
    
    final color = fineValue < -0.1 
        ? Colors.blue
        : fineValue > 0.1 
            ? Colors.orange
            : Colors.green;
    
    int tapCount = 0;
    
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(responsiveMetrics.dp(20, tabletFactor: 1.1)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicateur d'alignement actuel
              GestureDetector(
                onTap: () {
                  tapCount++;
                  
                  // Triple-tap pour accéder au panel d'administration
                  if (tapCount >= 3) {
                    tapCount = 0;
                    onTripleTap();
                  } else {
                    // Réinitialiser le compteur après 2 secondes
                    Future.delayed(const Duration(seconds: 2), () {
                      tapCount = 0;
                    });
                    
                    // Simple tap pour calibration
                    onSimpleTap();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fineValue < -0.1 
                            ? Icons.keyboard_arrow_left
                            : fineValue > 0.1 
                                ? Icons.keyboard_arrow_right
                                : Icons.center_focus_weak,
                        color: Colors.white,
                        size: responsiveMetrics.dp(16, tabletFactor: 1.0),
                      ),
                      SizedBox(width: responsiveMetrics.dp(4, tabletFactor: 1.0)),
                      Text(
                        alignmentDesc,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: responsiveMetrics.font(12, tabletFactor: 1.0, min: 10, max: 14),
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasCustom) ...[
                        SizedBox(width: responsiveMetrics.dp(4, tabletFactor: 1.0)),
                        Icon(
                          Icons.star,
                          color: Colors.white,
                          size: responsiveMetrics.dp(12, tabletFactor: 1.0),
                        ),
                      ],
                      SizedBox(width: responsiveMetrics.dp(4, tabletFactor: 1.0)),
                      Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: responsiveMetrics.dp(14, tabletFactor: 1.0),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: responsiveMetrics.dp(6, tabletFactor: 1.0)),
              
              // Valeur numérique (debug)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  fineValue.toStringAsFixed(2),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsiveMetrics.font(10, tabletFactor: 1.0, min: 8, max: 12),
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ===================================================================
  // GESTION ET STATISTIQUES
  // ===================================================================
  
  /// Obtient les statistiques complètes des alignements
  static Future<Map<String, dynamic>> getStatistics() async {
    return await BirdImageAlignments.getCompleteStats();
  }
  
  /// Verrouille tous les alignements en mode production
  static Future<void> lockAllAlignments() async {
    await BirdImageAlignments.lockAllAlignments();
  }
  
  /// Déverrouille et réactive le mode développement
  static Future<void> unlockAlignments() async {
    await BirdImageAlignments.enableDevMode();
  }
  
  /// Exporte tous les alignements calibrés
  static Future<Map<String, double>> exportAlignments() async {
    return await BirdImageAlignments.exportCalibratedAlignments();
  }
  
  /// Importe des alignements
  static Future<void> importAlignments(Map<String, double> alignments) async {
    await BirdAlignmentStorage.importAlignments(alignments);
  }
  
  /// Efface tous les alignements (DANGEREUX)
  static Future<void> clearAllAlignments() async {
    await BirdAlignmentStorage.clearAll();
  }
  
  // ===================================================================
  // UTILITAIRES PRIVÉS
  // ===================================================================
  
  /// Affiche un message d'accès refusé
  // ignore: unused_element
  static void _showAccessDeniedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Outils de développement désactivés en mode production',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // ===================================================================
  // ACCÈS RAPIDE DÉVELOPPEMENT
  // ===================================================================
  
  /// Crée un menu flottant d'accès rapide aux outils de développement
  static Widget buildDevToolsFloatingMenu({
    required BuildContext context,
    required List<Bird> birds,
  }) {
    return FutureBuilder<bool>(
      future: isAccessible(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }
        
        return Positioned(
          bottom: 100,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: () => showAdminPanel(context),
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.developer_mode),
            label: const Text(
              'Cadrage DEV',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// Affiche un dialog de confirmation pour actions critiques
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
}

/// Extensions utilitaires pour le service de cadrage
extension ServiceCadrageExtensions on Bird {
  /// Obtient l'alignement optimal pour cet oiseau
  Alignment get optimalAlignment {
    return BirdImageAlignments.getOptimalAlignment(genus, species);
  }
  
  /// Vérifie si cet oiseau a un alignement personnalisé
  bool get hasCustomAlignment {
    return BirdImageAlignments.hasCustomAlignment(genus, species);
  }
  
  /// Obtient la description textuelle de l'alignement
  String get alignmentDescription {
    return BirdImageAlignments.getAlignmentDescription(genus, species);
  }
  
  /// Obtient la valeur fine de l'alignement
  double get fineAlignment {
    return BirdImageAlignments.getFineAlignment(genus, species);
  }
}
