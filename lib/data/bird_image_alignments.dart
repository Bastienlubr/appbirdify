import 'package:flutter/material.dart';
import 'bird_alignment_storage.dart';

/// Système intelligent et adaptatif de positionnement des images d'oiseaux
/// Utilise des alignements fins et peut apprendre des corrections utilisateur
/// Supporte les modes dev (calibration) et production (verrouillé)
class BirdImageAlignments {
  
  /// Alignements fins personnalisés (valeurs entre -1.0 et 1.0)
  /// -1.0 = complètement à gauche, 0.0 = centré, 1.0 = complètement à droite
  static final Map<String, double> _fineAlignments = {
    // ESPÈCES TESTÉES ET CALIBRÉES MANUELLEMENT
    'thalassarche_melanophris': 0.4,     // Albatros à sourcils noir (légèrement à droite)
    'prunella_collaris': -0.3,           // Accenteur alpin (légèrement à gauche)
    
    // AJOUTS FUTURS PAR CALIBRATION...
  };
  
  /// Historique des ajustements pour apprentissage
  static final Map<String, List<double>> _adjustmentHistory = {};
  
  /// Alignements de base par famille (fallback seulement)
  static const Map<String, double> _familyDefaults = {
    // Familles avec tendance gauche (valeurs négatives)
    'parus': -0.2,           // Mésanges
    'turdus': -0.15,         // Grives  
    'fringilla': -0.25,      // Pinsons
    'carduelis': -0.3,       // Chardonnerets
    'phylloscopus': -0.2,    // Pouillots
    'sylvia': -0.15,         // Fauvettes
    
    // Familles avec tendance droite (valeurs positives)  
    'corvus': 0.3,           // Corneilles
    'pica': 0.25,            // Pies
    'dendrocopos': 0.4,      // Pics
    'sturnus': 0.2,          // Étourneaux
    'ardea': 0.35,           // Hérons
    'motacilla_alba': 0.15,  // Bergeronnette grise spécifique
    
    // Familles centrées (proches de 0)
    'falco': 0.0,            // Faucons
    'buteo': 0.0,            // Buses
    'strix': 0.0,            // Chouettes
    'anas': 0.0,             // Canards
    'columba': 0.0,          // Pigeons
  };
  
  /// Convertit une valeur fine en Alignment Flutter
  static Alignment _doubleToAlignment(double value) {
    // Clamp la valeur entre -1.0 et 1.0
    final clampedValue = value.clamp(-1.0, 1.0);
    return Alignment(clampedValue, 0.0);
  }
  
  /// Obtient l'alignement fin pour une espèce (entre -1.0 et 1.0)
  static Future<double> _getFineAlignment(String genus, String species) async {
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    
    // 1. Priorité absolue : alignement sauvegardé (persistant)
    final savedAlignment = await BirdAlignmentStorage.loadAlignment(genus, species);
    if (savedAlignment != null) {
      return savedAlignment;
    }
    
    // 2. Alignement temporaire en cours de calibration
    if (_fineAlignments.containsKey(key)) {
      return _fineAlignments[key]!;
    }
    
    // 3. Chercher par famille (genre)
    final genusLower = genus.toLowerCase();
    if (_familyDefaults.containsKey(genusLower)) {
      return _familyDefaults[genusLower]!;
    }
    
    // 4. Chercher par nom spécifique complet (ex: motacilla_alba)
    for (final familyKey in _familyDefaults.keys) {
      if (key.startsWith(familyKey)) {
        return _familyDefaults[familyKey]!;
      }
    }
    
    // 5. Par défaut : centré
    return 0.0;
  }
  
  /// Enregistre un ajustement manuel pour apprentissage  
  static void recordAdjustment(String genus, String species, double newAlignment) {
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    
    // Enregistrer dans l'historique
    _adjustmentHistory[key] ??= [];
    _adjustmentHistory[key]!.add(newAlignment);
    
    // Garder seulement les 5 derniers ajustements
    if (_adjustmentHistory[key]!.length > 5) {
      _adjustmentHistory[key]!.removeAt(0);
    }
    
    // Mettre à jour l'alignement avec une moyenne pondérée
    _updateAlignmentFromHistory(key);
  }
  
  /// Met à jour l'alignement basé sur l'historique
  static void _updateAlignmentFromHistory(String key) {
    final history = _adjustmentHistory[key];
    if (history == null || history.isEmpty) return;
    
    // Calculer une moyenne pondérée (plus de poids aux ajustements récents)
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (int i = 0; i < history.length; i++) {
      final weight = i + 1; // Les plus récents ont plus de poids
      weightedSum += history[i] * weight;
      totalWeight += weight;
    }
    
    final newAlignment = weightedSum / totalWeight;
    _fineAlignments[key] = newAlignment.clamp(-1.0, 1.0);
  }
  
