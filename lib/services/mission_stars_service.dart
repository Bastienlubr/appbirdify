import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/mission.dart';
import 'firestore_service.dart';

class MissionStarsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Synchronise les étoiles des missions depuis Firestore
  /// 
  /// [missions] : Liste des missions à synchroniser
  /// Retourne : Liste des missions avec les étoiles mises à jour
  static Future<List<Mission>> syncMissionStars(List<Mission> missions) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté, étoiles non synchronisées');
        return missions;
      }

      // Récupérer toutes les étoiles de l'utilisateur depuis Firestore
      final QuerySnapshot missionsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('missions')
          .get();

      // Créer un Map des étoiles par mission ID
      final Map<String, int> starsByMissionId = {};
      for (final doc in missionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final missionId = doc.id;
        final stars = data['lastStarsEarned'] as int? ?? 0;
        starsByMissionId[missionId] = stars;
      }

      // Mettre à jour les missions avec les étoiles depuis Firestore
      final List<Mission> updatedMissions = missions.map((mission) {
        final firestoreStars = starsByMissionId[mission.id] ?? 0;
        
        // Si les étoiles Firestore sont plus élevées que celles du CSV, utiliser Firestore
        final finalStars = firestoreStars > mission.lastStarsEarned 
            ? firestoreStars 
            : mission.lastStarsEarned;
            
        return Mission(
          id: mission.id,
          milieu: mission.milieu,
          index: mission.index,
          status: mission.status,
          questions: mission.questions,
          title: mission.title,
          csvFile: mission.csvFile,
          titreMission: mission.titreMission,
          sousTitre: mission.sousTitre,
          iconUrl: mission.iconUrl,
          lastStarsEarned: finalStars,
          hasBeenSeen: mission.hasBeenSeen,
        );
      }).toList();

      if (kDebugMode) {
        debugPrint('✅ Étoiles synchronisées pour ${updatedMissions.length} missions');
      }

      return updatedMissions;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation des étoiles: $e');
      return missions; // Retourner les missions originales en cas d'erreur
    }
  }

  /// Met à jour les étoiles d'une mission spécifique
  /// 
  /// [missionId] : ID de la mission
  /// [newStars] : Nouveau nombre d'étoiles
  static Future<void> updateMissionStars(String missionId, int newStars) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté');
        return;
      }

      await FirestoreService().updateMissionStars(user.uid, missionId, newStars);
      
      if (kDebugMode) {
        debugPrint('✅ Étoiles mises à jour pour la mission $missionId: $newStars');
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la mise à jour des étoiles: $e');
      rethrow;
    }
  }
} 