import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';


/// Service complet pour la gestion des missions et leurs statistiques
class MissionManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Met à jour complètement la progression d'une mission après un quiz
  static Future<void> updateMissionProgress({
    required String missionId,
    required int score,
    required int totalQuestions,
    // required List<Map<String, dynamic>> reponses, // Ce paramètre sera modifié ou supprimé
    required Duration dureePartie,
    required List<String> wrongBirds, // Nouveau paramètre pour les oiseaux manqués
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔧 MissionManagementService.updateMissionProgress appelé');
        debugPrint('   Mission ID: $missionId');
        debugPrint('   Score: $score/$totalQuestions');
        debugPrint('   Durée: ${dureePartie.inSeconds}s');
        debugPrint('   🔍 Début du traitement...');
      }

      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté');
        return;
      }

      final uid = user.uid;
      if (kDebugMode) {
        debugPrint('👤 Utilisateur connecté: $uid');
        debugPrint('   🔍 Connexion Firebase OK');
      }

      final progressRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('progression_missions')
          .doc(missionId);

      // Récupérer la progression actuelle
      if (kDebugMode) {
        debugPrint('   🔍 Récupération de la progression existante...');
      }
      
      final doc = await progressRef.get();
      final Map<String, dynamic> currentData = doc.exists ? doc.data()! : {};
      
      if (kDebugMode) {
        debugPrint('   📊 Progression existante:');
        debugPrint('      - Existe: ${doc.exists}');
        if (doc.exists) {
          debugPrint('      - Étoiles actuelles: ${currentData['etoiles'] ?? 0}');
          debugPrint('      - Tentatives: ${currentData['tentatives'] ?? 0}');
        }
      }

      // Calculer les nouvelles statistiques
      final int anciennesTentatives = currentData['tentatives'] ?? 0;
      final int anciennesEtoiles = currentData['etoiles'] ?? 0;

      // Calculer le score en pourcentage (toujours utile pour la moyenne)
      final int scorePourcentage = ((score / totalQuestions) * 100).round();

      // Calculer les nouvelles étoiles (système progressif)
      final int nouvellesEtoiles = calculateStars(score, totalQuestions, anciennesEtoiles);

      if (kDebugMode) {
        debugPrint('   🌟 Calcul des étoiles:');
        debugPrint('      - Score: $score/$totalQuestions');
        debugPrint('      - Ratio: ${(score / totalQuestions).toStringAsFixed(2)}');
        debugPrint('      - Nouvelles étoiles: $nouvellesEtoiles');
        debugPrint('      - Anciennes étoiles: $anciennesEtoiles');
      }

      // Gérer l'historique des oiseaux manqués (scoresHistorique)
      // Gérer la migration depuis l'ancien format List vers le nouveau format Map
      Map<String, dynamic> oiseauxManquesHistorique;
      if (currentData['scoresHistorique'] is List) {
        // Migration depuis l'ancien format List
        if (kDebugMode) {
          debugPrint('   🔄 Migration de scoresHistorique: List → Map');
        }
        oiseauxManquesHistorique = <String, dynamic>{};
      } else {
        // Nouveau format Map
        oiseauxManquesHistorique = Map<String, dynamic>.from(currentData['scoresHistorique'] ?? {});
      }
      
      for (final bird in wrongBirds) {
        oiseauxManquesHistorique[bird] = (oiseauxManquesHistorique[bird] ?? 0) + 1;
      }

      // Calculer la moyenne des scores de façon incrémentale (sans stocker la liste des pourcentages)
      final double ancienneMoyenne = (currentData['moyenneScores'] is num)
          ? (currentData['moyenneScores'] as num).toDouble()
          : 0.0;
      final int nouveauNombreTentatives = anciennesTentatives + 1;
      final double moyenneScores =
          ((ancienneMoyenne * anciennesTentatives) + scorePourcentage) / (nouveauNombreTentatives == 0 ? 1 : nouveauNombreTentatives);

      if (kDebugMode) {
        debugPrint('   📈 Calcul des moyennes:');
        debugPrint('      - Oiseaux manqués (fréquence): $oiseauxManquesHistorique');
        debugPrint('      - Moyenne scores: ${moyenneScores.toStringAsFixed(1)}%');
      }

      // Préparer les données de mise à jour
      final Map<String, dynamic> updateData = {
        'tentatives': nouveauNombreTentatives,
        'dernierePartieLe': FieldValue.serverTimestamp(),
        'scoresHistorique': oiseauxManquesHistorique, // Maintenant stocke les oiseaux manqués
        'moyenneScores': double.parse(moyenneScores.toStringAsFixed(1)),
      };

      if (kDebugMode) {
        debugPrint('   📋 Données à mettre à jour:');
        debugPrint('      - Tentatives: ${anciennesTentatives + 1} (était $anciennesTentatives)');
        debugPrint('      - Moyenne scores: ${updateData['moyenneScores']}%');
        debugPrint('      - Oiseaux manqués: ${updateData['scoresHistorique']}');
      }

      // Mettre à jour les étoiles si de nouvelles ont été gagnées
      if (nouvellesEtoiles > anciennesEtoiles) {
        updateData['etoiles'] = nouvellesEtoiles;
        updateData['etoilesGagneesLe'] = FieldValue.serverTimestamp();

        if (kDebugMode) {
          debugPrint('🌟 Nouvelles étoiles gagnées pour $missionId: $anciennesEtoiles → $nouvellesEtoiles');
          
          // Expliquer le système progressif
          if (nouvellesEtoiles == 1) {
            debugPrint('   🎯 1ère étoile obtenue ! (8/10 minimum)');
          } else if (nouvellesEtoiles == 2) {
            debugPrint('   🎯 2ème étoile obtenue ! (8/10 minimum)');
            debugPrint('   🔓 La mission suivante sera déverrouillée !');
          } else if (nouvellesEtoiles == 3) {
            debugPrint('   🎯 3ème étoile obtenue ! (10/10 parfait requis)');
          }
        }
      }

      // Mettre à jour ou créer la progression
      if (doc.exists) {
        if (kDebugMode) {
          debugPrint('📊 Progression existante trouvée pour $missionId, mise à jour...');
        }
        await progressRef.update(updateData);
        if (kDebugMode) {
          debugPrint('✅ Progression mise à jour pour $missionId');
        }
      } else {
        // Créer une nouvelle progression (pas de champ creeLe pour éviter les doublons avec derniereMiseAJour)
        if (kDebugMode) {
          debugPrint('🎯 Aucune progression existante, création d\'une nouvelle pour $missionId...');
        }
        updateData['deverrouille'] = true;
        updateData['etoiles'] = nouvellesEtoiles; // Initialiser les étoiles lors de la création
        await progressRef.set(updateData);
        if (kDebugMode) {
          debugPrint('✅ Nouvelle progression créée pour $missionId');
        }
      }

      // Créer une session pour l'historique (les logs seront ajustés après)
      await _createSession(uid, missionId, score, totalQuestions, wrongBirds, dureePartie);

      // Vérifier si la mission suivante peut être déverrouillée (2ème étoile)
      if (nouvellesEtoiles >= 2 && anciennesEtoiles < 2) {
        if (kDebugMode) {
          debugPrint('🔓 Déverrouillage automatique de la mission suivante (2ème étoile obtenue)');
        }
        await _checkAndUnlockNextMission(uid, missionId);
      }

      if (kDebugMode) {
        debugPrint('✅ Mission $missionId mise à jour complètement');
        debugPrint('   Score: $score/$totalQuestions ($scorePourcentage%)');
        debugPrint('   Étoiles: $nouvellesEtoiles');
        debugPrint('   Tentatives: ${anciennesTentatives + 1}');
        debugPrint('   Moyenne: ${updateData['moyenneScores']}%');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la mise à jour de la mission $missionId: $e');
      }
      rethrow;
    }
  }

  /// Calcule le nombre d'étoiles basé sur le score et les étoiles actuelles
  static int calculateStars(int score, int total, int currentStars) {
    if (total == 0) return currentStars;
    final double ratio = score / total;
    
    if (kDebugMode) {
      debugPrint('   🎯 Calcul étoiles: score=$score/$total, ratio=${ratio.toStringAsFixed(2)}, étoiles actuelles=$currentStars');
    }
    
    // Logique progressive des étoiles
    if (ratio >= 0.8) { // 8/10 ou 9/10
      if (currentStars == 0) {
        if (kDebugMode) debugPrint('      ✅ 1ère étoile obtenue (≥8/10)');
        return 1; // Première étoile
      } else if (currentStars == 1) {
        if (kDebugMode) debugPrint('      ✅ 2ème étoile obtenue (≥8/10)');
        return 2; // Deuxième étoile
      } else if (currentStars == 2 && ratio == 1.0) {
        if (kDebugMode) debugPrint('      ✅ 3ème étoile obtenue (10/10 parfait)');
        return 3; // Troisième étoile (seulement avec 10/10)
      } else {
        if (kDebugMode) debugPrint('      ⏸️ Garde les étoiles actuelles ($currentStars)');
        return currentStars; // Garde les étoiles actuelles
      }
    }
    
    // Score insuffisant (< 8/10), garde les étoiles actuelles
    if (kDebugMode) debugPrint('      ❌ Score insuffisant (<8/10), garde $currentStars étoiles');
    return currentStars;
  }

  /// Crée une session pour l'historique
  static Future<void> _createSession(
    String uid,
    String missionId,
    int score,
    int totalQuestions,
    List<String> wrongBirds,
    Duration dureePartie,
  ) async {
    try {
      final sessionRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('sessions')
          .doc();

      await sessionRef.set({
        'idMission': missionId,
        'score': score,
        'totalQuestions': totalQuestions,
        'oiseauxManques': wrongBirds, // Renommé pour plus de clarté
        'dureePartie': dureePartie.inSeconds,
        'commenceLe': FieldValue.serverTimestamp(),
        'termineLe': FieldValue.serverTimestamp(),
        // Supprimé: reponsesCorrectes, reponsesIncorrectes, tauxReussite
      });

      if (kDebugMode) {
        debugPrint('📝 Session créée pour $missionId (score: $score/$totalQuestions)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Erreur lors de la création de la session: $e');
      }
    }
  }

  /// Vérifie et déverrouille la mission suivante si possible
  static Future<void> _checkAndUnlockNextMission(String uid, String currentMissionId) async {
    try {
      // Extraire le biome et l'index de la mission actuelle
      final biome = currentMissionId[0]; // U01 → U, F02 → F
      final currentIndex = int.parse(currentMissionId.substring(1));
      final nextMissionId = '$biome${(currentIndex + 1).toString().padLeft(2, '0')}';

      // Vérifier si la mission suivante existe
      final nextMissionRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('progression_missions')
          .doc(nextMissionId);

      final nextMissionDoc = await nextMissionRef.get();
      
      if (!nextMissionDoc.exists) {
        // Créer la progression pour la mission suivante
        await nextMissionRef.set({
          'etoiles': 0,
          'tentatives': 0,
          'deverrouille': true,
          'biome': biome,
          'index': currentIndex + 1,
          'deverrouilleLe': FieldValue.serverTimestamp(),
          'creeLe': FieldValue.serverTimestamp(),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
          'deverrouillePar': currentMissionId, // Mission qui a permis le déverrouillage
          'scoresHistorique': {}, // Map vide pour les oiseaux manqués
          'moyenneScores': 0.0, // Moyenne à 0
        });

        if (kDebugMode) {
          debugPrint('🔓 Mission suivante $nextMissionId déverrouillée automatiquement');
          debugPrint('   📍 Déverrouillée par: $currentMissionId (2ème étoile obtenue)');
          debugPrint('   🎯 Prête à être jouée avec 0 étoiles');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ Mission suivante $nextMissionId existe déjà');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Erreur lors du déverrouillage de la mission suivante: $e');
      }
    }
  }

  /// Obtient les statistiques complètes d'une mission
  static Future<Map<String, dynamic>?> getMissionStats(String missionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .doc(missionId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des stats de $missionId: $e');
      }
      return null;
    }
  }

  /// Obtient toutes les sessions d'une mission
  static Future<List<Map<String, dynamic>>> getMissionSessions(String missionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('sessions')
          .where('idMission', isEqualTo: missionId)
          .orderBy('termineLe', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des sessions de $missionId: $e');
      }
      return [];
    }
  }

  /// Obtient les statistiques globales de l'utilisateur
  static Future<Map<String, dynamic>> getUserGlobalStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final missionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .get();

      final sessionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('sessions')
          .get();

      int totalMissions = 0;
      int totalEtoiles = 0;
      int totalTentatives = 0;
      double totalScoreMoyen = 0;
      int missionsTerminees = 0;

      for (final doc in missionsSnapshot.docs) {
        final data = doc.data();
        totalMissions++;
        totalEtoiles += (data['etoiles'] ?? 0) as int;
        totalTentatives += (data['tentatives'] ?? 0) as int;
        totalScoreMoyen += (data['moyenneScores'] ?? 0.0) as double;
        
        if ((data['etoiles'] ?? 0) >= 2) {
          missionsTerminees++;
        }
      }

      final scoreMoyenGlobal = totalMissions > 0 ? totalScoreMoyen / totalMissions : 0;

      return {
        'totalMissions': totalMissions,
        'totalEtoiles': totalEtoiles,
        'totalTentatives': totalTentatives,
        'scoreMoyenGlobal': double.parse(scoreMoyenGlobal.toStringAsFixed(1)),
        'missionsTerminees': missionsTerminees,
        'totalSessions': sessionsSnapshot.docs.length,
        // Supprimé: tauxReussiteGlobal (calculé à partir de missionsTerminees)
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des stats globales: $e');
      }
      return {};
    }
  }
}