  /// Calibre manuellement un alignement pour une espèce
  static Future<void> calibrateAlignment(String genus, String species, double alignment) async {
    final clampedAlignment = alignment.clamp(-1.0, 1.0);
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    
    // 1. Mettre à jour le cache temporaire IMMÉDIATEMENT
    _fineAlignments[key] = clampedAlignment;
    
    // 2. Sauvegarder de manière persistante en arrière-plan
    try {
      await BirdAlignmentStorage.saveAlignment(genus, species, clampedAlignment);
    } catch (e) {
      // En cas d'erreur, la valeur reste dans le cache temporaire
      assert(() {
        debugPrint('❌ Erreur sauvegarde persistante: $e');
        return true;
      }());
    }
  }
  
  /// Obtient les statistiques d'utilisation
  static Map<String, dynamic> getUsageStats() {
    return {
      'calibrated_species': _fineAlignments.length,
      'species_with_history': _adjustmentHistory.length,
      'total_adjustments': _adjustmentHistory.values
          .map((list) => list.length)
          .fold(0, (sum, count) => sum + count),
    };
  }
  
  /// Détermine l'alignement optimal pour un oiseau donné (version synchrone)
  /// Paramètres : genus et species de l'oiseau
  /// Retourne : Alignment optimal basé sur l'alignement fin
  static Alignment getOptimalAlignment(String genus, String species) {
    final fineValue = _getFineAlignmentSync(genus, species);
    return _doubleToAlignment(fineValue);
  }
  
  // Méthode d'auto-lock supprimée (déplacée dans AutoLockService)
  
  /// Version asynchrone pour obtenir l'alignement optimal
  static Future<Alignment> getOptimalAlignmentAsync(String genus, String species) async {
    final fineValue = await _getFineAlignment(genus, species);
    return _doubleToAlignment(fineValue);
  }
  
  /// Obtient l'alignement fin actuel pour une espèce (version synchrone)
  static double getFineAlignment(String genus, String species) {
    return _getFineAlignmentSync(genus, species);
  }
  
  /// Version asynchrone pour obtenir l'alignement fin
  static Future<double> getFineAlignmentAsync(String genus, String species) async {
    return await _getFineAlignment(genus, species);
  }
  
  /// Version synchrone de _getFineAlignment (pour compatibilité)
  static double _getFineAlignmentSync(String genus, String species) {
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    
    // 1. Alignement temporaire en cours de calibration
    if (_fineAlignments.containsKey(key)) {
      return _fineAlignments[key]!;
    }
    
    // 2. Charger depuis le stockage si pas encore dans le cache
    _loadAlignmentToCache(genus, species);
    
    // 3. Vérifier à nouveau après chargement
    if (_fineAlignments.containsKey(key)) {
      return _fineAlignments[key]!;
    }
    
    // 4. Chercher par famille (genre)
    final genusLower = genus.toLowerCase();
    if (_familyDefaults.containsKey(genusLower)) {
      return _familyDefaults[genusLower]!;
    }
    
    // 5. Chercher par nom spécifique complet (ex: motacilla_alba)
    for (final familyKey in _familyDefaults.keys) {
      if (key.startsWith(familyKey)) {
        return _familyDefaults[familyKey]!;
      }
    }
    
    // 6. Par défaut : centré
    return 0.0;
  }
  
  /// Charge un alignement spécifique dans le cache de manière asynchrone
  static void _loadAlignmentToCache(String genus, String species) {
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    
    // Éviter de charger si déjà en cours
    if (!_fineAlignments.containsKey(key)) {
      BirdAlignmentStorage.loadAlignment(genus, species).then((savedAlignment) {
        if (savedAlignment != null) {
          _fineAlignments[key] = savedAlignment;
        }
      }).catchError((e) {
        // Ignorer silencieusement les erreurs de chargement
      });
    }
  }
  
  /// Vérifie si un alignement personnalisé existe pour cette espèce
  static bool hasCustomAlignment(String genus, String species) {
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    return _fineAlignments.containsKey(key);
  }
  
  /// Retourne la liste des espèces avec alignement personnalisé
  static List<String> getSpeciesWithCustomAlignments() {
    return _fineAlignments.keys.toList();
  }
  
