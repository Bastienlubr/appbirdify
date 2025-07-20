import 'package:flutter/foundation.dart';
import '../models/mission.dart';
import 'milieu_data.dart';

class MilieuDataUtils {
  /// Vérifie si un nom de fichier CSV est valide
  static bool isValidCsvFileName(String fileName) {
    // Format attendu: "U01 - template_mission_quiz.csv"
    final RegExp csvPattern = RegExp(r'^[UFAMHL]\d{2}\s*-\s*template_mission_quiz\.csv$');
    return csvPattern.hasMatch(fileName);
  }

  /// Parse un nom de fichier CSV pour extraire le préfixe et l'index
  static Map<String, dynamic>? parseCsvFileName(String fileName) {
    if (!isValidCsvFileName(fileName)) {
      return null;
    }

    // Extraire le préfixe (U, F, A, M, H, L) et l'index
    final RegExp pattern = RegExp(r'^([UFAMHL])(\d{2})\s*-\s*template_mission_quiz\.csv$');
    final match = pattern.firstMatch(fileName);
    
    if (match != null) {
      return {
        'prefix': match.group(1),
        'index': int.parse(match.group(2)!),
      };
    }
    
    return null;
  }

  /// Génère un nom de fichier CSV à partir du préfixe et de l'index
  static String generateCsvFileName(String prefix, int index) {
    final paddedIndex = index.toString().padLeft(2, '0');
    return '$prefix$paddedIndex - template_mission_quiz.csv';
  }

  /// Retourne la liste des fichiers CSV disponibles
  static List<String> getAvailableCsvFiles() {
    return [
      'U01 - template_mission_quiz.csv',
      'U02 - template_mission_quiz.csv',
      'U03 - template_mission_quiz.csv',
      'U04 - template_mission_quiz.csv',
      'F01 - template_mission_quiz.csv',
      'F02 - template_mission_quiz.csv',
      // Ajouter d'autres fichiers CSV quand ils seront disponibles
    ];
  }

  /// Obtient les missions pour un biome donné
  static List<Mission> getMissionsByBiome(String biome) {
    final normalizedBiome = biome.toLowerCase();
    
    for (final milieu in milieux) {
      if (milieu.name.toLowerCase().contains(normalizedBiome)) {
        return milieu.missions;
      }
    }
    
    if (kDebugMode) debugPrint('⚠️ Aucun milieu trouvé pour le biome: $biome');
    return [];
  }

  /// Vérifie si une mission est débloquée
  static bool isMissionUnlocked(Mission mission, {List<Mission>? completedMissions}) {
    // Si c'est la première mission (index 1), elle est toujours débloquée
    if (mission.index == 1) {
      return true;
    }

    // Si aucune mission complétée n'est fournie, on considère que toutes les missions précédentes sont complétées
    if (completedMissions == null) {
      return true;
    }

    // Vérifier que toutes les missions précédentes sont complétées
    final previousMissions = completedMissions
        .where((m) => m.milieu == mission.milieu && m.index < mission.index)
        .toList();

    return previousMissions.length >= mission.index - 1;
  }

  /// Calcule le résumé des étoiles pour un milieu
  static Map<String, int> getStarSummary(String biome) {
    final missions = getMissionsByBiome(biome);
    int totalStars = 0;
    int earnedStars = 0;

    for (final _ in missions) {
      // Chaque mission peut donner jusqu'à 3 étoiles
      totalStars += 3;
      
      // Pour l'instant, on considère qu'aucune étoile n'est gagnée
      // TODO: Implémenter la logique de calcul des étoiles basée sur les performances
    }

    return {
      'total': totalStars,
      'earned': earnedStars,
      'remaining': totalStars - earnedStars,
    };
  }

  /// Obtient le prochain milieu à débloquer
  static String? getNextUnlockedMilieu(List<String> completedMilieux) {
    final allMilieux = milieux.map((m) => m.name).toList();
    
    for (final milieu in allMilieux) {
      if (!completedMilieux.contains(milieu)) {
        return milieu;
      }
    }
    
    return null; // Tous les milieux sont débloqués
  }

  /// Vérifie si un milieu est débloqué
  static bool isMilieuUnlocked(String biome, List<String> completedMilieux) {
    // Le premier milieu (urbain) est toujours débloqué
    if (biome.toLowerCase().contains('urbain')) {
      return true;
    }

    // Pour les autres milieux, vérifier si le milieu précédent est complété
    final allMilieux = milieux.map((m) => m.name).toList();
    final currentIndex = allMilieux.indexWhere((m) => m.toLowerCase().contains(biome.toLowerCase()));
    
    if (currentIndex <= 0) {
      return true; // Premier milieu ou milieu non trouvé
    }

    final previousMilieu = allMilieux[currentIndex - 1];
    return completedMilieux.contains(previousMilieu);
  }

  /// Obtient le pourcentage de progression pour un milieu
  static double getMilieuProgress(String biome, List<Mission> completedMissions) {
    final missions = getMissionsByBiome(biome);
    if (missions.isEmpty) return 0.0;

    final completedCount = completedMissions
        .where((m) => m.milieu.toLowerCase() == biome.toLowerCase())
        .length;

    return (completedCount / missions.length) * 100;
  }

  /// Valide la cohérence des données de milieu
  static List<String> validateMilieuData() {
    final List<String> errors = [];

    for (final milieu in milieux) {
      // Vérifier que chaque milieu a un nom
      if (milieu.name.isEmpty) {
        errors.add('Milieu sans nom trouvé');
      }

      // Vérifier que chaque milieu a des missions
      if (milieu.missions.isEmpty) {
        errors.add('Milieu ${milieu.name} n\'a aucune mission');
      }

      // Vérifier la cohérence des IDs de mission
      for (final mission in milieu.missions) {
        if (mission.id.isEmpty) {
          errors.add('Mission sans ID dans le milieu ${milieu.name}');
        }

        if (mission.index <= 0) {
          errors.add('Mission ${mission.id} a un index invalide: ${mission.index}');
        }
      }

      // Vérifier que les indices sont séquentiels
      final indices = milieu.missions.map((m) => m.index).toList();
      indices.sort();
      for (int i = 0; i < indices.length; i++) {
        if (indices[i] != i + 1) {
          errors.add('Indices non séquentiels dans le milieu ${milieu.name}');
          break;
        }
      }
    }

    return errors;
  }

  /// Obtient les statistiques globales de progression
  static Map<String, dynamic> getGlobalProgress(List<Mission> completedMissions) {
    int totalMissions = 0;
    int completedMissionsCount = 0;
    Map<String, int> missionsByMilieu = {};

    for (final milieu in milieux) {
      totalMissions += milieu.missions.length;
      final completedInMilieu = completedMissions
          .where((m) => m.milieu.toLowerCase() == milieu.name.toLowerCase())
          .length;
      missionsByMilieu[milieu.name] = completedInMilieu;
      completedMissionsCount += completedInMilieu;
    }

    return {
      'totalMissions': totalMissions,
      'completedMissions': completedMissionsCount,
      'progressPercentage': totalMissions > 0 ? (completedMissionsCount / totalMissions) * 100 : 0.0,
      'missionsByMilieu': missionsByMilieu,
    };
  }
} 