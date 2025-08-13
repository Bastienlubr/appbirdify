class AnswerRecap {
  final String questionBird; // oiseau correct (attendu)
  final String selected; // réponse choisie par l'utilisateur
  final bool isCorrect;
  final String audioUrl; // son de l'oiseau correct (si disponible)

  const AnswerRecap({
    required this.questionBird,
    required this.selected,
    required this.isCorrect,
    required this.audioUrl,
  });
}


