import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class MissionPersistenceService {
  static const String _consultedMissionsKey = 'consulted_missions';
  
  /// Marque une mission comme consultée
  static Future<void> markMissionAsConsulted(String missionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consultedMissions = prefs.getStringList(_consultedMissionsKey) ?? [];
      
      if (!consultedMissions.contains(missionId)) {
        consultedMissions.add(missionId);
        await prefs.setStringList(_consultedMissionsKey, consultedMissions);
        if (kDebugMode) debugPrint('✅ Mission $missionId marquée comme consultée');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du marquage de la mission $missionId: $e');
    }
  }
  
  /// Vérifie si une mission a été consultée
  static Future<bool> isMissionConsulted(String missionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consultedMissions = prefs.getStringList(_consultedMissionsKey) ?? [];
      return consultedMissions.contains(missionId);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la vérification de la mission $missionId: $e');
      return false;
    }
  }
  
  /// Récupère toutes les missions consultées
  static Future<List<String>> getConsultedMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_consultedMissionsKey) ?? [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la récupération des missions consultées: $e');
      return [];
    }
  }
  
  /// Efface toutes les missions consultées (pour les tests)
  static Future<void> clearConsultedMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_consultedMissionsKey);
      if (kDebugMode) debugPrint('🗑️ Toutes les missions consultées ont été effacées');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de l\'effacement des missions consultées: $e');
    }
  }
} 