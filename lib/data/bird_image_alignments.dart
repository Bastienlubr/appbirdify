import 'package:flutter/material.dart';
import 'bird_alignment_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert' as dart_convert;

/// Système intelligent et adaptatif de positionnement des images d'oiseaux
/// Utilise des alignements fins et peut apprendre des corrections utilisateur
/// Supporte les modes dev (calibration) et production (verrouillé)
class BirdImageAlignments {
  
  /// Alignements fins personnalisés (valeurs entre -1.0 et 1.0)
  /// -1.0 = complètement à gauche, 0.0 = centré, 1.0 = complètement à droite
  static final Map<String, double> _fineAlignments = {
    // Cadrages calibrés et figés (chargés en mémoire par défaut)
    'thalassarche_melanophris': 0.9,
    'prunella_collaris': -0.3,
    'egretta_garzetta': -0.4,
    'melanocorypha_calandra': 0.4,
    'calandrella_brachydactyla': 0.85,
    'eremophila_alpestris': 0.65,
    'lullula_arborea': -0.4,
    'accipiter_gentilis': 0.25,
    'recurvirostra_avosetta': -0.8,
    'limosa_limosa': 0.35,
    'limosa_lapponica': 0.35,
    'calidris_alba': 0.7,
    'calidris_alpina': 0.4,
    'calidris_melanotos': -0.5,
    'gallinago_gallinago': 0.4,
    'motacilla_flava': 0.5,
    'branta_ruficollis': 0.15,
    'motacilla_alba': 0.65,
    'branta_bernicla': 0.1,
    'ixobrychus_minutus': -0.15,
    'nycticorax_nycticorax': 0.45,
    'cettia_cetti': -0.4,
    'plectrophenax_nivalis': 0.9,
    'pyrrhula_pyrrhula': 0.3,
    'emberiza_cia': -0.3,
    'emberiza_citrinella': 0.9,
    'calcarius_lapponicus': -0.1,
    'emberiza_calandra': -0.25,
    'emberiza_hortulana': 0.75,
    'buteo_buteo': 0.3,
    'botaurus_stellaris': 0.85,
    'coturnix_coturnix': -0.8,
    'aix_galericulata': -0.7,
    'anas_platyrhynchos': 0.25,
    'anas_acuta': -0.6,
    'mareca_penelope': 0.75,
    'spatula_clypeata': 0.45,
    'carduelis_carduelis': 0.0,
    'tringa_nebularia': 0.5,
    'tringa_totanus': 0.4,
    'actitis_hypoleucos': 0.35,
    'tringa_glareola': 0.3,
    'coloeus_monedula': 0.15,
    'ciconia_ciconia': -0.2,
    'cinclus_cinclus': -0.85,
    'galerida_cristata': 0.2,
    'corvus_frugilegus': -0.25,
    'calidris_pugnax': 0.35,
    'corvus_cornix': -0.15,
    'corvus_corone': 0.65,
    'clamator_glandarius': 0.85,
    'pyrrhocorax_pyrrhocorax': -0.5,
    'numenius_phaeopus': -0.95,
    'cygnus_olor': -0.5,
    'cygnus_atratus': 0.2,
    'himantopus_himantopus': 0.45,
    'somateria_mollissima': 0.7,
    'caprimulgus_europaeus': 0.6,
    'accipiter_nisus': 0.15,
    'oxyura_jamaicensis': 0.3,
    'sturnus_vulgaris': -0.8,
    'phasianus_colchicus': 0.55,
    'falco_subbuteo': 0.4,
    'falco_peregrinus': 0.4,
    'curruca_conspicillata': -0.65,
    'sylvia_atricapilla': 0.35,
    'curruca_curruca': -0.25,
    'sylvia_borin': 0.1,
    'curruca_communis': 0.4,
    'curruca_melanocephala': 0.2,
    'phoenicopterus_roseus': -0.5,
    'curruca_undata': 0.3,
    'morus_bassanus': 0.45,
    'fulica_atra': -0.8,
    'aythya_fuligula': -0.1,
    'fulmarus_glacialis': 0.75,
    'gallinula_chloropus': 0.85,
    'bucephala_clangula': -0.6,
    'garrulus_glandarius': -0.85,
    'tetrastes_bonasia': -0.5,
    'muscicapa_striata': 0.35,
    'ficedula_parva': -0.3,
    'ficedula_hypoleuca': -0.55,
    'larus_argentatus': 0.85,
    'larus_fuscus': -0.5,
    'larus_canus': -0.8,
    'larus_dominicanus': -0.45,
    'larus_marinus': -0.65,
    'tetrao_urogallus': 0.95,
    'podiceps_cristatus': 0.65,
    'certhia_familiaris': 0.0,
    'certhia_brachydactyla': -0.4,
    'turdus_viscivorus': 0.15,
    'turdus_pilaris': 0.15,
    'coccothraustes_coccothraustes': -0.75,
    'merops_apiaster': 0.65,
    'uria_aalge': -0.5,
    'chlidonias_niger': 0.0,
    'chlidonias_hybrida': 0.0,
    'clangula_hyemalis': -0.45,
    'mergus_serrator': 0.5,
    'ardea_cinerea': -0.25,
    'bubulcus_ibis': -0.1,
    'ardea_purpurea': -0.05,
    'asio_flammeus': 0.5,
    'bubo_bubo': 0.3,
    'asio_otus': -0.2,
    'riparia_riparia': -0.2,
    'ptyonoprogne_rupestris': -0.2,
    'cecropis_rufula': 0.1,
    'hirundo_rustica': -0.5,
    'haematopus_ostralegus': -0.4,
    'upupa_epops': -0.2,
    'hippolais_polyglotta': 0.0,
    'plegadis_falcinellus': 0.0,
    'stercorarius_pomarinus': 0.0,
    'lagopus_muta': 0.6,
    'leiothrix_lutea': -0.05,
    'linaria_cannabina': 0.25,
    'locustella_luscinioides': 0.35,
    'locustella_naevia': 0.0,
    'oriolus_oriolus': -0.25,
    'fratercula_arctica': 0.0,
    'melanitta_nigra': -0.65,
    'zapornia_pusilla': -0.2,
    'porzana_porzana': -0.75,
    'alcedo_atthis': 0.4,
    'tachymarptis_melba': 0.0,
    'apus_apus': 0.25,
    'turdus_torquatus': -0.15,
    'turdus_merula': 0.1,
    'aegithalos_caudatus': 0.2,
    'cyanistes_caeruleus': 0.2,
    'poecile_montanus': 0.45,
    'parus_major': -0.05,
    'lophophanes_cristatus': -0.3,
    'periparus_ater': 0.4,
    'poecile_palustris': 0.3,
    'milvus_migrans': 0.15,
    'milvus_milvus': 0.0,
    'passer_domesticus': 0.0,
    'passer_montanus': 0.4,
    'petronia_petronia': 0.25,
    'monticola_solitarius': 0.55,
    'chroicocephalus_ridibundus': 0.3,
    'rissa_tridactyla': 0.65,
    'hydrobates_leucorhous': 0.2,
    'burhinus_oedicnemus': 0.35,
    'anser_brachyrhynchus': -0.3,
    'anser_anser': 0.1,
    'anser_albifrons': 0.95,
    'panurus_biarmicus': -0.15,
    'perdix_perdix': 0.85,
    'alectoris_rufa': -0.6,
    'psittacula_krameri': 0.35,
    'melopsittacus_undulatus': -0.5,
    'otus_scops': 0.0,
    'phalaropus_lobatus': -0.6,
    'acrocephalus_paludicola': -0.15,
    'acrocephalus_schoenobaenus': -0.15,
    'dendrocopos_major': 0.4,
    'dryobates_minor': 0.25,
    'dendrocoptes_medius': 0.0,
    'dryocopus_martius': 0.2,
    'picus_viridis': 0.0,
    'pica_pica': -0.1,
    'lanius_senator': 0.55,
    'lanius_collurio': -0.3,
    'columba_livia': -0.75,
    'columba_oenas': -0.15,
    'columba_palumbus': -0.85,
    'alca_torda': 0.0,
    'fringilla_coelebs': -0.6,
    'fringilla_montifringilla': -0.6,
    'anthus_trivialis': 0.2,
    'anthus_pratensis': -0.35,
    'anthus_petrosus': 0.2,
    'gavia_immer': 0.3,
    'charadrius_alexandrinus': 0.0,
    'pluvialis_squatarola': 0.45,
    'pluvialis_apricaria': 0.45,
    'charadrius_hiaticula': -0.1,
    'eudromias_morinellus': 0.0,
    'charadrius_dubius': 0.5,
    'phylloscopus_trochilus': 0.35,
    'phylloscopus_sibilatrix': -0.2,
    'phylloscopus_collybita': -0.3,
    'puffinus_puffinus': 0.0,
    'ardenna_grisea': -0.35,
    'haliaeetus_albicilla': 0.0,
    'rallus_aquaticus': 0.45,
    'crex_crex': 0.55,
    'remiz_pendulinus': 0.2,
    'regulus_ignicapilla': -0.6,
    'regulus_regulus': 0.0,
    'coracias_garrulus': -0.4,
    'carpodacus_erythrinus': 0.0,
    'luscinia_megarhynchos': 0.8,
    'erithacus_rubecula': 0.2,
    'phoenicurus_phoenicurus': -0.3,
    'phoenicurus_ochruros': 0.5,
    'acrocephalus_scirpaceus': -0.15,
    'acrocephalus_arundinaceus': 0.15,
    'spatula_querquedula': -0.2,
    'anas_crecca': -0.15,
    'serinus_serinus': 0.2,
    'sitta_europaea': -0.25,
    'platalea_leucorodia': -0.65,
    'sterna_paradisaea': 0.0,
    'hydroprogne_caspia': 0.3,
    'sternula_albifrons': -0.4,
    'thalasseus_sandvicensis': 0.15,
    'sterna_dougallii': -0.35,
    'sterna_hirundo': -0.6,
    'tadorna_tadorna': 0.0,
    'saxicola_rubetra': 0.0,
    'saxicola_rubicola': 0.0,
    'spinus_spinus': 0.35,
    'lyrurus_tetrix': -0.2,
    'jynx_torquilla': -0.4,
    'arenaria_interpres': -0.55,
    'streptopelia_turtur': 0.7,
    'streptopelia_decaocto': 0.0,
    'troglodytes_troglodytes': -0.15,
    'oenanthe_oenanthe': 0.0,
    'oenanthe_hispanica': 0.0,
    'vanellus_vanellus': 0.0,
    'chloris_chloris': 0.25,
    'prunella_modularis': 0.0,
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
  
  /// Importe des alignements (JSON → stockage + cache)
  static Future<void> importAlignments(Map<String, double> alignments) async {
    // Mettre à jour le cache en mémoire immédiatement
    _fineAlignments.addAll(alignments);
    // Persister
    await BirdAlignmentStorage.importAlignments(alignments);
  }

  /// Charge des alignements par défaut embarqués (assets/data/bird_alignments.json)
  /// Sans échec si le fichier est absent/vidé → sécurise le démarrage.
  static Future<void> loadDefaultAlignmentsFromAssets({String path = 'assets/data/bird_alignments.json'}) async {
    try {
      final raw = await rootBundle.loadString(path);
      if (raw.trim().isEmpty) return;
      final Map<String, dynamic> decoded = dart_convert.jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, double> casted = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      // Charger en cache (et persister) pour que ce soit utilisé immédiatement
      await importAlignments(casted);
    } catch (_) {
      // Silencieux: pas d'assets ou JSON invalide → ignorer
    }
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
