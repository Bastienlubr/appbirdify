import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mission.dart';
import 'package:flutter/foundation.dart';
import 'mission_persistence_service.dart';
import 'mission_progression_init_service.dart';

/// Modèle pour la progression d'un utilisateur sur une mission
class ProgressionMission {
  final int etoiles;
  final int meilleurScore;
  final int tentatives;
  final bool deverrouille;
  final DateTime? dernierePartieLe;

  ProgressionMission({
    required this.etoiles,
    required this.meilleurScore,
    required this.tentatives,
    required this.deverrouille,
    this.dernierePartieLe,
  });

  factory ProgressionMission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProgressionMission(
      etoiles: data['etoiles'] ?? 0,
      meilleurScore: data['meilleurScore'] ?? 0,
      tentatives: data['tentatives'] ?? 0,
      deverrouille: data['deverrouille'] ?? false,
      dernierePartieLe: data['dernierePartieLe']?.toDate(),
    );
  }

  factory ProgressionMission.defaultProgression() {
    return ProgressionMission(
      etoiles: 0,
      meilleurScore: 0,
      tentatives: 0,
      deverrouille: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'etoiles': etoiles,
      'meilleurScore': meilleurScore,
      'tentatives': tentatives,
      'deverrouille': deverrouille,
      if (dernierePartieLe != null) 'dernierePartieLe': dernierePartieLe,
    };
  }
}

class MissionLoaderService {
  static const String _csvPath = 'assets/Missionhome/missions_structure.csv';
  static const int _batchSize = 10; // Taille des lots pour Firestore
  
