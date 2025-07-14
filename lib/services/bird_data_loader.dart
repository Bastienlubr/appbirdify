import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/bird.dart';

class BirdDataLoader {
  /// Charge les données des oiseaux depuis le fichier CSV
  /// 
  /// Retourne une `Future<List<Bird>>` contenant tous les oiseaux du fichier
  static Future<List<Bird>> loadBirdsFromCsv() async {
    try {
      // Charger le fichier CSV depuis les assets
      final String csvString = await rootBundle.loadString('assets/data/birds_test.csv');
      
      // Diviser le contenu en lignes
      final List<String> lines = const LineSplitter().convert(csvString);
      
      if (lines.isEmpty) {
        throw Exception('Le fichier CSV est vide');
      }

      // Extraire les en-têtes de colonnes (première ligne)
      final List<String> headers = _parseCsvLine(lines[0]);
      
      // Traiter chaque ligne de données (sauf l'en-tête)
      final List<Bird> birds = [];
      
      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final List<String> values = _parseCsvLine(line);
            final Map<String, String> csvRow = _createCsvRow(headers, values);
            final Bird bird = Bird.fromCsvRow(csvRow);
            birds.add(bird);
          } catch (e) {
            // Ignorer les lignes malformées et continuer
            debugPrint('Erreur lors du traitement de la ligne $i: $e');
          }
        }
      }

      return birds;
    } catch (e) {
      throw Exception('Erreur lors du chargement du fichier CSV: $e');
    }
  }

  /// Parse une ligne CSV en tenant compte des virgules dans les guillemets
  static List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(currentField.toString().trim());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }
    
    // Ajouter le dernier champ
    result.add(currentField.toString().trim());
    
    return result;
  }

  /// Crée un `Map<String, String>` à partir des en-têtes et des valeurs
  static Map<String, String> _createCsvRow(List<String> headers, List<String> values) {
    final Map<String, String> csvRow = {};
    
    for (int i = 0; i < headers.length && i < values.length; i++) {
      csvRow[headers[i]] = values[i];
    }
    
    return csvRow;
  }

  /// Charge les données des oiseaux avec gestion d'erreur simplifiée
  static Future<List<Bird>> loadBirdsFromCsvSafe() async {
    try {
      return await loadBirdsFromCsv();
    } catch (e) {
      debugPrint('Erreur lors du chargement des oiseaux: $e');
      return []; // Retourne une liste vide en cas d'erreur
    }
  }
} 