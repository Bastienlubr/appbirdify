import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DevToolsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Restaure toutes les étoiles à 0 pour toutes les missions
  static Future<void> resetAllStars() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('🔄 Restauration des étoiles pour ${user.uid}...');
      }

      final missionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ Aucune mission à restaurer');
        }
        return;
      }

      final batch = _firestore.batch();
      int missionsUpdated = 0;

      for (final missionDoc in missionsSnapshot.docs) {
        final missionId = missionDoc.id;
        
        // Remettre à zéro les statistiques
        batch.update(missionDoc.reference, {
          'etoiles': 0,
          'tentatives': 0,
          'moyenneScores': 0.0,
          'scoresHistorique': {},
          'scoresPourcentagesPasses': [],
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        missionsUpdated++;
        
        if (kDebugMode) {
          debugPrint('   🎯 $missionId: étoiles remises à 0');
        }
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('✅ $missionsUpdated missions restaurées avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la restauration des étoiles: $e');
      }
      rethrow;
    }
  }

  /// Restaure les vies à 5
  static Future<void> restoreLives() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('💚 Restauration des vies pour ${user.uid}...');
      }

      // Nouveau schéma unifié
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .set({
        'vie': {
          'vieRestante': 5,
          'vieMaximum': 5,
          'prochaineRecharge': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
        // Nettoyage anciens schémas
        'Vie restante': FieldValue.delete(),
        'livesRemaining': FieldValue.delete(),
        'vies.compte': FieldValue.delete(),
        'vies.max': FieldValue.delete(),
        'vies.Vie restante': FieldValue.delete(),
        'vies.prochaineRecharge': FieldValue.delete(),
        'vie.Vie restante': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Vies restaurées à 5 (schéma unifié)');
        debugPrint('   📍 Champ utilisé: "vie.vieRestante"');
        debugPrint('   🔄 Synchronisation Firestore terminée, vies mises à jour');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la restauration des vies: $e');
      }
      rethrow;
    }
  }

  /// Active/désactive le mode vies infinies sur le compte courant
  static Future<void> setInfiniteLives(bool enabled) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('♾️ Mise à jour du mode vies infinies=$enabled pour ${user.uid}');
      }

      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .set({
        'livesInfinite': enabled,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Mode vies infinies ${enabled ? 'activé' : 'désactivé'}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du paramétrage vies infinies: $e');
      }
      rethrow;
    }
  }

  /// Déverrouille toutes les missions d'un biome
  static Future<void> unlockAllBiomeMissions(String biome) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('🔓 Déverrouillage de toutes les missions du biome $biome...');
      }

      final missionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .where('biome', isEqualTo: biome)
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ Aucune mission trouvée pour le biome $biome');
        }
        return;
      }

      final batch = _firestore.batch();
      int missionsUnlocked = 0;

      for (final missionDoc in missionsSnapshot.docs) {
        final missionId = missionDoc.id;
        
        batch.update(missionDoc.reference, {
          'deverrouille': true,
          'deverrouilleLe': FieldValue.serverTimestamp(),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        missionsUnlocked++;
        
        if (kDebugMode) {
          debugPrint('   🔓 $missionId déverrouillée');
        }
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('✅ $missionsUnlocked missions du biome $biome déverrouillées');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du déverrouillage: $e');
      }
      rethrow;
    }
  }

  /// Déverrouille toutes les missions
  static Future<void> unlockAllMissions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('🔓 Déverrouillage de toutes les missions...');
      }

      final missionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ Aucune mission trouvée');
        }
        return;
      }

      final batch = _firestore.batch();
      int missionsUnlocked = 0;

      for (final missionDoc in missionsSnapshot.docs) {
        final missionId = missionDoc.id;
        
        batch.update(missionDoc.reference, {
          'deverrouille': true,
          'deverrouilleLe': FieldValue.serverTimestamp(),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        missionsUnlocked++;
        
        if (kDebugMode) {
          debugPrint('   🔓 $missionId déverrouillée');
        }
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('✅ $missionsUnlocked missions déverrouillées');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du déverrouillage: $e');
      }
      rethrow;
    }
  }

  /// Déconnexion de l'utilisateur
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) {
        debugPrint('🚪 Utilisateur déconnecté');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la déconnexion: $e');
      }
      rethrow;
    }
  }

  /// Obtient les informations de l'utilisateur actuel
  static Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des infos utilisateur: $e');
      }
      return null;
    }
  }

  /// Obtient le nombre de missions déverrouillées
  static Future<int> getUnlockedMissionsCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final missionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .where('deverrouille', isEqualTo: true)
          .get();

      return missionsSnapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du comptage des missions: $e');
      }
      return 0;
    }
  }

  /// Obtient le total des étoiles de l'utilisateur
  static Future<int> getTotalStars() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final missionsSnapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .get();

      int totalStars = 0;
      for (final missionDoc in missionsSnapshot.docs) {
        final data = missionDoc.data();
        totalStars += (data['etoiles'] ?? 0) as int;
      }

      return totalStars;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du calcul des étoiles: $e');
      }
      return 0;
    }
  }

  /// Déverrouille toutes les étoiles (3 étoiles par mission)
  /// Crée et complète automatiquement toutes les missions de tous les biomes
  static Future<void> unlockAllStars() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('⭐ Déverrouillage de toutes les étoiles pour ${user.uid}...');
      }

      // Définir toutes les missions existantes par biome
      final Map<String, List<String>> allMissions = {
        'urbain': ['U01', 'U02', 'U03', 'U04'],
        'forestier': ['F01', 'F02', 'F03', 'F04'],
        'agricole': ['A01', 'A02', 'A03', 'A04'],
        'humide': ['H01', 'H02', 'H03', 'H04'],
        'montagnard': ['M01', 'M02', 'M03', 'M04'],
        'littoral': ['L01', 'L02', 'L03', 'L04'],
      };

      // Mapper biome vers code de biome pour compatibilité
      final Map<String, String> biomeToCode = {
        'urbain': 'U',
        'forestier': 'F', 
        'agricole': 'A',
        'humide': 'H',
        'montagnard': 'M',
        'littoral': 'L',
      };

      final batch = _firestore.batch();
      int missionsCreated = 0;

      // Pour chaque biome et ses missions
      for (final biomeEntry in allMissions.entries) {
        final biomeName = biomeEntry.key;
        final missionIds = biomeEntry.value;
        final biomeCode = biomeToCode[biomeName]!;

        for (int i = 0; i < missionIds.length; i++) {
          final missionId = missionIds[i];
          final missionIndex = i + 1;
          
          // Référence du document de progression
          final missionRef = _firestore
              .collection('utilisateurs')
              .doc(user.uid)
              .collection('progression_missions')
              .doc(missionId);

          // Créer/mettre à jour la progression avec 3 étoiles
          batch.set(missionRef, {
            'missionId': missionId,
            'biome': biomeCode,
            'index': missionIndex,
            'etoiles': 3,
            'tentatives': 1,
            'moyenneScores': 100.0,
            'scoresHistorique': {
              DateTime.now().millisecondsSinceEpoch.toString(): 100.0
            },
            'scoresPourcentagesPasses': [100.0],
            'deverrouille': true,
            'deverrouilleLe': FieldValue.serverTimestamp(),
            'derniereMiseAJour': FieldValue.serverTimestamp(),
            'creeLe': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          missionsCreated++;
          
          if (kDebugMode) {
            debugPrint('   ⭐ $missionId ($biomeName): 3 étoiles accordées');
          }
        }
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('✅ $missionsCreated missions complétées avec 3 étoiles sur tous les biomes');
        debugPrint('📊 Biomes traités: ${allMissions.keys.join(', ')}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du déverrouillage des étoiles: $e');
      }
      rethrow;
    }
  }
}
