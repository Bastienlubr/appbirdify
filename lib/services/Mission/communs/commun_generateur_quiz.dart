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

  // Normalise les en-têtes: minuscules, accents retirés, espaces->underscore, apostrophes standardisées
  static String _normalizeHeader(String raw) {
    String h = raw.toString().trim().toLowerCase();
    h = h
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('’', "'")
        .replaceAll('‘', "'");
    h = h.replaceAll(RegExp(r"\s+"), '_');
    return h;
  }

  /// Charge un fichier CSV de mission et génère un quiz
  static Future<List<QuizQuestion>> generateQuizFromCsv(String missionId) async {
    try {
      // Charger le fichier CSV
      final csvPath = 'assets/Missionhome/questionMission/$missionId.csv';
      debugPrint('🔄 Tentative de chargement du fichier CSV: $csvPath');
      final csvString = await rootBundle.loadString(csvPath);
      debugPrint('✅ Fichier CSV chargé avec succès: ${csvString.length} caractères');
      // Normaliser les fins de ligne pour éviter les CSV monoligne (\r only)
      final normalizedCsv = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      
      // Parser le CSV avec le package csv
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(normalizedCsv);
      // Fallback: si une seule "ligne" détectée, parser manuellement
      if (csvTable.length <= 1) {
        final lines = normalizedCsv
            .replaceAll('\u2028', '\n')
            .replaceAll('\u2029', '\n')
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.length > 1) {
          final manual = <List<dynamic>>[];
          for (final line in lines) {
            manual.add(_parseCsvLineFlexible(line));
          }
          csvTable = manual;
        }
      }
      if (csvTable.isEmpty) {
        throw Exception('Fichier CSV vide');
      }
      
      debugPrint('📊 CSV parsé: ${csvTable.length} lignes');
      
      // Extraire et normaliser les en-têtes
      final rawHeaders = csvTable[0].map((e) => e.toString()).toList();
      final headers = rawHeaders.map(_normalizeHeader).toList();
      debugPrint('📋 En-têtes: $headers');
      
      // Séparer bonnes et mauvaises réponses
      final goodAnswers = <Map<String, String>>[];
      final wrongAnswers = <String>[];
      
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;
        
        // Créer un Map pour cette ligne avec clés normalisées
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          csvRow[headers[j]] = row[j]?.toString().trim() ?? '';
        }
        
        debugPrint('📝 Ligne $i: $csvRow');
        
        if ((csvRow['num_question'] ?? '').isNotEmpty) {
          goodAnswers.add(csvRow);
          debugPrint('✅ Question ajoutée: ${csvRow['bonne_reponse']}');
        } else if ((csvRow['mauvaise_reponse'] ?? '').isNotEmpty) {
          wrongAnswers.add(csvRow['mauvaise_reponse']!);
          debugPrint('❌ Mauvaise réponse ajoutée: ${csvRow['mauvaise_reponse']}');
        } else if ((csvRow['bonne_reponse'] ?? '').isNotEmpty && (csvRow['num_question'] ?? '').isEmpty) {
          // fallback pour anciennes structures
          wrongAnswers.add(csvRow['bonne_reponse']!);
          debugPrint('🔄 Réponse de fallback ajoutée: ${csvRow['bonne_reponse']}');
        }
      }
      // Construire un pool de 15 bonnes (uniques par nom) et 30 mauvaises
      final Map<String, Map<String, String>> uniqueGoodByName = {};
      for (final row in goodAnswers) {
        final name = (row['bonne_reponse'] ?? '').trim();
        if (name.isEmpty) continue;
        uniqueGoodByName.putIfAbsent(name, () => row);
      }

      if (uniqueGoodByName.length < _questionsPerQuiz) {
        throw Exception('Pas assez de bonnes réponses uniques dans le CSV (${uniqueGoodByName.length} < $_questionsPerQuiz)');
      }

      final random = Random();
      final uniqueGoodList = uniqueGoodByName.values.toList()..shuffle(random);
      final int goodPoolSize = uniqueGoodList.length >= 15 ? 15 : uniqueGoodList.length;
      final List<Map<String, String>> selectedGoodPool = uniqueGoodList.take(goodPoolSize).toList();
      final List<Map<String, String>> selectedGoodQuestions = selectedGoodPool.take(_questionsPerQuiz).toList();
      final List<String> extraGoodNames = selectedGoodPool
          .skip(_questionsPerQuiz)
          .map((m) => (m['bonne_reponse'] ?? '').trim())
          .where((n) => n.isNotEmpty)
          .toList();

      // 30 mauvaises max (uniques), en excluant toute espèce "bonne" de la mission
      final Set<String> goodNameSet = uniqueGoodByName.keys.toSet();
      final List<String> uniqueWrong = wrongAnswers
          .map((e) => e.trim())
          .where((n) => n.isNotEmpty && !goodNameSet.contains(n))
          .toSet()
          .toList();
      final List<String> thirtyWrong = uniqueWrong.length > 30 ? uniqueWrong.sublist(0, 30) : uniqueWrong;
      if (kDebugMode) {
        debugPrint('[CSV:$missionId] wrongRaw=${wrongAnswers.length} wrongUnique=${uniqueWrong.length} used=${thirtyWrong.length} sampleWrong=${thirtyWrong.take(10).toList()}');
      }

      if (kDebugMode) {
        debugPrint('[CSV:$missionId] goodUnique=${uniqueGoodByName.length} pool15=${selectedGoodPool.length} q10=${selectedGoodQuestions.length} extraGood=${extraGoodNames.length}');
        debugPrint('[CSV:$missionId] wrongUnique=${uniqueWrong.length} usedWrong=${thirtyWrong.length} sampleWrong=${thirtyWrong.take(10).toList()}');
      }
      return _generateQuizQuestionsFromCSV(selectedGoodQuestions, thirtyWrong, extraGoodNames);
    } catch (e) {
      debugPrint('Erreur lors de la génération du quiz: $e');
      rethrow;
    }
  }

  /// Génère un quiz à partir d'un document de mission Firestore
  /// Utilise pool.bonnesDetails: [{ id, nomFrancais, urlAudio, urlImage }]
  static List<QuizQuestion> generateQuizFromMissionDoc(Map<String, dynamic> missionDoc) {
    final pool = missionDoc['pool'] as Map<String, dynamic>?;
    final List<dynamic> bonnesDetails = (pool?['bonnesDetails'] as List<dynamic>?) ?? [];
    if (bonnesDetails.isEmpty) {
      throw Exception('Mission sans pool.bonnesDetails');
    }

    // Construire la liste des espèces disponibles (nom + audio)
    final List<Map<String, String>> species = bonnesDetails.map((e) {
      final m = e as Map<String, dynamic>;
      return {
        'nom': (m['nomFrancais'] ?? '').toString(),
        'audio': (m['urlAudio'] ?? '').toString(),
      };
    }).where((m) => m['nom']!.isNotEmpty && m['audio']!.isNotEmpty).toList();

    if (species.length < _questionsPerQuiz) {
      throw Exception('Pas assez d\'espèces avec audio (${species.length} < $_questionsPerQuiz)');
    }

    // Extraire un éventuel pool de "mauvaises" (distracteurs) côté Firestore
    // Formats supportés:
    // - pool.mauvaises: ["Nom 1", "Nom 2", ...]
    // - pool.mauvaisesDetails: [{ nomFrancais: "Nom 1" }, ...]
    final List<String> wrongNames = () {
      final List<String> results = [];
      final dynMauvaises = pool?['mauvaises'];
      if (dynMauvaises is List) {
        for (final item in dynMauvaises) {
          final name = item?.toString().trim();
          if (name != null && name.isNotEmpty) results.add(name);
        }
      }
      final dynMauvaisesDetails = pool?['mauvaisesDetails'];
      if (dynMauvaisesDetails is List) {
        for (final item in dynMauvaisesDetails) {
          if (item is Map) {
            final name = (item['nomFrancais'] ?? '').toString().trim();
            if (name.isNotEmpty) results.add(name);
          }
        }
      }
      // Déduplique
      return results.toSet().toList();
    }();

    // Construire le pool de 15 bonnes (ou moins), puis en tirer 10 pour les questions
    final random = Random();
    final List<Map<String, String>> shuffledSpecies = List<Map<String, String>>.from(species)..shuffle(random);
    final int goodPoolSize = species.length >= 15 ? 15 : species.length;
    final List<Map<String, String>> selectedGoodPool = shuffledSpecies.take(goodPoolSize).toList();
    final List<Map<String, String>> selectedGood = selectedGoodPool.take(_questionsPerQuiz).toList();
    final List<String> extraGoodNames = selectedGoodPool
        .skip(_questionsPerQuiz)
        .map((m) => m['nom']!)
        .toList();

    final questions = <QuizQuestion>[];
    for (final good in selectedGood) {
      final correctAnswer = good['nom']!;
      final audioUrl = good['audio']!;

      // Construire options: bonne + 3 distracteurs
      final List<String> options = [correctAnswer];

      // Pool de distracteurs: 30 "mauvaises" (si fournies) + 5 bonnes restantes
      List<String> wrongPool = wrongNames.toSet().toList();
      if (wrongPool.length > 30) {
        wrongPool = wrongPool.sublist(0, 30);
      }
      final Set<String> distractorPoolSet = {...wrongPool, ...extraGoodNames};
      final List<String> distractorPool = distractorPoolSet.where((n) => n != correctAnswer).toList()..shuffle(random);
      final List<String> pickedDistractors = distractorPool.take(_optionsPerQuestion - 1).toList();

      // Fallback: compléter avec d'autres "bonnes" de la mission si besoin
      if (pickedDistractors.length < (_optionsPerQuestion - 1)) {
        final Set<String> already = {...pickedDistractors, correctAnswer};
        final List<String> fallbackOthers = species
            .map((m) => m['nom']!)
            .where((n) => !already.contains(n))
            .toList()
          ..shuffle(random);
        for (final name in fallbackOthers) {
          if (pickedDistractors.length >= (_optionsPerQuestion - 1)) break;
          pickedDistractors.add(name);
        }
      }

      options.addAll(pickedDistractors);
      options.shuffle(random);

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

  /// Version asynchrone qui combine Firestore (bonnes avec audio) + CSV (mauvaises par nom)
  /// - missionId: utilisé pour lire le CSV d'assets `assets/Missionhome/questionMission/<missionId>.csv`
  static Future<List<QuizQuestion>> generateQuizFromFirestoreAndCsv(
    String missionId,
    Map<String, dynamic> missionDoc,
  ) async {
    final pool = missionDoc['pool'] as Map<String, dynamic>?;
    final List<dynamic> bonnesDetails = (pool?['bonnesDetails'] as List<dynamic>?) ?? [];
    if (bonnesDetails.isEmpty) {
      throw Exception('Mission sans pool.bonnesDetails');
    }

    // Construire la liste des espèces disponibles (nom + audio)
    final List<Map<String, String>> species = bonnesDetails.map((e) {
      final m = e as Map<String, dynamic>;
      return {
        'nom': (m['nomFrancais'] ?? '').toString(),
        'audio': (m['urlAudio'] ?? '').toString(),
      };
    }).where((m) => m['nom']!.isNotEmpty && m['audio']!.isNotEmpty).toList();

    if (species.length < _questionsPerQuiz) {
      throw Exception('Pas assez d\'espèces avec audio (${species.length} < $_questionsPerQuiz)');
    }

    // Construire le pool de 15 bonnes (ou moins), puis en tirer 10 pour les questions
    final random = Random();
    final List<Map<String, String>> shuffledSpecies = List<Map<String, String>>.from(species)..shuffle(random);
    final int goodPoolSize = species.length >= 15 ? 15 : species.length;
    final List<Map<String, String>> selectedGoodPool = shuffledSpecies.take(goodPoolSize).toList();
    final List<Map<String, String>> selectedGood = selectedGoodPool.take(_questionsPerQuiz).toList();
    final List<String> extraGoodNames = selectedGoodPool
        .skip(_questionsPerQuiz)
        .map((m) => m['nom']!)
        .toList();

    // Charger les 30 mauvaises depuis le CSV de la mission
    final List<String> wrongFromCsv = await _loadWrongAnswersFromCsv(missionId);
    // Exclure toute "bonne" de la mission des mauvaises, puis tronquer à 30
    final Set<String> goodNamesSet = species.map((m) => m['nom']!).toSet();
    final List<String> filteredWrong = wrongFromCsv.where((n) => !goodNamesSet.contains(n)).toList();
    final List<String> thirtyWrong = filteredWrong.length > 30 ? filteredWrong.sublist(0, 30) : filteredWrong;
    if (kDebugMode) {
      debugPrint('[FS+CSV:$missionId] speciesWithAudio=${species.length} pool15=${selectedGoodPool.length} extraGood=${extraGoodNames.length}');
      debugPrint('[FS+CSV:$missionId] wrongRaw=${wrongFromCsv.length} wrongFiltered=${filteredWrong.length} used=${thirtyWrong.length} sampleWrong=${thirtyWrong.take(10).toList()}');
    }

    final questions = <QuizQuestion>[];
    for (final good in selectedGood) {
      final correctAnswer = good['nom']!;
      final audioUrl = good['audio']!;

      final List<String> options = [correctAnswer];

      // Distracteurs = 30 mauvaises CSV + 5 bonnes restantes
      final Set<String> distractorPoolSet = {...thirtyWrong, ...extraGoodNames};
      List<String> distractorPool = distractorPoolSet.where((n) => n != correctAnswer).toList();
      distractorPool.shuffle(random);
      final List<String> picked = distractorPool.take(_optionsPerQuestion - 1).toList();

      // Fallback si insuffisant: compléter avec d'autres "bonnes" de la mission
      if (picked.length < (_optionsPerQuestion - 1)) {
        final Set<String> already = {...picked, correctAnswer};
        final List<String> fallbackOthers = species
            .map((m) => m['nom']!)
            .where((n) => !already.contains(n))
            .toList()
          ..shuffle(random);
        for (final name in fallbackOthers) {
          if (picked.length >= (_optionsPerQuestion - 1)) break;
          picked.add(name);
        }
      }

      options.addAll(picked);
      options.shuffle(random);
      if (kDebugMode) {
        debugPrint('[FS+CSV:$missionId] Q:"$correctAnswer" opts=${options.join(' | ')}');
      }
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

  /// Lit les mauvaises réponses (noms) depuis le CSV d'une mission
  static Future<List<String>> _loadWrongAnswersFromCsv(String missionId) async {
    try {
      final csvPath = 'assets/Missionhome/questionMission/$missionId.csv';
      if (kDebugMode) {
        debugPrint('[CSVLoad:$missionId] path=$csvPath');
      }
      final csvString = await rootBundle.loadString(csvPath);
      final normalizedCsv = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(normalizedCsv);
      if (csvTable.length <= 1) {
        final lines = normalizedCsv
            .replaceAll('\u2028', '\n')
            .replaceAll('\u2029', '\n')
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.length > 1) {
          final manual = <List<dynamic>>[];
          for (final line in lines) {
            manual.add(_parseCsvLineFlexible(line));
          }
          csvTable = manual;
        }
      }
      if (csvTable.isEmpty) {
        if (kDebugMode) debugPrint('[CSVLoad:$missionId] table empty');
        return <String>[];
      }

      final rawHeaders = csvTable[0].map((e) => e.toString()).toList();
      final headers = rawHeaders.map(_normalizeHeader).toList();
      if (kDebugMode) debugPrint('[CSVLoad:$missionId] headers=$headers rows=${csvTable.length-1}');
      final wrong = <String>[];
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;
        final Map<String, String> csvRow = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          csvRow[headers[j]] = row[j]?.toString().trim() ?? '';
        }
        final mauvaise = (csvRow['mauvaise_reponse'] ?? '').trim();
        if (mauvaise.isNotEmpty) {
          wrong.add(mauvaise);
          continue;
        }
        // Fallback ancien format: ligne avec bonne_reponse mais sans num_question
        final bonne = (csvRow['bonne_reponse'] ?? '').trim();
        final numQ = (csvRow['num_question'] ?? '').trim();
        if (bonne.isNotEmpty && numQ.isEmpty) {
          wrong.add(bonne);
        }
      }

      // Fallback supplémentaire: si rien trouvé, tenter par index de colonne
      if (wrong.isEmpty) {
        // Chercher un index de colonne qui ressemble à "mauvaise"
        int wrongIdx = -1;
        for (int j = 0; j < rawHeaders.length; j++) {
          final hRaw = rawHeaders[j].toLowerCase();
          final hNorm = _normalizeHeader(rawHeaders[j]);
          if (hNorm.contains('mauvaise') || hRaw.contains('mauvaise')) {
            wrongIdx = j;
            break;
          }
        }
        // Si introuvable, heuristique: prendre la 7e colonne (index 6) si disponible
        if (wrongIdx < 0 && rawHeaders.length > 6) {
          wrongIdx = 6;
        }
        if (wrongIdx >= 0) {
          for (int i = 1; i < csvTable.length; i++) {
            final row = csvTable[i];
            if (row.length > wrongIdx) {
              final candidate = row[wrongIdx]?.toString().trim() ?? '';
              if (candidate.isNotEmpty) wrong.add(candidate);
            }
          }
          if (kDebugMode) debugPrint('[CSVLoad:$missionId] Fallback index wrongIdx=$wrongIdx found=${wrong.length}');
        }
      }

      final unique = wrong.toSet().toList();
      if (kDebugMode) debugPrint('[CSVLoad:$missionId] wrongFound=${wrong.length} unique=${unique.length} sample=${unique.take(10).toList()}');
      // Ne pas limiter ici: on peut avoir besoin de filtrer des doublons avec les "bonnes" ensuite
      return unique;
    } catch (e) {
      if (kDebugMode) debugPrint('[CSVLoad:$missionId] ERROR: $e');
      return <String>[];
    }
  }

  // Parser une ligne CSV de manière tolérante (guillemets optionnels)
  static List<String> _parseCsvLineFlexible(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  /// Génère les questions de quiz avec mélange aléatoire complet
  static List<QuizQuestion> _generateQuizQuestionsFromCSV(
    List<Map<String, String>> selectedGoodQuestions,
    List<String> thirtyWrong,
    List<String> extraGoodNames,
  ) {
    final random = Random();
    final questions = <QuizQuestion>[];

    // Pool de distracteurs = 30 mauvaises + 5 bonnes restantes
    final Set<String> distractorPoolSet = {...thirtyWrong, ...extraGoodNames};
    final List<String> baseDistractorPool = distractorPoolSet.toList();

    for (final goodAnswer in selectedGoodQuestions) {
      final correctAnswer = (goodAnswer['bonne_reponse'] ?? '').trim();
      // Supporte les variantes normalisées
      final audioUrl = (goodAnswer['url_bonne_reponse'] ?? '').trim();

      final options = <String>[correctAnswer];

      // Construire le pool de distracteurs pour cette question en excluant la bonne
      final List<String> localPool = baseDistractorPool.where((n) => n != correctAnswer).toList();
      localPool.shuffle(random);
      final List<String> pickedDistractors = localPool.take(_optionsPerQuestion - 1).toList();

      // Si jamais insuffisant, compléter depuis les autres bonnes (hors correcte)
      if (pickedDistractors.length < (_optionsPerQuestion - 1)) {
        final Set<String> already = {...pickedDistractors, correctAnswer};
        final List<String> extra = selectedGoodQuestions
            .map((m) => (m['bonne_reponse'] ?? '').trim())
            .where((n) => n.isNotEmpty && !already.contains(n))
            .toList();
        extra.shuffle(random);
        for (final name in extra) {
          if (pickedDistractors.length >= (_optionsPerQuestion - 1)) break;
          pickedDistractors.add(name);
        }
      }

      options.addAll(pickedDistractors);
      options.shuffle(random);
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