  /// Obtient l'alignement final (méthode de compatibilité)
  static Alignment getFinalAlignment(String genus, String species) {
    return getOptimalAlignment(genus, species);
  }
  
  /// Méthode de compatibilité pour setCustomAlignment
  static void setCustomAlignment(String genus, String species, Alignment alignment) {
    // Convertir l'Alignment en valeur fine
    double fineValue = alignment.x;
    calibrateAlignment(genus, species, fineValue);
  }
  
  /// Statistiques du système d'alignement
  static Map<String, dynamic> getAlignmentStats() {
    final allAlignments = _fineAlignments.values.toList();
    final leftCount = allAlignments.where((v) => v < -0.1).length;
    final rightCount = allAlignments.where((v) => v > 0.1).length;
    final centerCount = allAlignments.where((v) => v.abs() <= 0.1).length;
    
    return {
      'total': _fineAlignments.length,
      'left': leftCount,
      'right': rightCount,
      'center': centerCount,
      'calibrated': _fineAlignments.length,
      'with_history': _adjustmentHistory.length,
    };
  }
  
  /// Obtient la description textuelle de l'alignement
  static String getAlignmentDescription(String genus, String species) {
    final fineValue = _getFineAlignmentSync(genus, species);
    
    if (fineValue < -0.5) return 'TRÈS À GAUCHE';
    if (fineValue < -0.2) return 'À GAUCHE';
    if (fineValue < -0.05) return 'LÉGÈREMENT À GAUCHE';
    if (fineValue > 0.5) return 'TRÈS À DROITE';
    if (fineValue > 0.2) return 'À DROITE';
    if (fineValue > 0.05) return 'LÉGÈREMENT À DROITE';
    return 'CENTRÉ';
  }
  
  /// Remet à zéro l'alignement d'une espèce (retour au défaut de famille)
  static void resetAlignment(String genus, String species) {
    final key = '${genus.toLowerCase()}_${species.toLowerCase()}';
    _fineAlignments.remove(key);
    _adjustmentHistory.remove(key);
  }
  
  // ===================================================================
  // GESTION DES MODES DEV/PRODUCTION
  // ===================================================================
  
  /// Vérifie si le mode développement est actif (interfaces de calibration visibles)
  static Future<bool> isDevModeEnabled() async {
    return await BirdAlignmentStorage.isDevMode();
  }
  
  /// Active le mode développement (interfaces de calibration)
  static Future<void> enableDevMode() async {
    await BirdAlignmentStorage.unlockAlignments();
  }
  
  /// Désactive le mode développement et verrouille les alignements
  static Future<void> disableDevMode() async {
    await BirdAlignmentStorage.lockAlignments();
  }
  
  /// Obtient le mode actuel
  static Future<String> getCurrentMode() async {
    return await BirdAlignmentStorage.getCurrentMode();
  }
  
  /// Obtient les statistiques complètes (sauvegardé + temporaire)
  static Future<Map<String, dynamic>> getCompleteStats() async {
    final storageStats = await BirdAlignmentStorage.getStats();
    final tempStats = getUsageStats();
    
    return {
      'mode': storageStats['mode'],
      'is_locked': storageStats['is_locked'],
      'saved_alignments': storageStats['total_calibrated'],
      'temp_alignments': tempStats['calibrated_species'],
      'total_species': (storageStats['total_calibrated'] as int) + (tempStats['calibrated_species'] as int),
      'left_aligned': storageStats['left_aligned'],
      'right_aligned': storageStats['right_aligned'],
      'center_aligned': storageStats['center_aligned'],
    };
  }
  
  /// Exporte tous les alignements calibrés pour sauvegarde
  static Future<Map<String, double>> exportCalibratedAlignments() async {
    return await BirdAlignmentStorage.exportAlignments();
  }
  
  /// Charge les alignements sauvegardés dans le cache temporaire
  static Future<void> loadSavedAlignments() async {
    final savedAlignments = await BirdAlignmentStorage.exportAlignments();
    _fineAlignments.addAll(savedAlignments);
  }
  
  /// Méthode pour basculer vers le mode production (appelée quand l'utilisateur termine la calibration)
  static Future<void> lockAllAlignments() async {
    // Sauvegarder tous les alignements temporaires
    for (final entry in _fineAlignments.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        await BirdAlignmentStorage.saveAlignment(parts[0], parts[1], entry.value);
      }
    }
    
    // Verrouiller le système
    await BirdAlignmentStorage.lockAlignments();
    
    // Effacer le cache temporaire
    _fineAlignments.clear();
    _adjustmentHistory.clear();
  }
}
