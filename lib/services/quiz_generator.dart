import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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
      final csvString = await rootBundle.loadString('assets/Missionhome/$missionId');
      final lines = const LineSplitter().convert(csvString);
      if (lines.isEmpty) {
        throw Exception('Fichier CSV vide');
      }
      final headers = _parseCsvLine(lines[0]);
      // Séparer bonnes et mauvaises réponses
      final goodAnswers = <Map<String, String>>[];
      final wrongAnswers = <String>[];
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final values = _parseCsvLine(line);
        final csvRow = _createCsvRow(headers, values);
        if (csvRow['num_question']?.isNotEmpty == true) {
          goodAnswers.add(csvRow);
        } else if (csvRow['mauvaise_reponse']?.isNotEmpty == true) {
          wrongAnswers.add(csvRow['mauvaise_reponse']!);
        } else if (csvRow['bonne_reponse']?.isNotEmpty == true && csvRow['num_question']?.isEmpty != false) {
          // fallback pour anciennes structures
          wrongAnswers.add(csvRow['bonne_reponse']!);
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

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  static Map<String, String> _createCsvRow(List<String> headers, List<String> values) {
    final row = <String, String>{};
    for (int i = 0; i < headers.length && i < values.length; i++) {
      row[headers[i]] = values[i];
    }
    return row;
  }

  static String generateMissionId(String milieuType, int missionNumber) {
    final prefix = milieuType.substring(0, 1).toUpperCase();
    return '$prefix${missionNumber.toString().padLeft(2, '0')}';
  }
} 