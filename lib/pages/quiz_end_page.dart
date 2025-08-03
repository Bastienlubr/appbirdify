import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'quiz_page.dart';
import 'mission_unloading_screen.dart';
import '../services/firestore_service.dart';
import '../models/mission.dart';
import '../utils/star_utils.dart';

class QuizEndPage extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final Mission? mission; // Mission associée au quiz (peut être null)

  const QuizEndPage({
    super.key,
    required this.score,
    required this.totalQuestions,
    this.mission,
  });

  @override
  State<QuizEndPage> createState() => _QuizEndPageState();
}

class _QuizEndPageState extends State<QuizEndPage> {
  @override
  void initState() {
    super.initState();
    // Mettre à jour les étoiles si une mission est fournie
    if (widget.mission != null) {
      _updateMissionStars();
    }
  }

  /// Met à jour les étoiles de la mission dans Firestore
  Future<void> _updateMissionStars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || widget.mission == null) return;

      // Récupérer les étoiles actuelles de la mission
      int currentStars = widget.mission!.lastStarsEarned;
      
      // Calculer les nouvelles étoiles
      int newStars = StarUtils.computeUpdatedStars(currentStars, widget.score);
      
      // Si de nouvelles étoiles ont été gagnées
      if (newStars > currentStars) {
        // Mettre à jour dans Firestore (pas de mise à jour locale car lastStarsEarned est final)
        
        // Mettre à jour dans Firestore
        await FirestoreService().updateMissionStars(
          user.uid, 
          widget.mission!.id, 
          newStars
        );
        
        if (kDebugMode) {
          debugPrint('Nouvelles étoiles gagnées pour ${widget.mission!.id}: $newStars (était $currentStars)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors de la mise à jour des étoiles: $e');
      }
    }
  }



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
                    "Tu as obtenu ${widget.score} sur ${widget.totalQuestions}",
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
                      _getFeedbackMessage(widget.score, widget.totalQuestions),
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
                      // Naviguer vers l'écran de déchargement avec 5 vies (quiz terminé)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MissionUnloadingScreen(
                            livesRemaining: 5, // Quiz terminé, vies intactes
                          ),
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
