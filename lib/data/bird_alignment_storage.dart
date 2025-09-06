import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Système de stockage persistant des alignements d'oiseaux calibrés
/// Sauvegarde automatiquement tous les ajustements en local
class BirdAlignmentStorage {
  static const String _storageKey = 'bird_alignments_calibrated';
  static const String _modeKey = 'alignment_mode';
  static const String _versionKey = 'alignment_version';
  
  static Map<String, double>? _cachedAlignments;
  static bool? _isDevMode;
  
  /// Mode développement (interfaces de calibration visibles)
  static const String modeDev = 'development';
  
  /// Mode production (alignements verrouillés, pas d'interface)
  static const String modeProduction = 'production';
  
  /// Sauvegarde un alignement calibré
  static Future<void> saveAlignment(String genus, String species, double alignment) async {
    try {
      final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
      
      // Charger les alignements existants
      final alignments = await _loadAlignments();
      
      // Ajouter le nouvel alignement
      alignments[key] = alignment;
      
      // Sauvegarder
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(alignments);
      await prefs.setString(_storageKey, jsonData);
      
      // Mettre à jour le cache
      _cachedAlignments = alignments;
      
      // Log pour suivi
      if (kDebugMode) {
        final alignmentDesc = _getAlignmentDescription(alignment);
        debugPrint('💾 Alignement sauvegardé: $key → $alignmentDesc (${alignment.toStringAsFixed(2)})');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur sauvegarde alignement: $e');
      }
    }
  }
  
  /// Charge un alignement sauvegardé
  static Future<double?> loadAlignment(String genus, String species) async {
    try {
      final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
      final alignments = await _loadAlignments();
      return alignments[key];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur chargement alignement: $e');
      }
      return null;
    }
  }
  
  /// Charge tous les alignements sauvegardés
  static Future<Map<String, double>> _loadAlignments() async {
    if (_cachedAlignments != null) {
      return _cachedAlignments!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_storageKey);
      
      if (jsonData != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonData);
        _cachedAlignments = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
        return _cachedAlignments!;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur chargement alignements: $e');
      }
    }
    
    _cachedAlignments = <String, double>{};
    return _cachedAlignments!;
  }
  
  /// Obtient le mode actuel (dev ou production)
  static Future<String> getCurrentMode() async {
    if (_isDevMode != null) {
      return _isDevMode! ? modeDev : modeProduction;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_modeKey) ?? modeProduction; // Par défaut en production (UI recadrage masquée)
      _isDevMode = (mode == modeDev);
      return mode;
    } catch (e) {
      return modeDev;
    }
  }
  
  /// Définit le mode (dev ou production)
  static Future<void> setMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode);
      _isDevMode = (mode == modeDev);
      
      if (kDebugMode) {
        debugPrint('🔧 Mode alignement changé: $mode');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur changement mode: $e');
      }
    }
  }
  
  /// Vérifie si on est en mode développement
  static Future<bool> isDevMode() async {
    final mode = await getCurrentMode();
    return mode == modeDev;
  }
  
  /// Verrouille les alignements (passage en mode production)
  static Future<void> lockAlignments() async {
    await setMode(modeProduction);
    
    // Sauvegarder la version de verrouillage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, DateTime.now().toIso8601String());
    
    if (kDebugMode) {
      final alignments = await _loadAlignments();
      debugPrint('🔒 Alignements verrouillés - ${alignments.length} espèces calibrées');
    }
  }
  
  /// Déverrouille les alignements (retour en mode dev)
  static Future<void> unlockAlignments() async {
    await setMode(modeDev);
    
    if (kDebugMode) {
      debugPrint('🔓 Alignements déverrouillés - mode dev activé');
    }
  }
  
  /// Exporte tous les alignements calibrés (pour backup)
  static Future<Map<String, double>> exportAlignments() async {
    return await _loadAlignments();
  }
  
  /// Importe des alignements (pour restauration)
  static Future<void> importAlignments(Map<String, double> alignments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(alignments);
      await prefs.setString(_storageKey, jsonData);
      
      _cachedAlignments = alignments;
      
      if (kDebugMode) {
        debugPrint('📥 ${alignments.length} alignements importés');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur import alignements: $e');
      }
    }
  }
  
  /// Obtient les statistiques des alignements sauvegardés
  static Future<Map<String, dynamic>> getStats() async {
    final alignments = await _loadAlignments();
    final mode = await getCurrentMode();
    
    final leftCount = alignments.values.where((v) => v < -0.1).length;
    final rightCount = alignments.values.where((v) => v > 0.1).length;
    final centerCount = alignments.values.where((v) => v.abs() <= 0.1).length;
    
    return {
      'mode': mode,
      'total_calibrated': alignments.length,
      'left_aligned': leftCount,
      'right_aligned': rightCount,
      'center_aligned': centerCount,
      'is_locked': mode == modeProduction,
    };
  }
  
  /// Efface tous les alignements sauvegardés
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      _cachedAlignments = null;
      
      if (kDebugMode) {
        debugPrint('🗑️ Tous les alignements effacés');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur effacement alignements: $e');
      }
    }
  }
  
  /// Description textuelle d'un alignement
  static String _getAlignmentDescription(double value) {
    if (value < -0.5) return 'TRÈS À GAUCHE';
    if (value < -0.2) return 'À GAUCHE';
    if (value < -0.05) return 'LÉGÈREMENT À GAUCHE';
    if (value > 0.5) return 'TRÈS À DROITE';
    if (value > 0.2) return 'À DROITE';
    if (value > 0.05) return 'LÉGÈREMENT À DROITE';
    return 'CENTRÉ';
  }
}
