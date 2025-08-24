import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/bird.dart';
import '../ui/responsive/responsive.dart';
import '../data/bird_image_alignments.dart';

/// Dialog de calibration visuelle d'alignement d'image
class AlignmentCalibrationDialog extends StatefulWidget {
  final Bird bird;
  final double currentAlignment;
  final Function(double) onAlignmentChanged;
  final Function(double)? onPreviewAlignment;
  
  const AlignmentCalibrationDialog({
    super.key,
    required this.bird,
    required this.currentAlignment,
    required this.onAlignmentChanged,
    this.onPreviewAlignment,
  });

  @override
  State<AlignmentCalibrationDialog> createState() => _AlignmentCalibrationDialogState();
}

class _AlignmentCalibrationDialogState extends State<AlignmentCalibrationDialog> {
  late double _currentValue;
  late double _originalValue;
  bool _showPreview = true;
  bool _isValidating = false;
  
  @override
  void initState() {
    super.initState();
    _currentValue = widget.currentAlignment;
    _originalValue = widget.currentAlignment;
    
    // Activer immédiatement le mode preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPreviewAlignment?.call(_currentValue);
    });
  }
  
  /// Restore l'alignement original
  void _restoreOriginalAlignment() {
    if (widget.onPreviewAlignment != null) {
      widget.onPreviewAlignment!(_originalValue);
    }
  }
  
  Alignment get _previewAlignment => Alignment(_currentValue, 0.0);
  
  String get _alignmentDescription {
    // Utiliser la valeur actuelle du curseur pour la description
    if (_currentValue < -0.5) return 'TRÈS À GAUCHE';
    if (_currentValue < -0.2) return 'À GAUCHE';
    if (_currentValue < -0.05) return 'LÉGÈREMENT À GAUCHE';
    if (_currentValue > 0.5) return 'TRÈS À DROITE';
    if (_currentValue > 0.2) return 'À DROITE';
    if (_currentValue > 0.05) return 'LÉGÈREMENT À DROITE';
    return 'CENTRÉ';
  }
  
  Color get _alignmentColor {
    if (_currentValue < -0.1) return Colors.blue;
    if (_currentValue > 0.1) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: m.dp(400, tabletFactor: 1.2),
            padding: EdgeInsets.all(m.dp(24, tabletFactor: 1.1)),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F9),
              borderRadius: BorderRadius.circular(m.dp(20, tabletFactor: 1.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre
                Text(
                  'Calibrage d\'alignement',
                  style: TextStyle(
                    color: const Color(0xFF606D7C),
                    fontSize: m.font(24, tabletFactor: 1.1),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                
                SizedBox(height: m.dp(8, tabletFactor: 1.0)),
                
                // Nom de l'espèce
                Text(
                  widget.bird.nomFr,
                  style: TextStyle(
                    color: const Color(0xFF606D7C),
                    fontSize: m.font(16, tabletFactor: 1.0),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                SizedBox(height: m.dp(20, tabletFactor: 1.1)),
                
                // Aperçu de l'image avec alignement
                Container(
                  height: m.dp(200, tabletFactor: 1.2),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(m.dp(12, tabletFactor: 1.0)),
                    border: Border.all(
                      color: _alignmentColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(m.dp(10, tabletFactor: 1.0)),
                    child: widget.bird.urlImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.bird.urlImage,
                            fit: BoxFit.cover,
                            alignment: _previewAlignment,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFFD2DBB2),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFD2DBB2),
                              child: const Center(
                                child: Icon(Icons.image_not_supported),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFD2DBB2),
                            child: const Center(
                              child: Icon(Icons.image, size: 32),
                            ),
                          ),
                  ),
                ),
                
                SizedBox(height: m.dp(20, tabletFactor: 1.1)),
                
                // Indicateur d'alignement actuel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _alignmentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(m.dp(12, tabletFactor: 1.0)),
                    border: Border.all(
                      color: _alignmentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _currentValue < -0.1 
                            ? Icons.keyboard_arrow_left
                            : _currentValue > 0.1 
                                ? Icons.keyboard_arrow_right
                                : Icons.center_focus_weak,
                        color: _alignmentColor,
                        size: m.dp(20, tabletFactor: 1.0),
                      ),
                      SizedBox(width: m.dp(8, tabletFactor: 1.0)),
                      Text(
                        _alignmentDescription,
                        style: TextStyle(
                          color: _alignmentColor,
                          fontSize: m.font(16, tabletFactor: 1.0),
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: m.dp(16, tabletFactor: 1.1)),
                
                // Curseur d'ajustement
                Column(
                  children: [
                    Text(
                      'Valeur: ${_currentValue.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: const Color(0xFF606D7C),
                        fontSize: m.font(14, tabletFactor: 1.0),
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    SizedBox(height: m.dp(8, tabletFactor: 1.0)),
                    
                    Slider(
                      value: _currentValue,
                      min: -1.0,
                      max: 1.0,
                      divisions: 40, // 0.05 de précision
                      activeColor: _alignmentColor,
                      inactiveColor: _alignmentColor.withValues(alpha: 0.3),
                      onChanged: (value) {
                        setState(() {
                          _currentValue = value;
                        });
                        
                        // Aperçu en temps réel sur l'image de fond
                        widget.onPreviewAlignment?.call(value);
                      },
                    ),
                    
                    // Légendes du curseur
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: m.dp(16, tabletFactor: 1.0)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GAUCHE',
                            style: TextStyle(
                              color: Colors.blue.withValues(alpha: 0.7),
                              fontSize: m.font(12, tabletFactor: 1.0),
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'CENTRE',
                            style: TextStyle(
                              color: Colors.green.withValues(alpha: 0.7),
                              fontSize: m.font(12, tabletFactor: 1.0),
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'DROITE',
                            style: TextStyle(
                              color: Colors.orange.withValues(alpha: 0.7),
                              fontSize: m.font(12, tabletFactor: 1.0),
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: m.dp(24, tabletFactor: 1.1)),
                
                // Boutons d'action
                Row(
                  children: [
                    // Bouton Reset
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          BirdImageAlignments.resetAlignment(widget.bird.genus, widget.bird.species);
                          final newValue = BirdImageAlignments.getFineAlignment(widget.bird.genus, widget.bird.species);
                          setState(() {
                            _currentValue = newValue;
                          });
                          
                          // Aperçu immédiat du reset
                          widget.onPreviewAlignment?.call(newValue);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(m.dp(8, tabletFactor: 1.0)),
                          ),
                        ),
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: const Color(0xFF606D7C),
                            fontSize: m.font(14, tabletFactor: 1.0),
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: m.dp(12, tabletFactor: 1.0)),
                    
                    // Bouton Annuler
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          // Restaurer l'alignement original
                          _restoreOriginalAlignment();
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(m.dp(8, tabletFactor: 1.0)),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: TextStyle(
                            color: const Color(0xFF606D7C),
                            fontSize: m.font(14, tabletFactor: 1.0),
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: m.dp(12, tabletFactor: 1.0)),
                    
                    // Bouton Valider
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isValidating ? null : () async {
                          // 1. Marquer comme en cours de validation
                          setState(() => _isValidating = true);
                          
                          // 2. Mettre à jour l'image immédiatement (effet visible instantané)
                          widget.onAlignmentChanged(_currentValue);
                          
                          // 3. Feedback visuel de confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Alignement sauvegardé pour ${widget.bird.nomFr}',
                                style: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: _alignmentColor,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          
                          // 4. Log de confirmation avant fermeture
                          assert(() {
                            debugPrint('🔄 Validation terminée, fermeture dans 500ms');
                            return true;
                          }());
                          
                          // 5. Délai pour voir l'effet avant fermeture
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // 5. Fermer le dialog
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _alignmentColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(m.dp(8, tabletFactor: 1.0)),
                          ),
                        ),
                        child: _isValidating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: m.dp(16, tabletFactor: 1.0),
                                  height: m.dp(16, tabletFactor: 1.0),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: m.dp(8, tabletFactor: 1.0)),
                                Text(
                                  'Application...',
                                  style: TextStyle(
                                    fontSize: m.font(14, tabletFactor: 1.0),
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: m.dp(18, tabletFactor: 1.0),
                                ),
                                SizedBox(width: m.dp(6, tabletFactor: 1.0)),
                                Text(
                                  'Valider',
                                  style: TextStyle(
                                    fontSize: m.font(14, tabletFactor: 1.0),
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
