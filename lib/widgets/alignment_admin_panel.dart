import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show Clipboard, ClipboardData; // retiré
import '../data/bird_image_alignments.dart';
// import 'dart:convert' as dart_convert; // retiré
import '../ui/responsive/responsive.dart';

/// Panel d'administration pour gérer les alignements d'images
/// Permet de basculer entre mode dev et production
class AlignmentAdminPanel extends StatefulWidget {
  const AlignmentAdminPanel({super.key});

  @override
  State<AlignmentAdminPanel> createState() => _AlignmentAdminPanelState();
}

class _AlignmentAdminPanelState extends State<AlignmentAdminPanel> {
  // ignore: unused_field
  String _currentMode = 'development';
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      final mode = await BirdImageAlignments.getCurrentMode();
      final stats = await BirdImageAlignments.getCompleteStats();
      
      setState(() {
        _currentMode = mode;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Erreur lors du chargement: $e');
    }
  }

  Future<void> _lockAlignments() async {
    final confirm = await _showConfirmDialog(
      'Verrouiller les alignements',
      'Êtes-vous sûr de vouloir passer en mode production ?\n\n'
      'Cela va :\n'
      '• Sauvegarder tous les alignements calibrés\n'
      '• Masquer les interfaces de calibration\n'
      '• Verrouiller le système\n\n'
      'Cette action peut être annulée plus tard.',
    );

    if (!confirm) return;

    try {
      await BirdImageAlignments.lockAllAlignments();
      await _loadData();
      _showSuccessSnackBar('Alignements verrouillés en mode production !');
    } catch (e) {
      _showErrorSnackBar('Erreur lors du verrouillage: $e');
    }
  }

  Future<void> _unlockAlignments() async {
    final confirm = await _showConfirmDialog(
      'Déverrouiller les alignements',
      'Êtes-vous sûr de vouloir revenir en mode développement ?\n\n'
      'Cela va réactiver les interfaces de calibration.',
    );

    if (!confirm) return;

    try {
      await BirdImageAlignments.enableDevMode();
      await _loadData();
      _showSuccessSnackBar('Mode développement réactivé !');
    } catch (e) {
      _showErrorSnackBar('Erreur lors du déverrouillage: $e');
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        
        return Dialog(
          child: Container(
            width: m.dp(500, tabletFactor: 1.2),
            padding: EdgeInsets.all(m.dp(24, tabletFactor: 1.1)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text(
                  'Administration des alignements',
                  style: TextStyle(
                    fontSize: m.font(24, tabletFactor: 1.1),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF606D7C),
                  ),
                ),
                
                SizedBox(height: m.dp(24, tabletFactor: 1.1)),
                
                if (_loading) ...[
                  const Center(child: CircularProgressIndicator()),
                  SizedBox(height: m.dp(24, tabletFactor: 1.1)),
                ] else ...[
                  // Statut actuel
                  _buildStatusCard(m),
                  
                  SizedBox(height: m.dp(20, tabletFactor: 1.1)),
                  
                  // Statistiques
                  _buildStatsCard(m),
                  
                  SizedBox(height: m.dp(24, tabletFactor: 1.1)),
                  
                  // Actions
                  _buildActionButtons(m),
                ],
                
                SizedBox(height: m.dp(16, tabletFactor: 1.1)),
                
                // Bouton fermer
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(ResponsiveMetrics m) {
    final isLocked = _stats['is_locked'] ?? false;
    final color = isLocked ? Colors.red : Colors.green;
    final icon = isLocked ? Icons.lock : Icons.lock_open;
    final status = isLocked ? 'PRODUCTION (Verrouillé)' : 'DÉVELOPPEMENT (Calibration)';

    return Container(
      padding: EdgeInsets.all(m.dp(16, tabletFactor: 1.0)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(m.dp(12, tabletFactor: 1.0)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: m.dp(24, tabletFactor: 1.0)),
          SizedBox(width: m.dp(12, tabletFactor: 1.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode actuel',
                  style: TextStyle(
                    fontSize: m.font(14, tabletFactor: 1.0),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF606D7C),
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: m.font(18, tabletFactor: 1.0),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ResponsiveMetrics m) {
    return Container(
      padding: EdgeInsets.all(m.dp(16, tabletFactor: 1.0)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(m.dp(12, tabletFactor: 1.0)),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques',
            style: TextStyle(
              fontSize: m.font(16, tabletFactor: 1.0),
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
              color: const Color(0xFF606D7C),
            ),
          ),
          
          SizedBox(height: m.dp(12, tabletFactor: 1.0)),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  m, 
                  'Espèces sauvegardées', 
                  '${_stats['saved_alignments'] ?? 0}',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  m, 
                  'Temporaires', 
                  '${_stats['temp_alignments'] ?? 0}',
                  Colors.orange,
                ),
              ),
            ],
          ),
          
          SizedBox(height: m.dp(8, tabletFactor: 1.0)),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  m, 
                  'À gauche', 
                  '${_stats['left_aligned'] ?? 0}',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  m, 
                  'À droite', 
                  '${_stats['right_aligned'] ?? 0}',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  m, 
                  'Centrés', 
                  '${_stats['center_aligned'] ?? 0}',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ResponsiveMetrics m, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: m.font(20, tabletFactor: 1.0),
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: m.font(12, tabletFactor: 1.0),
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w500,
            color: const Color(0xFF606D7C),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons(ResponsiveMetrics m) {
    final isLocked = _stats['is_locked'] ?? false;
    
    final primaryButton = isLocked
        ? ElevatedButton.icon(
            onPressed: _unlockAlignments,
            icon: const Icon(Icons.lock_open),
            label: const Text('Réactiver le mode développement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _lockAlignments,
            icon: const Icon(Icons.lock),
            label: const Text('Verrouiller en mode production'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primaryButton,
        SizedBox(height: m.dp(12, tabletFactor: 1.0)),
        Wrap(
          spacing: m.dp(8, tabletFactor: 1.0),
          runSpacing: m.dp(8, tabletFactor: 1.0),
          children: [
            // Actions JSON retirées (cadrages intégrés en dur désormais)
          ],
        ),
      ],
    );
  }

  Future<void> _exportAlignments() async {
    try {
      final data = await BirdImageAlignments.exportCalibratedAlignments();
      final jsonString = _prettyJson(data);
      // Montrer un dialog avec copie
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export des cadrages'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: SelectableText(jsonString, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Erreur export: $e');
    }
  }

  Future<void> _importAlignments() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer des cadrages (JSON)'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 14,
            decoration: const InputDecoration(hintText: '{ "genus_species": 0.25, ... }'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importer')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final Map<String, dynamic> decoded = <String, dynamic>{};
      final Map<String, double> casted = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      await BirdImageAlignments.importAlignments(casted);
      await _loadData();
      _showSuccessSnackBar('Cadrages importés (${casted.length})');
    } catch (e) {
      _showErrorSnackBar('JSON invalide: $e');
    }
  }

  String _prettyJson(Map<String, double> data) {
    return data.toString();
  }

  Future<void> _showCalibratedSpecies() async {
    try {
      final map = await BirdImageAlignments.exportCalibratedAlignments();
      final entries = map.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final buffer = StringBuffer();
      for (final e in entries) {
        buffer.writeln('${e.key}: ${e.value.toStringAsFixed(2)}');
      }
      final text = buffer.isEmpty ? 'Aucune espèce calibrée pour le moment.' : buffer.toString();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Espèces calibrées'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la récupération: $e');
    }
  }
}
