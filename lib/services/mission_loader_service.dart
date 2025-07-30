import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/mission.dart';
import 'package:flutter/foundation.dart';

class MissionLoaderService {
  static const String _csvPath = 'assets/Missionhome/missions_structure.csv';
  
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
    final int niveau = _parseIntField(rowData, 'niveau', 'Niveau');
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
  
  /// Méthode utilitaire pour obtenir les missions d'un biome spécifique
  static Future<List<Mission>> loadMissionsForBiome(String biomeName) async {
    final Map<String, List<Mission>> allMissions = await loadMissionsFromCsv();
    return allMissions[biomeName] ?? [];
  }
} 