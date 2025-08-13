/// Utilitaires pour la gestion des étoiles dans les missions
class StarUtils {
  /// Calcule le nombre d'étoiles mises à jour basé sur le score obtenu
  /// 
  /// [currentStars] : Nombre d'étoiles actuelles (0-3)
  /// [score] : Score obtenu au quiz (sur 10)
  /// 
  /// Retourne :
  /// - 2 si score >= 8 et currentStars < 2 (gagne 1ère et 2ème étoiles)
  /// - 3 si score >= 10 et currentStars < 3 (gagne 3ème étoile)
  /// - currentStars sinon
  /// 
  /// Règles :
  /// - Maximum 3 étoiles par mission
  /// - 1ère et 2ème étoiles : score >= 8/10 (gagnées ensemble)
  /// - 3ème étoile : score >= 10/10 uniquement
  static int computeUpdatedStars(int currentStars, int score) {
    if (score >= 10 && currentStars < 3) {
      return 3;
    } else if (score >= 8 && currentStars < 2) {
      return 2; // Gagne 1ère et 2ème étoiles
    }
    return currentStars;
  }
  
  /// Calcule le nombre d'étoiles gagnées pour un score donné
  /// 
  /// [score] : Score obtenu au quiz
  /// [total] : Nombre total de questions
  /// 
  /// Retourne le nombre d'étoiles gagnées (0-3)
  /// 
  /// Règles :
  /// - 1ère étoile : score >= 8/10
  /// - 2ème étoile : score >= 8/10 (si pas déjà gagnée)
  /// - 3ème étoile : score >= 10/10 uniquement
  static int computeStarsEarned(int score, int total) {
    final ratio = score / total;
    if (ratio >= 1.0) return 3;      // 100% = 3 étoiles
    if (ratio >= 0.8) return 2;      // 80% = 2 étoiles (1ère et 2ème étoiles)
    return 0;                         // < 80% = 0 étoile
  }
  
  /// Calcule le nombre d'étoiles restantes à gagner
  /// 
  /// [score] : Score obtenu au quiz
  /// [total] : Nombre total de questions
  /// 
  /// Retourne le nombre d'étoiles restantes (0-3)
  static int computeStarsToEarn(int score, int total) {
    return 3 - computeStarsEarned(score, total);
  }
  
  /// Retourne le nombre total d'étoiles possibles
  /// 
  /// Retourne toujours 3 (système à 3 étoiles)
  static int computeStarsTotal(int score, int total) {
    return 3;
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
  /// - 'completed' : Mission terminée (3 étoiles obtenues)
  static String getMissionStatus(int currentStars, int previousMissionStars) {
    if (previousMissionStars < 2) {
      return 'locked';
    } else if (currentStars >= 3) {
      return 'completed';
    } else {
      return 'available';
    }
  }
} 