  /// Charge les missions depuis le CSV et fusionne avec la progression Firestore
  static Future<Map<String, List<Mission>>> loadMissionsWithProgression(
    String uid, {
    List<String>? missionIds,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Charger les missions depuis le CSV
      final Map<String, List<Mission>> missionsByBiome = await loadMissionsFromCsv();
      
      // Si des IDs spécifiques sont demandés, filtrer les missions
      List<String> idsToLoad = missionIds ?? [];
      if (idsToLoad.isEmpty) {
        // Récupérer tous les IDs de missions
        idsToLoad = missionsByBiome.values
            .expand((missions) => missions)
            .map((mission) => mission.id)
            .toList();
      }
      
      // Charger la progression en batch depuis Firestore
      final Map<String, ProgressionMission> progressionMap = 
          await _loadProgressionBatch(uid, idsToLoad);
      
      // Fusionner les missions avec leur progression
      final Map<String, List<Mission>> missionsWithProgression = {};
      
      missionsByBiome.forEach((biome, missions) {
        final List<Mission> missionsFusionnees = missions.map((mission) {
          final bool hasProgression = progressionMap.containsKey(mission.id);
          final progression = hasProgression
              ? progressionMap[mission.id]!
              : ProgressionMission.defaultProgression();

          // Si aucune progression n'existe encore, respecter l'état initial du CSV (ex: première mission déverrouillée)
          final String resolvedStatus = hasProgression
              ? (progression.deverrouille ? 'available' : 'locked')
              : mission.status;

          return mission.copyWith(
            lastStarsEarned: progression.etoiles,
            status: resolvedStatus,
          );
        }).toList();
        
        missionsWithProgression[biome] = missionsFusionnees;
      });
      
      final duration = stopwatch.elapsedMilliseconds;
      debugPrint('🚀 Missions chargées en $duration ms (${idsToLoad.length} missions, ${progressionMap.length} progressions)');
      
      return missionsWithProgression;
      
    } catch (e) {
      final duration = stopwatch.elapsedMilliseconds;
      debugPrint('❌ Erreur lors du chargement des missions avec progression ($duration ms): $e');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Charge la progression des missions en batch depuis Firestore
  static Future<Map<String, ProgressionMission>> _loadProgressionBatch(
    String uid, 
    List<String> missionIds,
  ) async {
    final stopwatch = Stopwatch()..start();
    final Map<String, ProgressionMission> progressionMap = {};
    
    try {
      // Diviser en lots de 10 (limite Firestore)
      final List<List<String>> batches = _chunkList(missionIds, _batchSize);
      int totalReads = 0;
      
      for (int i = 0; i < batches.length; i++) {
        final batch = batches[i];
        final batchStopwatch = Stopwatch()..start();
        
        // Requête Firestore avec whereIn
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(uid)
            .collection('progression_missions')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        // Traiter les résultats
        for (final doc in snapshot.docs) {
          final progression = ProgressionMission.fromFirestore(doc);
          progressionMap[doc.id] = progression;
        }
        
        totalReads += snapshot.docs.length;
        final batchDuration = batchStopwatch.elapsedMilliseconds;
        
        debugPrint('📦 Lot ${i + 1}/${batches.length}: ${batch.length} missions en $batchDuration ms (${snapshot.docs.length} trouvées)');
        
        batchStopwatch.stop();
      }
      
      final totalDuration = stopwatch.elapsedMilliseconds;
      debugPrint('🔥 Progression chargée en $totalDuration ms: $totalReads lectures sur ${missionIds.length} missions demandées');
      
      return progressionMap;
      
    } catch (e) {
      final duration = stopwatch.elapsedMilliseconds;
      debugPrint('❌ Erreur lors du chargement batch de la progression ($duration ms): $e');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Divise une liste en lots de taille spécifiée
  static List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final List<List<T>> chunks = [];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
  
  /// Charge toutes les missions depuis le fichier CSV et les organise par biome
  static Future<Map<String, List<Mission>>> loadMissionsFromCsv() async {
    try {
      // Lire le fichier CSV
      final String csvData = await rootBundle.loadString(_csvPath);
      
      // Parser le CSV
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvData);
      
      // Vérifier qu'il y a au moins une ligne d'en-tête et des données
      if (csvTable.length < 2) {
        throw Exception('Le fichier CSV est vide ou ne contient que l\'en-tête');
      }
      
      // Extraire les en-têtes (première ligne)
      final List<String> headers = csvTable[0].map((e) => e.toString()).toList();
      
      // Map pour organiser les missions par biome
      final Map<String, List<Mission>> missionsByBiome = {};
      
      // Traiter chaque ligne de données (à partir de la ligne 1)
      for (int i = 1; i < csvTable.length; i++) {
        final List<dynamic> row = csvTable[i];
        
        try {
          final Mission mission = _parseMissionFromRow(row, headers);
          
          // Ajouter la mission au biome correspondant
          final String biome = mission.milieu;
          if (!missionsByBiome.containsKey(biome)) {
            missionsByBiome[biome] = [];
          }
          missionsByBiome[biome]!.add(mission);
          
        } catch (e) {
          // Logger l'erreur mais continuer avec les autres missions
          debugPrint('⚠️ Erreur lors du parsing de la ligne $i: $e');
          continue;
        }
      }
      
      return missionsByBiome;
      
    } catch (e) {
      throw Exception('Erreur lors du chargement des missions: $e');
    }
  }
  
  /// Parse une ligne CSV en objet Mission
  static Mission _parseMissionFromRow(List<dynamic> row, List<String> headers) {
    // Créer un Map pour faciliter l'accès aux valeurs par nom de colonne
    final Map<String, String> rowData = {};
    for (int i = 0; i < headers.length && i < row.length; i++) {
      rowData[headers[i]] = row[i]?.toString() ?? '';
    }
    
    // Extraire et valider les données requises
    final String id = _getRequiredField(rowData, 'id_mission', 'ID de mission');
    final String titre = _getRequiredField(rowData, 'titre', 'Titre');
    final String description = _getRequiredField(rowData, 'description', 'Description');
    final String biome = _getRequiredField(rowData, 'biome', 'Biome');
    // Déterminer l'index/niveau de la mission
    int niveau = _parseIntField(rowData, 'niveau', 'Niveau');
    if (niveau <= 0) {
      // Fallback: extraire le numéro depuis l'ID de mission (ex: U01 -> 1)
      // Cela permet de fonctionner même si la colonne 'niveau' est absente du CSV
      final String idRaw = rowData['id_mission'] ?? '';
      final match = RegExp(r"(\d+)").firstMatch(idRaw);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0) {
          niveau = parsed;
        }
      } else {
        // Par défaut, si impossible à déduire, considérer comme première mission
        niveau = 1;
      }
    }
    final bool deverrouillee = _parseBoolField(rowData, 'deverrouillee', 'Déverrouillée');
    final int etoiles = _parseIntField(rowData, 'etoiles', 'Étoiles');
    final String? csvUrl = rowData['csv_url'];
    final String? imageUrl = rowData['image_url'];
    
    // Corriger le chemin de l'image si nécessaire
    String? correctedImageUrl = imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('assets/')) {
      correctedImageUrl = 'assets/$imageUrl';
    }
    
    // Créer l'objet Mission
    return Mission(
      id: id,
      milieu: biome,
      index: niveau,
      status: deverrouillee ? 'available' : 'locked',
      questions: [], // Les questions seront chargées séparément depuis le fichier CSV spécifique
      title: titre,
      csvFile: csvUrl,
      titreMission: titre,
      sousTitre: description,
      iconUrl: correctedImageUrl,
      lastStarsEarned: etoiles,
    );
  }
  
  /// Récupère un champ requis et lève une exception s'il est manquant
  static String _getRequiredField(Map<String, String> rowData, String fieldName, String displayName) {
    final value = rowData[fieldName];
    if (value == null || value.trim().isEmpty) {
      throw Exception('Champ requis manquant: $displayName ($fieldName)');
    }
    return value.trim();
  }
  
  /// Parse un champ entier avec gestion d'erreur
  static int _parseIntField(Map<String, String> rowData, String fieldName, String displayName) {
    final value = rowData[fieldName];
    if (value == null || value.trim().isEmpty) {
      return 0; // Valeur par défaut
    }
    
    try {
      return int.parse(value.trim());
    } catch (e) {
      debugPrint('⚠️ Erreur de parsing pour $displayName ($fieldName): "$value" - utilisation de 0');
      return 0;
    }
  }
  
