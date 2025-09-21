import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/fiche_oiseau.dart';

/// Service pour gérer les fiches oiseaux dans Firestore
class FicheOiseauService {
	static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	static final FirebaseAuth _auth = FirebaseAuth.instance;
	static const String _collectionName = 'fiches_oiseaux';

	static String _slugify(String input) {
		final lower = input.trim().toLowerCase();
		final withoutDiacritics = lower
			.replaceAll(RegExp(r"[àáâä]"), 'a')
			.replaceAll(RegExp(r"[ç]"), 'c')
			.replaceAll(RegExp(r"[èéêë]"), 'e')
			.replaceAll(RegExp(r"[îï]"), 'i')
			.replaceAll(RegExp(r"[ôö]"), 'o')
			.replaceAll(RegExp(r"[ùúûü]"), 'u')
			.replaceAll(RegExp(r"[^a-z0-9\s-]"), '')
			.replaceAll(RegExp(r"[\s_]+"), '-');
		return withoutDiacritics;
	}

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
			if (kDebugMode) {
				debugPrint('Erreur authentification anonyme: $e');
			}
			return false;
		}
	}

	/// Construit une map fusionnée parent + sous-collections `current` (si présentes)
	static Future<Map<String, dynamic>> _buildMergedData(
		DocumentReference<Map<String, dynamic>> docRef,
		Map<String, dynamic> base,
	) async {
		final merged = Map<String, dynamic>.from(base);
		// S'assurer des permissions pour lire les sous-collections (peut être requis par les règles)
		await _ensureUserAuthenticated();
		try {
			// Utilise le cache Firestore si disponible, puis synchronise serveur en arrière-plan
			final results = await Future.wait([
				docRef.collection('identification').doc('current').get(),
				docRef.collection('habitat').doc('current').get(),
				docRef.collection('alimentation').doc('current').get(),
				docRef.collection('reproduction').doc('current').get(),
				docRef.collection('protection').doc('current').get(),
			]);

			final identificationSnap = results[0];
			final habitatSnap = results[1];
			final alimentationSnap = results[2];
			final reproductionSnap = results[3];
			final protectionSnap = results[4];

			if (identificationSnap.exists) {
				final m = await _transformIdentificationAsync(_firestore, identificationSnap.data() as Map<String, dynamic>);
				if (m != null) merged['identification'] = m;
			}
			if (habitatSnap.exists) {
				final m = _transformHabitat(habitatSnap.data() as Map<String, dynamic>);
				if (m != null) merged['habitat'] = m;
			}
			if (alimentationSnap.exists) {
				final m = _transformAlimentation(alimentationSnap.data() as Map<String, dynamic>);
				if (m != null) merged['alimentation'] = m;
			}
			if (reproductionSnap.exists) {
				final m = _transformReproduction(reproductionSnap.data() as Map<String, dynamic>);
				if (m != null) merged['reproduction'] = m;
			}
			if (protectionSnap.exists) {
				final m = _transformProtection(protectionSnap.data() as Map<String, dynamic>);
				if (m != null) merged['protectionEtatActuel'] = m;
			}
		} catch (e) {
			if (kDebugMode) {
				debugPrint('⚠️ Fusion panels échouée: $e');
			}
		}
		return merged;
	}

	static Future<Map<String, dynamic>?> _transformIdentificationAsync(FirebaseFirestore db, Map<String, dynamic> p) async {
		if (p.isEmpty) return null;
        String? displayOrRange(Map<String, dynamic>? obj) {
			if (obj == null) return null;
			final display = (obj['display'] as String?)?.trim();
			if (display != null && display.isNotEmpty) return display;
			final min = obj['min'];
			final max = obj['max'];
			final unite = (obj['unite'] as String?) ?? '';
			if (min is num && max is num && unite.isNotEmpty) {
				return (min == max) ? '≈ ${max.toString()} $unite' : '${min.toString()}–${max.toString()} $unite';
			}
			return null;
		}
		final mesures = p['mesures'] as Map<String, dynamic>?;
        final poids = displayOrRange(mesures?['poids'] as Map<String, dynamic>?);
        final taille = displayOrRange(mesures?['taille'] as Map<String, dynamic>?);
        final envergure = displayOrRange(mesures?['envergure'] as Map<String, dynamic>?);

		String? differenciationText;
		final ressemblantes = (p['especesRessemblantes'] as List?)?.whereType<Map>()
			.map((e) => e as Map<String, dynamic>)
			.toList() ?? const [];
        if (ressemblantes.isNotEmpty) {
            // Résolution en parallèle pour réduire la latence globale
            final futures = <Future<String?>>[];
            final pairs = <Map<String, String>>[];
            for (final e in ressemblantes) {
                final sci = (e['nom'] as String?)?.trim();
                final se = (e['se_distingue_par'] as String?)?.trim();
                if (sci == null || sci.isEmpty || se == null || se.isEmpty) continue;
                pairs.add({'sci': sci, 'se': se});
                futures.add(_lookupFrenchNameByScientific(db, sci));
            }
            final results = await Future.wait(futures);
            final parts = <String>[];
            for (int i = 0; i < pairs.length; i++) {
                final label = (results[i] != null && results[i]!.isNotEmpty) ? results[i]! : pairs[i]['sci']!;
                parts.add('$label : ${pairs[i]['se']!}');
            }
            differenciationText = parts.isEmpty ? null : parts.join(' | ');
        }

		return {
			'classification': {
				'ordre': (p['classification'] as Map?)?.cast<String, dynamic>()['ordre'],
				'famille': (p['classification'] as Map?)?.cast<String, dynamic>()['famille'],
			},
			'morphologie': (p['morphologie'] as String?)?.trim(),
			'mesures': {
				'poids': poids,
				'taille': taille,
				'envergure': envergure,
			},
			'especesRessemblantes': {
				'exemples': [],
				'differenciation': differenciationText,
			},
		};
	}

	static Future<String?> _lookupFrenchNameByScientific(FirebaseFirestore db, String scientific) async {
		try {
			// Tenter d'abord dans fiches_oiseaux
			final q1 = await db.collection('fiches_oiseaux').where('nomScientifique', isEqualTo: scientific).limit(1).get();
			if (q1.docs.isNotEmpty) {
				final data = q1.docs.first.data();
				final fr = (data['nomFrancais'] as String?)?.trim();
				if (fr != null && fr.isNotEmpty) return fr;
			}
			// Sinon dans sons_oiseaux
			final q2 = await db.collection('sons_oiseaux').where('nomScientifique', isEqualTo: scientific).limit(1).get();
			if (q2.docs.isNotEmpty) {
				final data = q2.docs.first.data();
				final fr = (data['nomFrancais'] as String?)?.trim();
				if (fr != null && fr.isNotEmpty) return fr;
			}
		} catch (_) {}
		return null;
	}

	static Map<String, dynamic>? _transformHabitat(Map<String, dynamic> p) {
		if (p.isEmpty) return null;
		final type = (p['typeDeMilieu'] as String?)?.trim();
		return {
			// L'UI lit milieux → on y place le type de milieu comme première entrée
			'milieux': type != null && type.isNotEmpty ? <String>[type] : const <String>[],
			'description': type,
			'zonesObservation': (p['ouObserverFrance'] as String?)?.trim(),
			'migration': {
				'description': (p['migration'] as String?)?.trim(),
			},
		};
	}

	static Map<String, dynamic>? _transformAlimentation(Map<String, dynamic> p) {
		if (p.isEmpty) return null;
		final princ = (p['alimentationPrincipale'] is List)
			? List<String>.from((p['alimentationPrincipale'] as List).whereType<String>())
			: <String>[];
		return {
			'regimePrincipal': princ.isNotEmpty ? princ.first : null,
			'proiesPrincipales': princ,
			'techniquesChasse': <String>[],
			'description': (p['description'] as String?)?.trim(),
		};
	}

	static Map<String, dynamic>? _transformReproduction(Map<String, dynamic> p) {
		if (p.isEmpty) return null;
		final chips = (p['chips'] as Map?)?.cast<String, dynamic>();
		final months = (chips?['periodeMois'] is List)
			? List<String>.from((chips?['periodeMois'] as List).whereType<String>())
			: <String>[];
		String? debut;
		String? fin;
		if (months.isNotEmpty) {
			debut = months.first;
			fin = months.last;
		}
        String? formatRange(Map<String, dynamic>? r, String unite) {
			if (r == null) return null;
			final min = r['min'];
			final max = r['max'];
			if (min is num && max is num) {
				return (min == max) ? '≈ ${max.toString()} $unite' : '${min.toString()}–${max.toString()} $unite';
			}
			return null;
		}
        final nbOeufsTxt = formatRange(chips?['nbOeufsParPondee'] as Map<String, dynamic>?, '');
        final incubationTxt = formatRange(chips?['incubationJours'] as Map<String, dynamic>?, 'j');

		final etapes = (p['etapes'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
		final details = <String, String>{};
		String? read(String key) => (etapes[key] as String?)?.trim();
		// L'UI attend des clés normalisées:
		final parade = read('parade');
		if (parade != null && parade.isNotEmpty) details['paradeNuptiale'] = parade;
		final acc = read('accouplement');
		if (acc != null && acc.isNotEmpty) details['accouplement'] = acc;
		final nidif = read('nidification');
		if (nidif != null && nidif.isNotEmpty) {
			// Répartir l'info nid en trois entrées si possible
			details['nidification'] = nidif; // fallback texte global
			if (!details.containsKey('materiauxNid')) details['materiauxNid'] = nidif;
			if (!details.containsKey('emplacementNid')) details['emplacementNid'] = nidif;
		}
		final ponte = read('ponte');
		if (ponte != null && ponte.isNotEmpty) details['ponte'] = ponte;
		final incub = read('incubation');
		if (incub != null && incub.isNotEmpty) {
			details['incubation'] = incub;
			// Indice sur parents
			if (incub.toLowerCase().contains('parents')) {
				details['incubationParents'] = incub;
			}
		}
		final nourr = read('nourrissage');
		if (nourr != null && nourr.isNotEmpty) details['nourrissage'] = nourr;
		final envol = read('envol');
		if (envol != null && envol.isNotEmpty) details['envol'] = envol;

		return {
			'periode': {
				'debutMois': debut,
				'finMois': fin,
			},
			'nbOeufsParPondee': nbOeufsTxt,
			'incubationJours': incubationTxt,
			'details': details.isEmpty ? null : details,
		};
	}

	static Map<String, dynamic>? _transformProtection(Map<String, dynamic> p) {
		if (p.isEmpty) return null;
		final statutMonde = (p['statutMonde'] as Map?)?.cast<String, dynamic>() ?? const {};
		final iucn = (statutMonde['iucn'] as String?)?.trim();
		String? actionsText;
		if (p['actions'] is List) {
			final list = List<String>.from((p['actions'] as List).whereType<String>()).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
			if (list.isNotEmpty) actionsText = list.join(', ');
		} else if (p['actions'] is String) {
			actionsText = (p['actions'] as String).trim();
		}
		return {
			'description': (p['description'] as String?)?.trim(),
			'statutFrance': (p['statutFrance'] as String?)?.trim(),
			// Le modèle attend une chaîne: ne renvoyer que le code IUCN
			'statutMonde': iucn,
			// Le modèle attend une chaîne: concaténer les actions
			'actions': actionsText,
		};
	}

	/// Récupère une fiche oiseau par son ID
	static Future<FicheOiseau?> getFicheById(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFicheById: Impossible d\'assurer l\'authentification');
				}
				return null;
			}

			final docSnapshot = await _collection.doc(idOiseau).get();
			
			if (!docSnapshot.exists) {
				if (kDebugMode) {
					debugPrint('FicheOiseauService: Document non trouvé pour l\'ID $idOiseau');
				}
				return null;
			}

			final data = docSnapshot.data();
			if (data == null) {
				if (kDebugMode) {
					debugPrint('FicheOiseauService: Données nulles pour la fiche $idOiseau');
				}
				return null;
			}

			return FicheOiseau.fromFirestore(data);
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la récupération de la fiche $idOiseau: $e');
			}
			return null;
		}
	}

	/// Récupère une fiche par nom scientifique exact (ex: "Prunella modularis")
	static Future<FicheOiseau?> getFicheByNomScientifique(String nomScientifique) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFicheByNomScientifique: Impossible d\'assurer l\'authentification');
				}
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
			if (kDebugMode) {
				debugPrint('Erreur getFicheByNomScientifique($nomScientifique): $e');
			}
			return null;
		}
	}

	/// Écoute les changements d'une fiche oiseau en temps réel
	static Stream<FicheOiseau?> watchFicheById(String idOiseau) {
		return Stream.fromFuture(_ensureUserAuthenticated()).asyncExpand((_) {
			return _collection.doc(idOiseau).snapshots().asyncMap((docSnapshot) async {
			if (!docSnapshot.exists) return null;
			final data = docSnapshot.data();
			if (data == null) return null;
			final merged = await _buildMergedData(docSnapshot.reference, data);
			return FicheOiseau.fromFirestore(merged);
			});
		}).handleError((error) {
			if (kDebugMode) {
				debugPrint('Erreur watchFicheById: $error');
			}
			return null;
		});
	}

	/// Écoute les changements d'une fiche par nom scientifique exact
	static Stream<FicheOiseau?> watchFicheByNomScientifique(String nomScientifique) {
		// Les lectures publiques sont autorisées par les règles; pas d'auth stricte ici
		return Stream.fromFuture(_ensureUserAuthenticated()).asyncExpand((_) {
			return _collection
				.where('nomScientifique', isEqualTo: nomScientifique)
				.limit(1)
				.snapshots()
				.asyncMap((querySnapshot) async {
				if (querySnapshot.docs.isEmpty) return null;
				final doc = querySnapshot.docs.first;
				final merged = await _buildMergedData(doc.reference, doc.data());
				return FicheOiseau.fromFirestore(merged);
				});
		}).handleError((error) {
				if (kDebugMode) {
					debugPrint('Erreur watchFicheByNomScientifique($nomScientifique): $error');
				}
				return null;
			});
	}

	/// Écoute les changements d'une fiche par nom français exact
	static Stream<FicheOiseau?> watchFicheByNomFrancais(String nomFrancais) {
		final slug = _slugify(nomFrancais);
		return Stream.fromFuture(_ensureUserAuthenticated()).asyncExpand((_) {
			return _collection
				.where('nomFrancais', isEqualTo: nomFrancais)
				.limit(1)
				.snapshots()
				.asyncMap((querySnapshot) async {
					if (querySnapshot.docs.isNotEmpty) {
						final doc = querySnapshot.docs.first;
						final merged = await _buildMergedData(doc.reference, doc.data());
						return FicheOiseau.fromFirestore(merged);
					}
					// Fallback sur slug (kebab-case FR)
					try {
						final alt = await _collection.where('slug', isEqualTo: slug).limit(1).get();
						if (alt.docs.isNotEmpty) {
							final doc = alt.docs.first;
							final merged = await _buildMergedData(doc.reference, doc.data());
							return FicheOiseau.fromFirestore(merged);
						}
					} catch (_) {}
					return null;
				});
		}).handleError((error) {
				if (kDebugMode) {
					debugPrint('Erreur watchFicheByNomFrancais($nomFrancais): $error');
				}
				return null;
			});
	}

	/// Écoute par appId (id interne app: genus_species)
	static Stream<FicheOiseau?> watchFicheByAppId(String appId) {
		return Stream.fromFuture(_ensureUserAuthenticated()).asyncExpand((_) {
			return _collection
				.where('appId', isEqualTo: appId)
				.limit(1)
				.snapshots()
				.asyncMap((querySnapshot) async {
				if (querySnapshot.docs.isEmpty) return null;
				final doc = querySnapshot.docs.first;
				final merged = await _buildMergedData(doc.reference, doc.data());
				return FicheOiseau.fromFirestore(merged);
				});
		}).handleError((error) {
				if (kDebugMode) {
					debugPrint('Erreur watchFicheByAppId($appId): $error');
				}
				return null;
			});
		}
	/// Lecture directe par docId (recommandé si docId == slug FR)
	static Stream<FicheOiseau?> watchFicheByDocId(String docId) {
		return Stream.fromFuture(_ensureUserAuthenticated()).asyncExpand((_) {
			return _collection.doc(docId).snapshots().asyncMap((snap) async {
				if (!snap.exists) return null;
				final data = snap.data();
				if (data == null) return null;
				final merged = await _buildMergedData(snap.reference, data);
				return FicheOiseau.fromFirestore(merged);
			});
		}).handleError((error) {
			if (kDebugMode) {
				debugPrint('Erreur watchFicheByDocId($docId): $error');
			}

				return null;
			});
	}

  // Suppression du watcher slug – le fallback par nom FR suffit désormais

	/// Récupère toutes les fiches oiseaux
	static Future<List<FicheOiseau>> getAllFiches() async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getAllFiches: Impossible d\'assurer l\'authentification');
				}
				return [];
			}

			final querySnapshot = await _collection.get();
			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data();
					final fiche = FicheOiseau.fromFirestore(data);
					fiches.add(fiche);
				} catch (e) {
					if (kDebugMode) {
						debugPrint('Erreur lors du parsing de la fiche ${doc.id}: $e');
					}
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la récupération de toutes les fiches: $e');
			}
			return [];
		}
	}

	/// Récupère les fiches oiseaux avec pagination
	static Future<List<FicheOiseau>> getFichesPaginated({
		required int limit,
		DocumentSnapshot<Map<String, dynamic>>? startAfter,
	}) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFichesPaginated: Impossible d\'assurer l\'authentification');
				}
				return [];
			}

			Query<Map<String, dynamic>> query = _collection.orderBy('nomFrancais').limit(limit);
			
			if (startAfter != null) {
				query = query.startAfterDocument(startAfter);
			}

			final querySnapshot = await query.get();
			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data();
					final fiche = FicheOiseau.fromFirestore(data);
					fiches.add(fiche);
				} catch (e) {
					if (kDebugMode) {
						debugPrint('Erreur lors du parsing de la fiche ${doc.id}: $e');
					}
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la récupération des fiches paginées: $e');
			}
			return [];
		}
	}

	/// Recherche des fiches oiseaux par nom
	static Future<List<FicheOiseau>> searchFichesByName(String searchTerm) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur searchFichesByName: Impossible d\'assurer l\'authentification');
				}
				return [];
			}

			if (searchTerm.isEmpty) {
				return [];
			}

			// Recherche insensible à la casse
			final searchTermLower = searchTerm.toLowerCase();
			
			final querySnapshot = await _collection
					.where('nomFrancais', isGreaterThanOrEqualTo: searchTermLower)
					.where('nomFrancais', isLessThan: '$searchTermLower\uf8ff')
					.limit(20)
					.get();

			final fiches = <FicheOiseau>[];

			for (final doc in querySnapshot.docs) {
				try {
					final data = doc.data();
					final fiche = FicheOiseau.fromFirestore(data);
					
					// Filtre supplémentaire côté client pour plus de précision
					if (fiche.nomFrancais.toLowerCase().contains(searchTermLower) ||
							fiche.nomScientifique.toLowerCase().contains(searchTermLower)) {
						fiches.add(fiche);
					}
				} catch (e) {
					if (kDebugMode) {
						debugPrint('Erreur lors du parsing de la fiche ${doc.id}: $e');
					}
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la recherche des fiches: $e');
			}
			return [];
		}
	}

	/// Recherche des fiches oiseaux par habitat
	static Future<List<FicheOiseau>> getFichesByHabitat(String habitat) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFichesByHabitat: Impossible d\'assurer l\'authentification');
				}
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
					final data = doc.data();
					final fiche = FicheOiseau.fromFirestore(data);
					fiches.add(fiche);
				} catch (e) {
					if (kDebugMode) {
						debugPrint('Erreur lors du parsing de la fiche ${doc.id}: $e');
					}
					// Continue avec les autres fiches
				}
			}

			return fiches;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la récupération des fiches par habitat: $e');
			}
			return [];
		}
	}

	/// Crée une nouvelle fiche oiseau
	static Future<bool> createFiche(FicheOiseau fiche) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur createFiche: Impossible d\'assurer l\'authentification');
				}
				return false;
			}

			await _collection.doc(fiche.idOiseau).set(fiche.toFirestore());
			if (kDebugMode) {
				debugPrint('Fiche oiseau créée avec succès: ${fiche.idOiseau}');
			}
			return true;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la création de la fiche ${fiche.idOiseau}: $e');
			}
			return false;
		}
	}

	/// Met à jour une fiche oiseau existante
	static Future<bool> updateFiche(FicheOiseau fiche) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur updateFiche: Impossible d\'assurer l\'authentification');
				}
				return false;
			}

			await _collection.doc(fiche.idOiseau).update(fiche.toFirestore());
			if (kDebugMode) {
				debugPrint('Fiche oiseau mise à jour avec succès: ${fiche.idOiseau}');
			}
			return true;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la mise à jour de la fiche ${fiche.idOiseau}: $e');
			}
			return false;
		}
	}

	/// Supprime une fiche oiseau
	static Future<bool> deleteFiche(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur deleteFiche: Impossible d\'assurer l\'authentification');
				}
				return false;
			}

			await _collection.doc(idOiseau).delete();
			if (kDebugMode) {
				debugPrint('Fiche oiseau supprimée avec succès: $idOiseau');
			}
			return true;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la suppression de la fiche $idOiseau: $e');
			}
			return false;
		}
	}

	/// Crée ou met à jour une fiche oiseau (upsert)
	static Future<bool> upsertFiche(FicheOiseau fiche) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur upsertFiche: Impossible d\'assurer l\'authentification');
				}
				return false;
			}

			await _collection.doc(fiche.idOiseau).set(fiche.toFirestore(), SetOptions(merge: true));
			if (kDebugMode) {
				debugPrint('Fiche oiseau upsertée avec succès: ${fiche.idOiseau}');
			}
			return true;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de l\'upsert de la fiche ${fiche.idOiseau}: $e');
			}
			return false;
		}
	}

	/// Importe plusieurs fiches en lot
	static Future<bool> importFichesBatch(List<FicheOiseau> fiches) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur importFichesBatch: Impossible d\'assurer l\'authentification');
				}
				return false;
			}

			if (fiches.isEmpty) {
				if (kDebugMode) {
					debugPrint('Aucune fiche à importer');
				}
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
					if (kDebugMode) {
						debugPrint('Lot ${(i ~/ batchSize) + 1} importé avec succès: ${endIndex - i} fiches');
					}
				} catch (e) {
					errorCount += endIndex - i;
					if (kDebugMode) {
						debugPrint('Erreur lors de l\'import du lot ${(i ~/ batchSize) + 1}: $e');
					}
				}
			}

			if (kDebugMode) {
				debugPrint('Import terminé: $successCount succès, $errorCount erreurs');
			}
			return errorCount == 0;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de l\'import en lot: $e');
			}
			return false;
		}
	}

	/// Compte le nombre total de fiches
	static Future<int> getFichesCount() async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFichesCount: Impossible d\'assurer l\'authentification');
				}
				return 0;
			}

			final querySnapshot = await _collection.count().get();
			return querySnapshot.count ?? 0;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors du comptage des fiches: $e');
			}
			return 0;
		}
	}

	/// Vérifie si une fiche existe
	static Future<bool> ficheExists(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur ficheExists: Impossible d\'assurer l\'authentification');
				}
				return false;
			}

			final docSnapshot = await _collection.doc(idOiseau).get();
			return docSnapshot.exists;
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors de la vérification de l\'existence de la fiche $idOiseau: $e');
			}
			return false;
		}
	}

	/// Vide le cache Firestore pour forcer le rechargement
	static Future<void> clearFirestoreCache() async {
		try {
			await _firestore.clearPersistence();
			if (kDebugMode) {
				debugPrint('🧹 Cache Firestore vidé avec succès');
			}
		} catch (e) {
			if (kDebugMode) {
				debugPrint('⚠️ Impossible de vider le cache Firestore: $e');
			}
		}
	}

	/// Force le rechargement d'une fiche depuis le serveur (ignore le cache)
	static Future<FicheOiseau?> getFicheFromServer(String idOiseau) async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFicheFromServer: Impossible d\'assurer l\'authentification');
				}
				return null;
			}

			// Utiliser get(source: Source.server) pour forcer la lecture depuis le serveur
			final docSnapshot = await _collection.doc(idOiseau).get(const GetOptions(source: Source.server));
			
			if (!docSnapshot.exists) {
				if (kDebugMode) {
					debugPrint('FicheOiseauService: Document non trouvé sur le serveur pour l\'ID $idOiseau');
				}
				return null;
			}

			final data = docSnapshot.data();
			if (data == null) {
				if (kDebugMode) {
					debugPrint('FicheOiseauService: Données nulles pour la fiche $idOiseau depuis le serveur');
				}
				return null;
			}

			if (kDebugMode) {
				debugPrint('🔄 Fiche $idOiseau rechargée depuis le serveur');
			}

			return FicheOiseau.fromFirestore(data);
		} catch (e) {
			if (kDebugMode) {
				debugPrint('Erreur lors du rechargement de la fiche $idOiseau depuis le serveur: $e');
			}
			return null;
		}
	}

	/// Récupère les statistiques des fiches
	static Future<Map<String, dynamic>> getFichesStats() async {
		try {
			if (!await _ensureUserAuthenticated()) {
				if (kDebugMode) {
					debugPrint('Erreur getFichesStats: Impossible d\'assurer l\'authentification');
				}
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
			if (kDebugMode) {
				debugPrint('Erreur lors de la récupération des statistiques: $e');
			}
			return {};
		}
	}
}
