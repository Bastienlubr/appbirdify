import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Réinitialise les vies à 5 si le dernier reset date d'avant aujourd'hui
  /// 
  /// Cette méthode :
  /// - Récupère le document Firestore dans la collection `users` avec l'uid donné
  /// - Compare le champ `dailyResetDate` avec aujourd'hui (DateTime.now())
  /// - Si la date est antérieure à aujourd'hui :
  ///   - Met à jour `livesRemaining` à 5
  ///   - Met `dailyResetDate` à aujourd'hui (avec heure à minuit)
  Future<void> resetLivesIfNeeded(String uid) async {
    try {
      // Récupérer le document utilisateur
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Si l'utilisateur n'existe pas, créer le document avec les valeurs par défaut
        DateTime today = DateTime.now();
        DateTime todayMidnight = DateTime(today.year, today.month, today.day);
        
        await userRef.set({
          'livesRemaining': 5,
          'dailyResetDate': todayMidnight,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Récupérer les données actuelles
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Vérifier si dailyResetDate existe, sinon utiliser une date par défaut
      DateTime? lastResetDate;
      if (userData['dailyResetDate'] != null) {
        if (userData['dailyResetDate'] is Timestamp) {
          lastResetDate = (userData['dailyResetDate'] as Timestamp).toDate();
        } else if (userData['dailyResetDate'] is DateTime) {
          lastResetDate = userData['dailyResetDate'] as DateTime;
        }
      }

      // Calculer aujourd'hui à minuit
      DateTime today = DateTime.now();
      DateTime todayMidnight = DateTime(today.year, today.month, today.day);

      // Si pas de date de reset ou si la dernière date est antérieure à aujourd'hui
      if (lastResetDate == null || lastResetDate.isBefore(todayMidnight)) {
        // Mettre à jour les vies et la date de reset
        await userRef.update({
          'livesRemaining': 5,
          'dailyResetDate': todayMidnight,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur lors de la réinitialisation des vies: $e');
      rethrow;
    }
  }

  /// Récupère le nombre de vies restantes d'un utilisateur
  Future<int> getLivesRemaining(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        return 5; // Valeur par défaut
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['livesRemaining'] ?? 5;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur lors de la récupération des vies: $e');
      return 5; // Valeur par défaut en cas d'erreur
    }
  }

  /// Consomme une vie pour un utilisateur
  Future<bool> consumeLife(String uid) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      
      // Utiliser une transaction pour éviter les conditions de course
      bool success = await _firestore.runTransaction<bool>((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          return false;
        }

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        int currentLives = userData['livesRemaining'] ?? 5;

        if (currentLives > 0) {
          transaction.update(userRef, {
            'livesRemaining': currentLives - 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          return true;
        }
        
        return false;
      });

      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur lors de la consommation d\'une vie: $e');
      return false;
    }
  }

  /// Consomme plusieurs vies pour un utilisateur
  /// 
  /// Cette méthode :
  /// - Décrémente le nombre de vies spécifié dans Firestore
  /// - Protège contre les décréments négatifs (ne passe jamais en dessous de 0)
  /// - Retourne le nombre de vies effectivement consommées
  Future<int> consumeLives(String uid, int count) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      
      // Utiliser une transaction pour éviter les conditions de course
      int consumedLives = await _firestore.runTransaction<int>((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          return 0;
        }

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        int currentLives = userData['livesRemaining'] ?? 5;

        // Calculer combien de vies peuvent être consommées
        int actualConsumed = count > currentLives ? currentLives : count;
        int newLivesCount = currentLives - actualConsumed;

        // S'assurer qu'on ne passe jamais en dessous de 0
        if (newLivesCount < 0) {
          newLivesCount = 0;
          actualConsumed = currentLives;
        }

        if (actualConsumed > 0) {
          transaction.update(userRef, {
            'livesRemaining': newLivesCount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        return actualConsumed;
      });

      return consumedLives;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur lors de la consommation des vies: $e');
      return 0;
    }
  }

  /// Crée le document utilisateur dans Firestore s'il n'existe pas
  /// 
  /// Cette méthode :
  /// - Vérifie si un document `users/<uid>` existe dans Firestore
  /// - Si non, crée un document avec les champs par défaut
  /// - Retourne true si le document a été créé, false s'il existait déjà
  Future<bool> createUserDocumentIfNeeded(String uid) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Calculer aujourd'hui à minuit
        DateTime today = DateTime.now();
        DateTime todayMidnight = DateTime(today.year, today.month, today.day);

        // Créer le document avec les champs par défaut
        await userRef.set({
          'livesRemaining': 5,
          'dailyResetDate': todayMidnight,
          'xp': 0,
          'isPremium': false,
          'currentBiome': 'milieu urbain',
          'biomesUnlocked': ['milieu urbain'],
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        return true; // Document créé
      }

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
          .collection('users')
          .doc(uid)
          .collection('missions')
          .doc(missionId);

      // Mettre à jour ou créer le document mission
      await missionRef.set({
        'lastStarsEarned': newStars,
        'lastUpdated': FieldValue.serverTimestamp(),
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