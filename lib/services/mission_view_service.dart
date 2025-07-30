import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MissionViewService {
  static const String _viewedMissionsKey = 'viewed_missions';
  
  /// Marque une mission comme vue
  static Future<void> markMissionAsViewed(String missionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedMissions = prefs.getStringList(_viewedMissionsKey) ?? [];
      
      if (!viewedMissions.contains(missionId)) {
        viewedMissions.add(missionId);
        await prefs.setStringList(_viewedMissionsKey, viewedMissions);
        if (kDebugMode) {
          debugPrint('Mission $missionId marquée comme vue');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors du marquage de la mission $missionId comme vue: $e');
      }
    }
  }
  
  /// Vérifie si une mission a déjà été vue
  static Future<bool> isMissionViewed(String missionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedMissions = prefs.getStringList(_viewedMissionsKey) ?? [];
      return viewedMissions.contains(missionId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors de la vérification de la mission $missionId: $e');
      }
      return false;
    }
  }
  
  /// Efface toutes les missions vues (pour les tests ou reset)
  static Future<void> clearViewedMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewedMissionsKey);
      if (kDebugMode) {
        debugPrint('Toutes les missions vues ont été effacées');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors de l\'effacement des missions vues: $e');
      }
    }
  }
} 