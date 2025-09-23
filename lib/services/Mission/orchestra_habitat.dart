import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/mission.dart';
import 'communs/commun_chargeur_missions.dart';
import 'communs/commun_gestionnaire_assets.dart';
import 'communs/commun_generateur_quiz.dart';
import 'communs/commun_gestion_mission.dart';
import 'communs/commun_strategie_progression.dart';
import 'communs/commun_cache_images.dart';

/// Chef d'orchestre des éléments communs pour le mode Habitat.
///
/// Centralise les opérations missions: catalogue + progression, préchargement,
/// génération de quiz, sauvegarde de progression, statistiques.
class OrchestraHabitat {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === Bootstrap (optionnel) ===
  static Future<void> start() async {
    // Initialiser les mappings d'images locales (offline-first) au démarrage
    try {
      await ImageCacheService().initializeLocalMappings();
    } catch (_) {}
    if (kDebugMode) debugPrint('🎼 OrchestraHabitat démarré');
  }

  // === Catalogue + progression ===

  static Future<Map<String, List<Mission>>> loadAllMissionsWithProgression(String uid) {
    return MissionLoaderService.loadMissionsWithProgression(uid);
  }

  static Future<List<Mission>> loadMissionsForBiomeWithProgression(
    String uid,
    String biomeName,
  ) {
    return MissionLoaderService.loadMissionsForBiomeWithProgression(uid, biomeName);
  }

  static Future<List<Mission>> loadMissionsForBiomeCsvOnly(String biomeName) {
    return MissionLoaderService.loadMissionsForBiome(biomeName);
  }

  // === Préchargement ===

  static Future<Map<String, dynamic>> preloadMissionAssets(String missionId) {
    return MissionPreloader.preloadMission(missionId);
  }

  // === Génération de quiz ===

  static Future<List<QuizQuestion>> generateQuiz(String missionId) async {
    try {
      final doc = await _firestore.collection('missions').doc(missionId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return await QuizGenerator.generateQuizFromFirestoreAndCsv(missionId, data);
      }
    } catch (_) {}
    return QuizGenerator.generateQuizFromCsv(missionId);
  }

  static String generateMissionId(String milieuType, int missionNumber) {
    return QuizGenerator.generateMissionId(milieuType, missionNumber);
  }

  // === Progression / Stats ===

  static Future<void> updateProgressAfterQuiz({
    required String missionId,
    required int score,
    required int totalQuestions,
    required Duration dureePartie,
    required List<String> wrongBirds,
  }) {
    return MissionManagementService.updateMissionProgress(
      missionId: missionId,
      score: score,
      totalQuestions: totalQuestions,
      dureePartie: dureePartie,
      wrongBirds: wrongBirds,
    );
  }

  static Future<Map<String, dynamic>?> getMissionStats(String missionId) {
    return MissionManagementService.getMissionStats(missionId);
  }

  static Future<List<Map<String, dynamic>>> getMissionSessions(String missionId) {
    return MissionManagementService.getMissionSessions(missionId);
  }

  static Future<Map<String, dynamic>> getUserGlobalStats() {
    return MissionManagementService.getUserGlobalStats();
  }

  static int calculateStars(int score, int total, int currentStars) {
    return MissionManagementService.calculateStars(score, total, currentStars);
  }

  // === Initialisation / Déverrouillage ===

  static Future<void> initializeBiomeProgress(String biome, List<Mission> missions) {
    return MissionProgressionInitService.initializeBiomeProgress(biome, missions);
  }

  static Future<void> unlockMission({
    required String missionId,
    required String biome,
    required int index,
  }) {
    return MissionProgressionInitService.unlockMission(missionId, biome: biome, index: index);
  }

  static Future<bool> isMissionUnlocked(String missionId) {
    return MissionProgressionInitService.isMissionUnlocked(missionId);
  }

  // === Images (helpers) ===

  static ImageProvider getOptimizedImageProvider({
    required String birdName,
    String? networkUrl,
    String placeholder = 'assets/Images/Milieu/placeholder_bird.png',
  }) {
    return ImageCacheService().getOptimizedImageProvider(
      birdName: birdName,
      networkUrl: networkUrl,
      placeholder: placeholder,
    );
  }
}


