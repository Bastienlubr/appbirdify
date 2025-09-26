import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'Users/streak_service.dart';
import 'Perchoir/fiche_oiseau_service.dart';
import '../core/iap_flags.dart';

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
        // plus de champ root lastUpdated
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
      if (!kEnableClientFallback) {
        if (kDebugMode) debugPrint('⏭️ setInfiniteLives ignoré (kEnableClientFallback=false)');
        return;
      }
      final user = _auth.currentUser;
      if (user == null) return;

      if (kDebugMode) {
        debugPrint('♾️ Mise à jour du mode vies infinies=$enabled pour ${user.uid}');
      }

      await _firestore.collection('utilisateurs').doc(user.uid).set({
        'vie': {
          'livesInfinite': enabled,
        },
        'livesInfinite': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (kDebugMode) debugPrint('✅ Mode vies infinies ${enabled ? 'activé' : 'désactivé'} (vie.livesInfinite)');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du paramétrage vies infinies: $e');
      }
      rethrow;
    }
  }

  /// Définit le maximum de vies (vie.vieMaximum)
  static Future<void> setMaxLives(int value) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection('utilisateurs').doc(user.uid);
    final snap = await ref.get();
    final Map<String, dynamic>? data = snap.data();
    final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic> ? (data?['vie']) : null;
    final int current = (vie?['vieRestante'] as int? ?? 5).clamp(0, 50);
    final int newMax = value.clamp(1, 50);
    final int clampedCurrent = current.clamp(0, newMax);
    await ref.set({
      'vie': {
        'vieMaximum': newMax,
        'vieRestante': clampedCurrent,
      }
    }, SetOptions(merge: true));
    if (kDebugMode) debugPrint('✅ Max vies défini à $newMax, vies restantes clampées à $clampedCurrent');
  }

  /// Réinitialise vie.vieMaximum à 5
  static Future<void> resetMaxLivesToFive() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection('utilisateurs').doc(user.uid);
    final snap = await ref.get();
    final Map<String, dynamic>? data = snap.data();
    final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic> ? (data?['vie']) : null;
    final int current = (vie?['vieRestante'] as int? ?? 5).clamp(0, 50);
    final int clampedCurrent = current.clamp(0, 5);
    await ref.set({
      'vie': {
        'vieMaximum': 5,
        'vieRestante': clampedCurrent,
      }
    }, SetOptions(merge: true));
    if (kDebugMode) debugPrint('✅ vieMaximum=5, vieRestante clampée à $clampedCurrent');
  }

  /// Ajoute 1 vie (sans dépasser vie.vieMaximum)
  static Future<void> addOneLife() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection('utilisateurs').doc(user.uid);
    final snap = await ref.get();
    final data = snap.data() is Map<String, dynamic> ? snap.data() as Map<String, dynamic> : null;
    final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic> ? (data?['vie']) : null;
    final int maxLives = (vie?['vieMaximum'] as int? ?? 5).clamp(1, 50);
    final int current = (vie?['vieRestante'] as int? ?? 5).clamp(0, maxLives);
    final int next = (current + 1).clamp(0, maxLives);
    await ref.set({
      'vie': {
        'vieRestante': next,
      }
    }, SetOptions(merge: true));
    if (kDebugMode) debugPrint('✅ Vie ajoutée: $current -> $next (max=$maxLives)');
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

  /// Supprime le champ biomesDeverrouilles du document utilisateur (dépoussiérage)
  static Future<void> removeUnlockedBiomesField() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection('utilisateurs').doc(user.uid).set({
        'biomesDeverrouilles': FieldValue.delete(),
        'biomesUnlocked': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('🧹 Champ biomesDeverrouilles supprimé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ removeUnlockedBiomesField error: $e');
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
        totalStars += (missionDoc.data()['etoiles'] ?? 0) as int;
      }

      return totalStars;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du calcul des étoiles: $e');
      }
      return 0;
    }
  }

  /// Normalise la série en cours: conserve uniquement les jours consécutifs jusqu'à aujourd'hui
  static Future<void> normalizeCurrentStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await StreakService.normalizeCurrentStreak(user.uid);
      if (kDebugMode) debugPrint('✅ Série normalisée pour ${user.uid}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ normalizeCurrentStreak error: $e');
      rethrow;
    }
  }

  /// Assure l'unicité de livesInfinite: place sous vie.livesInfinite et supprime la racine
  static Future<void> fixLivesInfinitePlacement() async {
    try {
      if (!kEnableClientFallback) {
        if (kDebugMode) debugPrint('⏭️ fixLivesInfinitePlacement ignoré (kEnableClientFallback=false)');
        return;
      }
      final user = _auth.currentUser;
      if (user == null) return;
      final ref = _firestore.collection('utilisateurs').doc(user.uid);
      final snap = await ref.get();
      final Map<String, dynamic>? data = snap.data();
      final bool nested = (data?['vie']?['livesInfinite'] == true);
      final bool root = (data?['livesInfinite'] == true);
      final bool value = nested || root;
      await ref.set({
        'vie': {
          'livesInfinite': value,
        },
        // Toujours supprimer le champ racine s'il subsiste
        'livesInfinite': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('🧹 fixLivesInfinitePlacement: vie.livesInfinite=$value, racine supprimée');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ fixLivesInfinitePlacement error: $e');
      rethrow;
    }
  }

  /// Supprime explicitement l'ancien champ racine livesInfinite (sans toucher à vie.livesInfinite)
  static Future<void> deleteRootLivesInfinite() async {
    try {
      if (!kEnableClientFallback) {
        if (kDebugMode) debugPrint('⏭️ deleteRootLivesInfinite ignoré (kEnableClientFallback=false)');
        return;
      }
      final user = _auth.currentUser;
      if (user == null) return;
      final ref = _firestore.collection('utilisateurs').doc(user.uid);
      await ref.set({
        'livesInfinite': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('🗑️ Champ racine livesInfinite supprimé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ deleteRootLivesInfinite error: $e');
      rethrow;
    }
  }

  /// Lit l'état premium (profil.estPremium)
  static Future<bool> isPremium() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await _firestore.collection('utilisateurs').doc(user.uid).get();
      return (doc.data()?['profil']?['estPremium'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Définit l'état premium et synchronise livesInfinite en conséquence
  static Future<void> setPremium(bool enabled) async {
    try {
      if (!kEnableClientFallback) {
        if (kDebugMode) debugPrint('⏭️ setPremium ignoré (kEnableClientFallback=false)');
        return;
      }
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection('utilisateurs').doc(user.uid).set({
        'profil': {
          'estPremium': enabled,
        },
        'vie': {
          'livesInfinite': enabled,
        },
        'livesInfinite': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('✅ Premium ${enabled ? 'activé' : 'désactivé'} pour ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ setPremium error: $e');
      rethrow;
    }
  }

  /// Inverse l'état premium actuel
  static Future<void> togglePremium() async {
    if (!kEnableClientFallback) {
      if (kDebugMode) debugPrint('⏭️ togglePremium ignoré (kEnableClientFallback=false)');
      return;
    }
    final current = await isPremium();
    await setPremium(!current);
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
            'scoresHistorique': {},
            'deverrouille': true,
            'deverrouilleLe': FieldValue.serverTimestamp(),
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

  // =============================
  // Cache Firestore - Outils Debug
  // =============================

  /// Vide le cache Firestore pour forcer le rechargement des données
  static Future<void> clearFirestoreCache() async {
    try {
      if (kDebugMode) {
        debugPrint('🧹 Vidage du cache Firestore...');
      }
      
      await FicheOiseauService.clearFirestoreCache();
      
      if (kDebugMode) {
        debugPrint('✅ Cache Firestore vidé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du vidage du cache Firestore: $e');
      }
      rethrow;
    }
  }

  /// Force le rechargement d'une fiche oiseau depuis le serveur
  static Future<bool> refreshBirdDataFromServer(String birdId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Rechargement de la fiche $birdId depuis le serveur...');
      }
      
      final fiche = await FicheOiseauService.getFicheFromServer(birdId);
      
      if (fiche != null) {
        if (kDebugMode) {
          debugPrint('✅ Fiche $birdId rechargée avec succès');
          debugPrint('   📋 Nom: ${fiche.nomFrancais}');
          debugPrint('   🔬 Famille: ${fiche.famille}');
          debugPrint('   📏 Morphologie: ${fiche.identification.morphologie?.substring(0, 50) ?? 'Non définie'}...');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Fiche $birdId non trouvée sur le serveur');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du rechargement de la fiche $birdId: $e');
      }
      return false;
    }
  }

  /// Vide le cache et force la synchronisation de toutes les fiches oiseaux
  static Future<void> refreshAllBirdData() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Rechargement complet des données oiseaux...');
      }
      
      // Vider le cache d'abord
      await clearFirestoreCache();
      
      // Attendre que le cache soit vidé
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (kDebugMode) {
        debugPrint('✅ Toutes les données oiseaux seront rechargées au prochain accès');
        debugPrint('🎯 Les fiches montreront maintenant les données mises à jour depuis Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du rechargement complet: $e');
      }
      rethrow;
    }
  }
}

/// Contrôle global d'affichage des outils de développement (overlays, boutons de test, etc.).
/// Ne masque PAS le bouton DevToolsMenu lui-même.
class DevVisibilityService {
  // Par défaut: visible en debug, masqué en release
  static final ValueNotifier<bool> overlaysEnabled = ValueNotifier<bool>(false);

  static bool get isOverlaysEnabled => overlaysEnabled.value;

  static void setOverlaysEnabled(bool enabled) {
    if (overlaysEnabled.value != enabled) {
      overlaysEnabled.value = enabled;
    }
  }

  static void toggle() => setOverlaysEnabled(!isOverlaysEnabled);
}
