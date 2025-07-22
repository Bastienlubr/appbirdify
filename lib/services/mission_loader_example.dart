import 'mission_loader.dart';

/// Exemple d'utilisation du MissionLoader
class MissionLoaderExample {
  
  /// Exemple : Charger toutes les missions et les afficher
  static Future<void> exampleLoadAllMissions() async {
    // 🔄 Chargement de toutes les missions...
    
    final missions = await MissionLoader.loadAllMissions();
    
    // ✅ ${missions.length} missions chargées :
    
    String currentMilieu = '';
    for (final mission in missions) {
      if (mission.milieu != currentMilieu) {
        currentMilieu = mission.milieu;
        // 📁 Milieu : $currentMilieu
      }
      
      //   ${mission.index.toString().padLeft(2, '0')}. ${mission.titreMission}
      if (mission.sousTitre != null && mission.sousTitre!.isNotEmpty) {
        //      └─ ${mission.sousTitre}
      }
    }
  }
  
  /// Exemple : Charger les missions pour un milieu spécifique
  static Future<void> exampleLoadMissionsForMilieu(String milieu) async {
    // 🔄 Chargement des missions pour le milieu : $milieu
    
    final missions = await MissionLoader.loadMissionsForMilieu(milieu);
    
    // ✅ ${missions.length} missions trouvées pour $milieu :
    
    for (final mission in missions) {
      //   ${mission.index.toString().padLeft(2, '0')}. ${mission.titreMission}
      if (mission.sousTitre != null && mission.sousTitre!.isNotEmpty) {
        //      └─ ${mission.sousTitre}
      }
    }
  }
  
  /// Exemple : Charger les titres d'une mission spécifique
  static Future<void> exampleLoadMissionTitles(String csvFile) async {
    // 🔄 Chargement des titres pour : $csvFile
    
    final titles = await MissionLoader.loadMissionTitles(csvFile);
    
    if (titles != null) {
      // ✅ Titres chargés :
      //   Titre : ${titles['titreMission']}
      //   Sous-titre : ${titles['sousTitre']}
      //   Icône : ${titles['iconUrl']}
    } else {
      // ❌ Impossible de charger les titres
    }
  }
  
  /// Exemple : Utilisation complète
  static Future<void> runCompleteExample() async {
    // 🚀 Démarrage de l'exemple complet du MissionLoader
    
    // 1. Charger toutes les missions
    await exampleLoadAllMissions();
    
    // ==================================================
    
    // 2. Charger les missions pour un milieu spécifique
    await exampleLoadMissionsForMilieu('urbain');
    
    // ==================================================
    
    // 3. Charger les titres d'une mission spécifique
    await exampleLoadMissionTitles('U01 - template_mission_quiz.csv');
    
    // ✅ Exemple terminé !
  }
} 