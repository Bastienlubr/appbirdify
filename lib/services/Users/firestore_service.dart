import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crée le document utilisateur dans Firestore s'il n'existe pas
  /// 
  /// Cette méthode :
  /// - Vérifie si un document `users/<uid>` existe dans Firestore
  /// - Si non, crée un document avec les champs par défaut
  /// - Retourne true si le document a été créé, false s'il existait déjà
  Future<bool> createUserDocumentIfNeeded(String uid) async {
    try {
      DocumentReference userRef = _firestore.collection('utilisateurs').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Créer le document avec la nouvelle structure unifiée (UserOrchestra)
        final now = DateTime.now();
        final nextMidnight = DateTime(now.year, now.month, now.day + 1);
        await userRef.set({
          // Déplacer la date de création sous profil
          'profil': {
            'creeLe': FieldValue.serverTimestamp(),
            'email': null,
            'nomAffichage': null,
            'estPremium': false,
            'derniereConnexion': FieldValue.serverTimestamp(),
          },
          'parametres': {
            'langue': 'fr',
            'notifications': true,
            'son': true,
            'theme': null,
          },
          // (Supprimé) biomesDeverrouilles — non utilisé
          'serie': {
            'derniersJoursActifs': <String>[],
            'serieEnCours': 0,
            'serieMaximum': 0,
          },
          'vie': {
            'vieRestante': 5,
            'prochaineRecharge': nextMidnight,
            'vieMaximum': 5,
          },
        });

        return true; // Document créé
      }

      // Document existait déjà → nettoyage lastUpdated si présent
      await userRef.set({'lastUpdated': FieldValue.delete()}, SetOptions(merge: true));
      return false; // Document existait déjà
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur lors de la création du document utilisateur: $e');
      return false;
    }
  }

  /// Met à jour le nombre d'étoiles gagnées pour une mission spécifique
  /// 
  /// Cette méthode :
  /// - Met à jour le champ `lastStarsEarned` dans la sous-collection `missions`
  /// - Structure : users/[uid]/missions/[missionId]
  /// - Crée le document mission s'il n'existe pas
  /// 
  /// [uid] : ID de l'utilisateur
  /// [missionId] : ID de la mission (ex: 'U01', 'F01', etc.)
  /// [newStars] : Nouveau nombre d'étoiles (0-3)
  Future<void> updateMissionStars(String uid, String missionId, int newStars) async {
    try {
      // Référence vers le document mission dans la sous-collection
      DocumentReference missionRef = _firestore
          .collection('utilisateurs')
          .doc(uid)
          .collection('missions')
          .doc(missionId);

      // Mettre à jour ou créer le document mission
      await missionRef.set({
        'lastStarsEarned': newStars,
      }, SetOptions(merge: true)); // merge: true permet de créer le document s'il n'existe pas

      if (kDebugMode) {
        debugPrint('Étoiles mises à jour pour la mission $missionId: $newStars étoiles');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur lors de la mise à jour des étoiles: $e');
      rethrow;
    }
  }





} 