  /// Parse un champ booléen avec gestion d'erreur
  static bool _parseBoolField(Map<String, String> rowData, String fieldName, String displayName) {
    final value = rowData[fieldName];
    if (value == null || value.trim().isEmpty) {
      return false; // Valeur par défaut
    }
    
    final lowerValue = value.trim().toLowerCase();
    return lowerValue == 'true' || lowerValue == '1' || lowerValue == 'yes';
  }
  
  /// Méthode utilitaire pour obtenir les missions d'un biome spécifique avec persistance
  static Future<List<Mission>> loadMissionsForBiome(String biomeName) async {
    try {
      final Map<String, List<Mission>> allMissions = await loadMissionsFromCsv();
      final List<Mission> biomeMissions = allMissions[biomeName] ?? [];
      
      // Récupérer les missions consultées
      final List<String> consultedMissions = await MissionPersistenceService.getConsultedMissions();
      
      // Mettre à jour le statut hasBeenSeen pour chaque mission
      final List<Mission> updatedMissions = biomeMissions.map((mission) {
        final bool hasBeenConsulted = consultedMissions.contains(mission.id);
        return mission.copyWith(hasBeenSeen: hasBeenConsulted);
      }).toList();
      
      // Trier les missions par niveau
      updatedMissions.sort((a, b) => a.index.compareTo(b.index));
      
      return updatedMissions;
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des missions pour le biome $biomeName: $e');
      return [];
    }
  }
  
  /// Méthode utilitaire pour obtenir les missions d'un biome avec progression Firestore
  static Future<List<Mission>> loadMissionsForBiomeWithProgression(
    String uid, 
    String biomeName,
  ) async {
    try {
      // D'abord, charger les missions depuis le CSV
      final Map<String, List<Mission>> allMissions = await loadMissionsFromCsv();
      final List<Mission> biomeMissions = allMissions[biomeName] ?? [];
      
      if (biomeMissions.isEmpty) {
        debugPrint('⚠️ Aucune mission trouvée pour le biome $biomeName');
        return [];
      }
      
      // Ensuite, essayer de charger la progression depuis Firestore
      try {
        final Map<String, ProgressionMission> progressionMap = 
            await _loadProgressionBatch(uid, biomeMissions.map((m) => m.id).toList());
        
        // Fusionner les missions avec leur progression et gérer le déverrouillage
        final List<Mission> missionsWithProgression = [];
        
        for (final mission in biomeMissions) {
          final bool hasProgression = progressionMap.containsKey(mission.id);
          final progression = hasProgression
              ? progressionMap[mission.id]!
              : ProgressionMission.defaultProgression();

          // Logique de déverrouillage intelligente :
          // - Si c'est la première mission (index 1), elle est toujours déverrouillée
          // - Sinon, vérifier si la mission précédente a au moins 2 étoiles
          String resolvedStatus;
          bool shouldUnlock = false;
          
          if (mission.index == 1) {
            resolvedStatus = 'available'; // Première mission toujours déverrouillée
          } else {
            // Vérifier si la mission précédente a au moins 2 étoiles
            final previousMission = biomeMissions.where((m) => m.index == mission.index - 1).firstOrNull;
            if (previousMission != null) {
              final previousProgression = progressionMap[previousMission.id];
              final previousStars = previousProgression?.etoiles ?? 0;
              
              if (previousStars >= 2) {
                resolvedStatus = 'available'; // Mission déverrouillée car précédente a 2+ étoiles
                shouldUnlock = true;
              } else {
                resolvedStatus = 'locked'; // Mission verrouillée car précédente n'a pas 2 étoiles
              }
            } else {
              resolvedStatus = 'locked'; // Pas de mission précédente trouvée
            }
          }

          final updatedMission = mission.copyWith(
            lastStarsEarned: progression.etoiles,
            status: resolvedStatus,
          );
          
          // Si la mission doit être déverrouillée, le faire maintenant
          if (shouldUnlock && !hasProgression) {
            try {
              await MissionProgressionInitService.unlockMission(
                mission.id,
                biome: biomeName,
                index: mission.index,
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ Erreur lors du déverrouillage automatique de ${mission.id}: $e');
              }
            }
          }
          
          missionsWithProgression.add(updatedMission);
        }
        
        // Récupérer les missions consultées et mettre à jour hasBeenSeen
        final List<String> consultedMissions = await MissionPersistenceService.getConsultedMissions();
        final List<Mission> finalMissions = missionsWithProgression.map((mission) {
          final bool hasBeenConsulted = consultedMissions.contains(mission.id);
          return mission.copyWith(hasBeenSeen: hasBeenConsulted);
        }).toList();
        
        // Trier les missions par niveau
        finalMissions.sort((a, b) => a.index.compareTo(b.index));
        
        debugPrint('✅ Missions chargées avec progression pour $biomeName: ${finalMissions.length} missions');
        return finalMissions;
        
      } catch (firestoreError) {
        // Si Firestore échoue, utiliser les missions du CSV avec statut par défaut
        debugPrint('⚠️ Erreur Firestore, utilisation du CSV: $firestoreError');
        return biomeMissions;
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des missions avec progression pour le biome $biomeName: $e');
      return [];
    }
  }
} 