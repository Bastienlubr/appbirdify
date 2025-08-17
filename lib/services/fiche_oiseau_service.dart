import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fiche_oiseau.dart';

/// Service pour gérer les fiches oiseaux dans Firestore
class FicheOiseauService {
	static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	static final FirebaseAuth _auth = FirebaseAuth.instance;
	static const String _collectionName = 'fiches_oiseaux';

	/// Collection Firestore
	static CollectionReference<Map<String, dynamic>> get _collection =>
			_firestore.collection(_collectionName);

	/// Assure l'authentification de l'utilisateur
	static Future<bool> _ensureUserAuthenticated() async {
		try {
			if (_auth.currentUser != null) {
				return true;
			}

			// Tentative d'authentification anonyme
			await _auth.signInAnonymously();
			return _auth.currentUser != null;
		} catch (e) {
			print('Erreur authentification anonyme: $e');
			return false;
		}
	}

	/// Récupère une fiche oiseau par son ID
	static Future<FicheOiseau?> getFicheById(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getFicheById: Impossible d\'assurer l\'authentification');
				return null;
			}

			final docSnapshot = await _collection.doc(idOiseau).get();
			
			if (!docSnapshot.exists) {
				print('FicheOiseauService: Document non trouvé pour l\'ID $idOiseau');
				return null;
			}

			final data = docSnapshot.data() as Map<String, dynamic>?;
			if (data == null) {
				print('FicheOiseauService: Données nulles pour la fiche $idOiseau');
				return null;
			}

			return FicheOiseau.fromFirestore(data);
		} catch (e) {
			print('Erreur lors de la récupération de la fiche $idOiseau: $e');
			return null;
		}
	}

	/// Récupère une fiche par nom scientifique exact (ex: "Prunella modularis")
	static Future<FicheOiseau?> getFicheByNomScientifique(String nomScientifique) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getFicheByNomScientifique: Impossible d\'assurer l\'authentification');
				return null;
			}

			final query = await _collection
				.where('nomScientifique', isEqualTo: nomScientifique)
				.limit(1)
				.get();
			if (query.docs.isEmpty) return null;
			final data = query.docs.first.data();
			return FicheOiseau.fromFirestore(data);
		} catch (e) {
			print('Erreur getFicheByNomScientifique($nomScientifique): $e');
			return null;
		}
	}

	/// Écoute les changements d'une fiche oiseau en temps réel
	static Stream<FicheOiseau?> watchFicheById(String idOiseau) {
		return _collection.doc(idOiseau).snapshots().map((docSnapshot) {
			if (!docSnapshot.exists) {
				return null;
			}

			final data = docSnapshot.data() as Map<String, dynamic>?;
			if (data == null) {
				return null;
			}

			return FicheOiseau.fromFirestore(data);
		}).handleError((error) {
			print('Erreur watchFicheById: $error');
			return null;
		});
	}

	/// Récupère toutes les fiches oiseaux
	static Future<List<FicheOiseau>> getAllFiches() async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getAllFiches: Impossible d\'assurer l\'authentification');
				return [];
			}

			final querySnapshot = await _collection.get();
			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data() as Map<String, dynamic>;
					final fiche = FicheOiseau.fromFirestore(data);
					fiches.add(fiche);
				} catch (e) {
					print('Erreur lors du parsing de la fiche ${doc.id}: $e');
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			print('Erreur lors de la récupération de toutes les fiches: $e');
			return [];
		}
	}

	/// Récupère les fiches oiseaux avec pagination
	static Future<List<FicheOiseau>> getFichesPaginated({
		required int limit,
		DocumentSnapshot? startAfter,
	}) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getFichesPaginated: Impossible d\'assurer l\'authentification');
				return [];
			}

			Query query = _collection.orderBy('nomFrancais').limit(limit);
			
			if (startAfter != null) {
				query = query.startAfterDocument(startAfter);
			}

			final querySnapshot = await query.get();
			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data() as Map<String, dynamic>;
					final fiche = FicheOiseau.fromFirestore(data);
					fiches.add(fiche);
				} catch (e) {
					print('Erreur lors du parsing de la fiche ${doc.id}: $e');
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			print('Erreur lors de la récupération des fiches paginées: $e');
			return [];
		}
	}

	/// Recherche des fiches oiseaux par nom
	static Future<List<FicheOiseau>> searchFichesByName(String searchTerm) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur searchFichesByName: Impossible d\'assurer l\'authentification');
				return [];
			}

			if (searchTerm.isEmpty) {
				return [];
			}

			// Recherche insensible à la casse
			final searchTermLower = searchTerm.toLowerCase();
			
			final querySnapshot = await _collection
					.where('nomFrancais', isGreaterThanOrEqualTo: searchTermLower)
					.where('nomFrancais', isLessThan: searchTermLower + '\uf8ff')
					.limit(20)
					.get();

			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data() as Map<String, dynamic>;
					final fiche = FicheOiseau.fromFirestore(data);
					
					// Filtre supplémentaire côté client pour plus de précision
					if (fiche.nomFrancais.toLowerCase().contains(searchTermLower) ||
							fiche.nomScientifique.toLowerCase().contains(searchTermLower)) {
						fiches.add(fiche);
					}
				} catch (e) {
					print('Erreur lors du parsing de la fiche ${doc.id}: $e');
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			print('Erreur lors de la recherche des fiches: $e');
			return [];
		}
	}

	/// Recherche des fiches oiseaux par habitat
	static Future<List<FicheOiseau>> getFichesByHabitat(String habitat) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getFichesByHabitat: Impossible d\'assurer l\'authentification');
				return [];
			}

			if (habitat.isEmpty) {
				return [];
			}

			final querySnapshot = await _collection
					.where('habitat.milieux', arrayContains: habitat)
					.limit(50)
					.get();

			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data() as Map<String, dynamic>;
					final fiche = FicheOiseau.fromFirestore(data);
					fiches.add(fiche);
				} catch (e) {
					print('Erreur lors du parsing de la fiche ${doc.id}: $e');
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			print('Erreur lors de la récupération des fiches par habitat: $e');
			return [];
		}
	}

	/// Crée une nouvelle fiche oiseau
	static Future<bool> createFiche(FicheOiseau fiche) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur createFiche: Impossible d\'assurer l\'authentification');
				return false;
			}

			await _collection.doc(fiche.idOiseau).set(fiche.toFirestore());
			print('Fiche oiseau créée avec succès: ${fiche.idOiseau}');
			return true;
		} catch (e) {
			print('Erreur lors de la création de la fiche ${fiche.idOiseau}: $e');
			return false;
		}
	}

	/// Met à jour une fiche oiseau existante
	static Future<bool> updateFiche(FicheOiseau fiche) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur updateFiche: Impossible d\'assurer l\'authentification');
				return false;
			}

			await _collection.doc(fiche.idOiseau).update(fiche.toFirestore());
			print('Fiche oiseau mise à jour avec succès: ${fiche.idOiseau}');
			return true;
		} catch (e) {
			print('Erreur lors de la mise à jour de la fiche ${fiche.idOiseau}: $e');
			return false;
		}
	}

	/// Supprime une fiche oiseau
	static Future<bool> deleteFiche(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur deleteFiche: Impossible d\'assurer l\'authentification');
				return false;
			}

			await _collection.doc(idOiseau).delete();
			print('Fiche oiseau supprimée avec succès: $idOiseau');
			return true;
		} catch (e) {
			print('Erreur lors de la suppression de la fiche $idOiseau: $e');
			return false;
		}
	}

	/// Crée ou met à jour une fiche oiseau (upsert)
	static Future<bool> upsertFiche(FicheOiseau fiche) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur upsertFiche: Impossible d\'assurer l\'authentification');
				return false;
			}

			await _collection.doc(fiche.idOiseau).set(fiche.toFirestore(), SetOptions(merge: true));
			print('Fiche oiseau upsertée avec succès: ${fiche.idOiseau}');
			return true;
		} catch (e) {
			print('Erreur lors de l\'upsert de la fiche ${fiche.idOiseau}: $e');
			return false;
		}
	}

	/// Importe plusieurs fiches en lot
	static Future<bool> importFichesBatch(List<FicheOiseau> fiches) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur importFichesBatch: Impossible d\'assurer l\'authentification');
				return false;
			}

			if (fiches.isEmpty) {
				print('Aucune fiche à importer');
				return true;
			}

			// Firestore limite les batch à 500 opérations
			const int batchSize = 500;
			int successCount = 0;
			int errorCount = 0;

			for (int i = 0; i < fiches.length; i += batchSize) {
				final batch = _firestore.batch();
				final endIndex = (i + batchSize < fiches.length) ? i + batchSize : fiches.length;
				
				for (int j = i; j < endIndex; j++) {
					final fiche = fiches[j];
					final docRef = _collection.doc(fiche.idOiseau);
					batch.set(docRef, fiche.toFirestore(), SetOptions(merge: true));
				}

				try {
					await batch.commit();
					successCount += endIndex - i;
					print('Lot ${(i ~/ batchSize) + 1} importé avec succès: ${endIndex - i} fiches');
				} catch (e) {
					errorCount += endIndex - i;
					print('Erreur lors de l\'import du lot ${(i ~/ batchSize) + 1}: $e');
				}
			}

			print('Import terminé: $successCount succès, $errorCount erreurs');
			return errorCount == 0;
		} catch (e) {
			print('Erreur lors de l\'import en lot: $e');
			return false;
		}
	}

	/// Compte le nombre total de fiches
	static Future<int> getFichesCount() async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getFichesCount: Impossible d\'assurer l\'authentification');
				return 0;
			}

			final querySnapshot = await _collection.count().get();
			return querySnapshot.count ?? 0;
		} catch (e) {
			print('Erreur lors du comptage des fiches: $e');
			return 0;
		}
	}

	/// Vérifie si une fiche existe
	static Future<bool> ficheExists(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur ficheExists: Impossible d\'assurer l\'authentification');
				return false;
			}

			final docSnapshot = await _collection.doc(idOiseau).get();
			return docSnapshot.exists;
		} catch (e) {
			print('Erreur lors de la vérification de l\'existence de la fiche $idOiseau: $e');
			return false;
		}
	}

	/// Récupère les statistiques des fiches
	static Future<Map<String, dynamic>> getFichesStats() async {
		try {
			if (!await _ensureUserAuthenticated()) {
				print('Erreur getFichesStats: Impossible d\'assurer l\'authentification');
				return {};
			}

			final totalCount = await getFichesCount();
			
			// Compter par habitat
			final habitats = ['milieu urbain', 'milieu forestier', 'milieu agricole', 'milieu humide', 'milieu montagnard', 'milieu littoral'];
			final statsByHabitat = <String, int>{};
			
			for (final habitat in habitats) {
				try {
					final querySnapshot = await _collection
							.where('habitat.milieux', arrayContains: habitat)
							.count()
							.get();
					statsByHabitat[habitat] = querySnapshot.count ?? 0;
				} catch (e) {
					statsByHabitat[habitat] = 0;
				}
			}

			return {
				'total': totalCount,
				'parHabitat': statsByHabitat,
				'dateMiseAJour': DateTime.now().toIso8601String(),
			};
		} catch (e) {
			print('Erreur lors de la récupération des statistiques: $e');
			return {};
		}
	}
}
