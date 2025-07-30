import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';

class QuizQuestion {
  final String correctAnswer;
  final String audioUrl;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.correctAnswer,
    required this.audioUrl,
    required this.options,
    required this.correctIndex,
  });
}

class QuizGenerator {
  static const int _questionsPerQuiz = 10;
  static const int _optionsPerQuestion = 4;

  /// Charge un fichier CSV de mission et génère un quiz
  static Future<List<QuizQuestion>> generateQuizFromCsv(String missionId) async {
    try {
      // Charger le fichier CSV
      final csvPath = 'assets/Missionhome/questionMission/$missionId.csv';
      debugPrint('🔄 Tentative de chargement du fichier CSV: $csvPath');
      final csvString = await rootBundle.loadString(csvPath);
      debugPrint('✅ Fichier CSV chargé avec succès: ${csvString.length} caractères');
      
      // Parser le CSV avec le package csv
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      if (csvTable.isEmpty) {
        throw Exception('Fichier CSV vide');
      }
      
      debugPrint('📊 CSV parsé: ${csvTable.length} lignes');
      
      // Extraire les en-têtes
      final headers = csvTable[0].map((e) => e.toString()).toList();
      debugPrint('📋 En-têtes: $headers');
      
      // Séparer bonnes et mauvaises réponses
      final goodAnswers = <Map<String, String>>[];
      final wrongAnswers = <String>[];
      
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;
        
        // Créer un Map pour cette ligne
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          csvRow[headers[j]] = row[j]?.toString() ?? '';
        }
        
        debugPrint('📝 Ligne $i: $csvRow');
        
        if (csvRow['num_question']?.isNotEmpty == true) {
          goodAnswers.add(csvRow);
          debugPrint('✅ Question ajoutée: ${csvRow['bonne_reponse']}');
        } else if (csvRow['mauvaise_reponse']?.isNotEmpty == true) {
          wrongAnswers.add(csvRow['mauvaise_reponse']!);
          debugPrint('❌ Mauvaise réponse ajoutée: ${csvRow['mauvaise_reponse']}');
        } else if (csvRow['bonne_reponse']?.isNotEmpty == true && csvRow['num_question']?.isEmpty != false) {
          // fallback pour anciennes structures
          wrongAnswers.add(csvRow['bonne_reponse']!);
          debugPrint('🔄 Réponse de fallback ajoutée: ${csvRow['bonne_reponse']}');
        }
      }
      if (goodAnswers.length < _questionsPerQuiz) {
        throw Exception('Pas assez de bonnes réponses dans le CSV (${goodAnswers.length} < $_questionsPerQuiz)');
      }
      if (wrongAnswers.length < _optionsPerQuestion - 1) {
        throw Exception('Pas assez de mauvaises réponses disponibles (${wrongAnswers.length} < ${_optionsPerQuestion - 1})');
      }
      return _generateQuizQuestionsFromCSV(goodAnswers, wrongAnswers);
    } catch (e) {
      debugPrint('Erreur lors de la génération du quiz: $e');
      rethrow;
    }
  }

  /// Génère les questions de quiz avec mélange aléatoire complet
  static List<QuizQuestion> _generateQuizQuestionsFromCSV(
    List<Map<String, String>> allGoodAnswers,
    List<String> allWrongAnswers,
  ) {
    final random = Random();
    final questions = <QuizQuestion>[];
    
    // 1. Sélectionner aléatoirement 10 bonnes réponses uniques
    final shuffledGoodAnswers = List<Map<String, String>>.from(allGoodAnswers)..shuffle(random);
    final selectedGoodAnswers = shuffledGoodAnswers.take(_questionsPerQuiz).toList();
    
    // 2. Pour chaque bonne réponse sélectionnée, générer une question
    for (final goodAnswer in selectedGoodAnswers) {
      final correctAnswer = goodAnswer['bonne_reponse']!;
      final audioUrl = goodAnswer['URL_bonne_reponse']!;
      
      // 3. Créer la liste des options avec la bonne réponse
      final options = <String>[correctAnswer];
      
      // 4. Pour CHAQUE question, sélectionner 3 mauvaises réponses aléatoires uniques
      final availableWrongAnswers = List<String>.from(allWrongAnswers);
      availableWrongAnswers.remove(correctAnswer); // Éviter les doublons
      availableWrongAnswers.shuffle(random); // Mélanger les mauvaises réponses disponibles
      
      // Prendre 3 mauvaises réponses aléatoires pour cette question spécifique
      final selectedWrongAnswers = availableWrongAnswers.take(_optionsPerQuestion - 1).toList();
      options.addAll(selectedWrongAnswers);
      
      // 5. Mélanger l'ordre des 4 options pour cette question
      options.shuffle(random);
      
      // 6. Trouver l'index de la bonne réponse après mélange
      final correctIndex = options.indexOf(correctAnswer);
      
      questions.add(QuizQuestion(
        correctAnswer: correctAnswer,
        audioUrl: audioUrl,
        options: options,
        correctIndex: correctIndex,
      ));
    }
    
    return questions;
  }



  static String generateMissionId(String milieuType, int missionNumber) {
    final prefix = milieuType.substring(0, 1).toUpperCase();
    return '$prefix${missionNumber.toString().padLeft(2, '0')}';
  }
} 