import 'package:flutter/material.dart';
import 'home_page.dart';
import 'quiz_page.dart';

class QuizEndPage extends StatelessWidget {
  final int score;
  final int totalQuestions;

  const QuizEndPage({
    super.key,
    required this.score,
    required this.totalQuestions,
  });

  String _getFeedbackMessage(int score, int total) {
    final ratio = score / total;
    if (ratio >= 0.9) {
      return "Incroyable ! Tu maîtrises presque tous ces chants d'oiseaux 🏆";
    } else if (ratio >= 0.7) {
      return "Très bon score ! Tu progresses à grands pas 🌿";
    } else if (ratio >= 0.5) {
      return "Pas mal ! Encore un petit effort pour tout retenir 🐣";
    } else if (ratio >= 0.3) {
      return "Courage ! Tu es en train d'apprendre les bases 🌱";
    } else {
      return "Ce n'est que le début, persévère et tu y arriveras ! 🍃";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icône de félicitations
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF000000),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.celebration,
                      size: 50,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Message de félicitations
                  const Text(
                    "Quiz terminé !",
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF000000),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Score
                  Text(
                    "Tu as obtenu $score sur $totalQuestions",
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8C939F),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Message de feedback personnalisé
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      _getFeedbackMessage(score, totalQuestions),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        height: 1.3,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Bouton Rejouer
                  _buildActionButton(
                    text: "Rejouer",
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizPage(missionId: 'U01'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Bouton Retour à l'accueil
                  _buildActionButton(
                    text: "Retour à l'accueil",
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF000000),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF000000),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
