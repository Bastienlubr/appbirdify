import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FavoritesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Ajoute un oiseau aux favoris
  static Future<void> addToFavorites(String birdId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('favoris_oiseaux')
          .doc(birdId)
          .set({
        'birdId': birdId,
        'ajouteLe': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('💖 Oiseau $birdId ajouté aux favoris');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout aux favoris: $e');
      }
      rethrow;
    }
  }

  /// Retire un oiseau des favoris
  static Future<void> removeFromFavorites(String birdId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('favoris_oiseaux')
          .doc(birdId)
          .delete();

      if (kDebugMode) {
        debugPrint('💔 Oiseau $birdId retiré des favoris');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la suppression des favoris: $e');
      }
      rethrow;
    }
  }

  /// Vérifie si un oiseau est dans les favoris
  static Future<bool> isFavorite(String birdId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('favoris_oiseaux')
          .doc(birdId)
          .get();

      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la vérification des favoris: $e');
      }
      return false;
    }
  }

  /// Récupère tous les IDs des oiseaux favoris
  static Future<Set<String>> getFavoriteIds() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('favoris_oiseaux')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des favoris: $e');
      }
      return {};
    }
  }

  /// Basculer le statut favori d'un oiseau
  static Future<bool> toggleFavorite(String birdId) async {
    final isFav = await isFavorite(birdId);
    if (isFav) {
      await removeFromFavorites(birdId);
      return false;
    } else {
      await addToFavorites(birdId);
      return true;
    }
  }
}
