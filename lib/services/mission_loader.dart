import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/mission.dart';

class MissionLoader {
  /// Charge toutes les missions depuis les fichiers CSV dans assets/Missionhome/question Mission/
  static Future<List<Mission>> loadAllMissions() async {
    try {
      if (kDebugMode) debugPrint('🔄 Chargement de toutes les missions...');
      
      // Liste des fichiers CSV disponibles
      final List<String> csvFiles = [
        'U01 - template_mission_quiz.csv',
        'U02 - template_mission_quiz.csv',
        'U03 - template_mission_quiz.csv',
        'U04 - template_mission_quiz.csv',
        'F01 - template_mission_quiz.csv',
        'F02 - template_mission_quiz.csv',
      ];
      
      final List<Mission> allMissions = [];
      
      for (final String csvFile in csvFiles) {
        try {
          final Mission? mission = await _loadMissionFromCsv(csvFile);
          if (mission != null) {
            allMissions.add(mission);
            if (kDebugMode) debugPrint('✅ Mission chargée: ${mission.id} - ${mission.titreMission}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ Erreur lors du chargement de $csvFile: $e');
        }
      }
      
      if (kDebugMode) debugPrint('🎯 Total des missions chargées: ${allMissions.length}');
      return allMissions;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement de toutes les missions: $e');
      return [];
    }
  }
  
  /// Charge uniquement les missions d'un milieu donné
  static Future<List<Mission>> loadMissionsForMilieu(String biome) async {
    try {
      if (kDebugMode) debugPrint('🔄 Chargement des missions pour le milieu: $biome');
      
      final List<Mission> allMissions = await loadAllMissions();
      final List<Mission> filteredMissions = allMissions
          .where((mission) => mission.milieu.toLowerCase() == biome.toLowerCase())
          .toList();
      
      if (kDebugMode) debugPrint('🎯 Missions trouvées pour $biome: ${filteredMissions.length}');
      return filteredMissions;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des missions pour $biome: $e');
      return [];
    }
  }
  
  /// Charge une mission depuis un fichier CSV spécifique
  static Future<Mission?> _loadMissionFromCsv(String csvFileName) async {
    try {
      // Charger le fichier CSV depuis les assets
      final String csvContent = await rootBundle.loadString('assets/Missionhome/question Mission/$csvFileName');
      
      // Diviser le contenu en lignes
      final List<String> lines = csvContent.split('\n');
      
      if (lines.isEmpty) {
        if (kDebugMode) debugPrint('❌ Fichier CSV vide: $csvFileName');
        return null;
      }
      
      // Analyser l'en-tête pour trouver les index des colonnes
      final String header = lines[0];
      final List<String> headers = header.split(',');
      
      // Trouver les index des colonnes
      final Map<String, int> columnIndexes = _findColumnIndexes(headers);
      
      if (columnIndexes['id_mission'] == -1) {
        if (kDebugMode) debugPrint('❌ Colonne id_mission non trouvée dans: $csvFileName');
        return null;
      }
      
      // Extraire les données de la première ligne de données
      if (lines.length > 1) {
        final String firstDataLine = lines[1];
        final List<String> values = firstDataLine.split(',');
        
        // Extraire les informations de base de la mission
        final String id = _getValue(values, columnIndexes['id_mission']!, '');
        final String milieu = _getValue(values, columnIndexes['biome']!, '');
        final String titreMission = _getValue(values, columnIndexes['titre_mission']!, '');
        final String sousTitre = _getValue(values, columnIndexes['sous_titre']!, '');
        final String iconUrl = _getValue(values, columnIndexes['icon']!, '');
        
        // Construire la liste des questions
        final List<Map<String, dynamic>> questions = [];
        for (int i = 1; i < lines.length; i++) {
          final String line = lines[i];
          if (line.trim().isEmpty) continue;
          
          final List<String> lineValues = line.split(',');
          if (lineValues.length < 3) continue;
          
          final String questionId = _getValue(lineValues, columnIndexes['id_mission']!, '');
          final String questionNum = _getValue(lineValues, columnIndexes['num_question']!, '');
          final String bonneReponse = _getValue(lineValues, columnIndexes['bonne_reponse']!, '');
          final String urlBonneReponse = _getValue(lineValues, columnIndexes['URL_bonne_reponse']!, '');
          final String mauvaiseReponse = _getValue(lineValues, columnIndexes['mauvaise_reponse']!, '');
          
          if (questionId.isNotEmpty && bonneReponse.isNotEmpty) {
            questions.add({
              'id': questionId,
              'num_question': questionNum,
              'bonne_reponse': bonneReponse,
              'URL_bonne_reponse': urlBonneReponse,
              'mauvaise_reponse': mauvaiseReponse,
            });
          }
        }
        
        // Créer l'objet Mission
        final Mission mission = Mission(
          id: id,
          milieu: milieu,
          index: _extractIndexFromId(id),
          status: 'available', // Par défaut disponible
          questions: questions,
          csvFile: csvFileName,
          titreMission: titreMission.isNotEmpty ? titreMission : 'Mission $id',
          sousTitre: sousTitre,
          iconUrl: iconUrl,
        );
        
        return mission;
      }
      
      if (kDebugMode) debugPrint('❌ Aucune donnée trouvée dans: $csvFileName');
      return null;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement de $csvFileName: $e');
      return null;
    }
  }
  
  /// Trouve les index des colonnes dans l'en-tête CSV
  static Map<String, int> _findColumnIndexes(List<String> headers) {
    final Map<String, int> indexes = {
      'id_mission': -1,
      'biome': -1,
      'num_question': -1,
      'titre_mission': -1,
      'sous_titre': -1,
      'icon': -1,
      'bonne_reponse': -1,
      'URL_bonne_reponse': -1,
      'mauvaise_reponse': -1,
    };
    
    for (int i = 0; i < headers.length; i++) {
      final String header = headers[i].trim().toLowerCase();
      
      if (header == 'id_mission') {
        indexes['id_mission'] = i;
      } else if (header == 'biome') {
        indexes['biome'] = i;
      } else if (header == 'num_question') {
        indexes['num_question'] = i;
      } else if (header == 'titre_mission') {
        indexes['titre_mission'] = i;
      } else if (header == 'sous_titre') {
        indexes['sous_titre'] = i;
      } else if (header == 'icon') {
        indexes['icon'] = i;
      } else if (header == 'bonne_reponse') {
        indexes['bonne_reponse'] = i;
      } else if (header == 'url_bonne_reponse') {
        indexes['URL_bonne_reponse'] = i;
      } else if (header == 'mauvaise_reponse') {
        indexes['mauvaise_reponse'] = i;
      }
    }
    
    return indexes;
  }
  
  /// Extrait une valeur de la liste en gérant les index hors limites
  static String _getValue(List<String> values, int index, String defaultValue) {
    if (index >= 0 && index < values.length) {
      return values[index].trim();
    }
    return defaultValue;
  }
  
  /// Extrait l'index numérique de l'ID de mission (ex: "U01" -> 1)
  static int _extractIndexFromId(String id) {
    try {
      // Extraire les chiffres de l'ID (ex: "U01" -> "01" -> 1)
      final String numbers = id.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(numbers) ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Charge le titre, le sous-titre et l'icône d'une mission depuis son fichier CSV
  /// 
  /// [csvFileName] : Nom du fichier CSV (ex: "U01 - template_mission_quiz.csv")
  /// Retourne un Map avec 'titreMission', 'sousTitre' et 'iconUrl' ou null si non trouvé
  static Future<Map<String, String>?> loadMissionTitles(String csvFileName) async {
    try {
      // Charger le fichier CSV depuis les assets
      final String csvContent = await rootBundle.loadString('assets/Missionhome/$csvFileName');
      
      // Diviser le contenu en lignes
      final List<String> lines = csvContent.split('\n');
      
      if (lines.isEmpty) {
        if (kDebugMode) debugPrint('❌ Fichier CSV vide: $csvFileName');
        return null;
      }
      
      // Analyser l'en-tête pour trouver les index des colonnes
      final String header = lines[0];
      final List<String> headers = header.split(',');
      
      // Chercher l'index de la colonne titre_mission
      int titreMissionIndex = -1;
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].trim() == 'titre_mission') {
          titreMissionIndex = i;
          break;
        }
      }
      
      // Chercher l'index de la colonne sous_titre
      int sousTitreIndex = -1;
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].trim() == 'sous_titre') {
          sousTitreIndex = i;
          break;
        }
      }
      
      // Chercher l'index de la colonne icon (insensible à la casse)
      int iconIndex = -1;
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].trim().toLowerCase() == 'icon') {
          iconIndex = i;
          break;
        }
      }
      
      if (titreMissionIndex == -1) {
        if (kDebugMode) debugPrint('❌ Colonne titre_mission non trouvée dans: $csvFileName');
        return null;
      }
      
      // Prendre la première ligne de données (ligne 1) pour obtenir les titres
      if (lines.length > 1) {
        final String firstDataLine = lines[1];
        final List<String> values = firstDataLine.split(',');
        
        String titreMission = '';
        String sousTitre = '';
        String iconUrl = '';
        
        if (values.length > titreMissionIndex) {
          titreMission = values[titreMissionIndex].trim();
        }
        
        if (sousTitreIndex != -1 && values.length > sousTitreIndex) {
          sousTitre = values[sousTitreIndex].trim();
        }
        
        if (iconIndex != -1 && values.length > iconIndex) {
          iconUrl = values[iconIndex].trim();
        }
        
        if (kDebugMode) debugPrint('✅ Titres et icône chargés pour $csvFileName: titre="$titreMission", sous-titre="$sousTitre", icône="$iconUrl"');
        return {
          'titreMission': titreMission,
          'sousTitre': sousTitre,
          'iconUrl': iconUrl,
        };
      }
      
      if (kDebugMode) debugPrint('❌ Aucune donnée trouvée dans: $csvFileName');
      return null;
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement du sous-titre pour $csvFileName: $e');
      return null;
    }
  }
  
  /// Charge les titres, sous-titres et icônes pour une liste de missions
  /// 
  /// [missions] : Liste des missions à mettre à jour
  /// Retourne la liste des missions avec les titres chargés
  static Future<List<Map<String, dynamic>>> loadMissionsWithTitles(List<Map<String, dynamic>> missions) async {
    final List<Map<String, dynamic>> updatedMissions = [];
    
    for (final mission in missions) {
      final String? csvFile = mission['csvFile'] as String?;
      Map<String, String>? titles;
      
      if (csvFile != null) {
        titles = await loadMissionTitles(csvFile);
      }
      
      // Créer une copie de la mission avec les titres
      final Map<String, dynamic> updatedMission = Map<String, dynamic>.from(mission);
      updatedMission['titreMission'] = titles?['titreMission'] ?? 'Mission sans titre';
      updatedMission['sousTitre'] = titles?['sousTitre'] ?? '';
      updatedMission['iconUrl'] = titles?['iconUrl'] ?? '';
      
      updatedMissions.add(updatedMission);
    }
    
    return updatedMissions;
  }
} 