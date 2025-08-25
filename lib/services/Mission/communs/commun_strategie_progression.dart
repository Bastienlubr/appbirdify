import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../models/mission.dart';

/// Service pour initialiser et gérer la progression des missions
class MissionProgressionInitService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialise la progression d'une mission si elle n'existe pas encore
  static Future<void> initializeMissionProgress(String missionId, {
    required String biome,
    required int index,
    bool forceUnlock = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté pour initialiser la progression');
        return;
      }

      final progressRef = _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .doc(missionId);

      // Vérifier si la progression existe déjà
      final doc = await progressRef.get();
      
      if (!doc.exists) {
        // Créer la progression initiale
        final initialData = {
          'etoiles': 0,
          'meilleurScore': 0,
          'tentatives': 0,
          'deverrouille': forceUnlock || index == 1, // Première mission toujours déverrouillée
          'biome': biome,
          'index': index,
          'creeLe': FieldValue.serverTimestamp(),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        };

        await progressRef.set(initialData);
        
        if (kDebugMode) {
          debugPrint('🎯 Progression initialisée pour $missionId (déverrouillée: ${initialData['deverrouille']})');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ Progression déjà existante pour $missionId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'initialisation de la progression pour $missionId: $e');
      }
    }
  }

  /// Initialise la progression pour toutes les missions d'un biome
  static Future<void> initializeBiomeProgress(String biome, List<Mission> missions) async {
    if (kDebugMode) {
      debugPrint('🔄 Initialisation de la progression pour le biome $biome (${missions.length} missions)');
    }

    for (final mission in missions) {
      // Seule la première mission est déverrouillée et initialisée
      if (mission.index == 1) {
        await initializeMissionProgress(
          mission.id,
          biome: biome,
          index: mission.index,
          forceUnlock: true, // Première mission toujours déverrouillée
        );
      }
      // Les autres missions ne sont PAS initialisées - elles seront créées quand déverrouillées
    }

    if (kDebugMode) {
      debugPrint('✅ Progression initialisée pour le biome $biome (seulement U01)');
    }
  }

  /// Vérifie si une mission est déverrouillée
  static Future<bool> isMissionUnlocked(String missionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .doc(missionId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['deverrouille'] ?? false;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la vérification du déverrouillage de $missionId: $e');
      }
      return false;
    }
  }

  /// Déverrouille une mission et crée sa progression si nécessaire
  static Future<void> unlockMission(String missionId, {
    required String biome,
    required int index,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final progressRef = _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .doc(missionId);

      // Vérifier si la progression existe déjà
      final doc = await progressRef.get();
      
      if (!doc.exists) {
        // Créer la progression au moment du déverrouillage
        await progressRef.set({
          'etoiles': 0,
          'meilleurScore': 0,
          'tentatives': 0,
          'deverrouille': true,
          'biome': biome,
          'index': index,
          'deverrouilleLe': FieldValue.serverTimestamp(), // Date de déverrouillage
          'creeLe': FieldValue.serverTimestamp(),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          debugPrint('🔓 Mission $missionId déverrouillée et progression créée');
        }
      } else {
        // Mettre à jour la progression existante
        await progressRef.update({
          'deverrouille': true,
          'deverrouilleLe': FieldValue.serverTimestamp(), // Date de déverrouillage
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          debugPrint('🔓 Mission $missionId déverrouillée (progression existante)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du déverrouillage de $missionId: $e');
      }
    }
  }
}
