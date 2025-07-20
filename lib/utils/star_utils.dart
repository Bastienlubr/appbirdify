/// Utilitaires pour la gestion des étoiles dans les missions
class StarUtils {
  /// Calcule le nombre d'étoiles mises à jour basé sur le score obtenu
  /// 
  /// [currentStars] : Nombre d'étoiles actuelles (0-2)
  /// [score] : Score obtenu au quiz (sur 10)
  /// 
  /// Retourne :
  /// - currentStars + 1 si score >= 8 et currentStars < 2
  /// - currentStars sinon
  /// 
  /// Règles :
  /// - Maximum 2 étoiles par mission
  /// - Une étoile gagnée pour chaque score >= 8/10
  static int computeUpdatedStars(int currentStars, int score) {
    if (score >= 8 && currentStars < 2) {
      return currentStars + 1;
    }
    return currentStars;
  }
  
  /// Vérifie si une mission peut être débloquée
  /// 
  /// [previousMissionStars] : Nombre d'étoiles de la mission précédente
  /// 
  /// Retourne true si la mission précédente a au moins 2 étoiles
  static bool canUnlockNextMission(int previousMissionStars) {
    return previousMissionStars >= 2;
  }
  
  /// Obtient le statut de déblocage d'une mission
  /// 
  /// [currentStars] : Nombre d'étoiles actuelles
  /// [previousMissionStars] : Nombre d'étoiles de la mission précédente (0 si première mission)
  /// 
  /// Retourne :
  /// - 'locked' : Mission verrouillée (mission précédente < 2 étoiles)
  /// - 'available' : Mission disponible
  /// - 'completed' : Mission terminée (2 étoiles obtenues)
  static String getMissionStatus(int currentStars, int previousMissionStars) {
    if (previousMissionStars < 2) {
      return 'locked';
    } else if (currentStars >= 2) {
      return 'completed';
    } else {
      return 'available';
    }
  }
} 