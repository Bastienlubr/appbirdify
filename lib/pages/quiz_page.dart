import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_generator.dart';
import '../services/quiz_life_manager.dart';
import '../widgets/lives_display_widget.dart';
import 'quiz_end_page.dart';

class QuizPage extends StatefulWidget {
  final String missionId;
  
  const QuizPage({
    super.key,
    required this.missionId,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<QuizQuestion> _questions = [];
  String? _selectedAnswer;
  bool _showFeedback = false;
  bool _isCorrect = false;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  
  // Gestion de l'audio
  late AudioPlayer _audioPlayer;
  String _currentAudioUrl = '';
  
  // Gestion des animations et feedback
  bool _showFeedbackMessage = false;
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Vérifier si l'utilisateur peut lancer le quiz
        final canStart = await QuizLifeManager.canStartQuiz(user.uid);
        if (!canStart) {
          if (!mounted) return;
          
          // Afficher un message d'erreur et retourner à l'accueil
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Vous n\'avez plus de vies disponibles. Revenez demain !'),
              backgroundColor: Color(0xFFBC4749),
            ),
          );
          final navigator = Navigator.of(context);
          navigator.pop();
          return;
        }
      }
      
      // Charger le quiz si les vies sont suffisantes
      _loadQuiz();
    } catch (e) {
      // En cas d'erreur, charger le quiz quand même
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildQuestionPage(QuizQuestion question, int index) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Zone supérieure avec bouton échappe et compteur de vies
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bouton "échappe" personnalisé à gauche
                  GestureDetector(
                    onTap: () {
                      // Annuler le quiz sans consommer de vies
                      QuizLifeManager.cancelQuiz();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2DBB2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          "assets/Images/Bouton/bouton echap.png",
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF473C33),
                              size: 35,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Compteur de vies à droite
                  const LivesQuizWidget(),
                ],
              ),
            ),
            
            // Compteur de questions centré horizontalement en haut
            Align(
              alignment: Alignment.topCenter,
        child: Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Opacity(
                  opacity: 0.6,
                  child: Text(
                    '${index + 1} sur ${_questions.length}',
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 20,
                      fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                  ),
                ),
              ),
            ),
            
            // Barre de progression animée
            Positioned(
              top: 70,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          // Fond de la barre (track)
                          Container(
                            width: 300,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF473C33),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          // Barre de progression animée
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            tween: Tween<double>(
                              begin: 0.0,
                              end: (_currentQuestionIndex + 1) / _questions.length,
                            ),
                            builder: (context, value, child) {
                              return Container(
                                height: 8,
                                width: 300 * value,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFABC270),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            
                        // Contenu principal du quiz
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
              child: Column(
                children: [
                  // Espace supplémentaire pour éviter le chevauchement avec la barre de progression
                  const SizedBox(height: 80),
              
                  const SizedBox(height: 24),
              
              // Titre principal
              const Text(
                'Quel oiseau se cache derrière ce son ?',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 2,
              ),
              
                  const SizedBox(height: 32),
              
              // Contrôles audio simplifiés
              Center(
                child: IconButton(
                  onPressed: _toggleAudio,
                  icon: StreamBuilder<bool>(
                    stream: _audioPlayer.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Icon(
                        isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 80,
                        color: const Color(0xFF6A994E),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Espace réservé pour le feedback (hauteur augmentée)
              SizedBox(
                height: 120,
                child: Center(
                  child: AnimatedScale(
                    scale: _showFeedbackMessage ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: _showFeedbackMessage
                        ? Container(
                            constraints: const BoxConstraints(
                              maxWidth: 320,
                              minHeight: 80,
                            ),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _isCorrect 
                                  ? const Color(0xFF6A994E).withAlpha(26)
                                  : const Color(0xFFBC4749).withAlpha(26),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isCorrect 
                                    ? const Color(0xFF6A994E).withAlpha(77)
                                    : const Color(0xFFBC4749).withAlpha(77),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _isCorrect 
                                        ? const Color(0xFF6A994E)
                                        : const Color(0xFFBC4749),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _isCorrect ? Icons.check_rounded : Icons.close_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Text(
                                    _feedbackMessage,
                                    style: TextStyle(
                                      fontFamily: 'Quicksand',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _isCorrect 
                                          ? const Color(0xFF6A994E)
                                          : const Color(0xFFBC4749),
                                    ),
                                    textAlign: TextAlign.left,
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Options de réponse positionnées vers le centre de l'écran
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Container temporaire pour visualiser l'emplacement (à supprimer après test)
                  // Container(
                  //   color: Colors.red.withOpacity(0.2),
                  //   height: 200,
                  //   child: Center(child: Text('Zone des boutons', style: TextStyle(color: Colors.red))),
                  // ),
                  
                  ...List.generate(question.options.length, (optionIndex) {
                    final option = question.options[optionIndex];
                    final isSelected = _selectedAnswer == option;
                    final isCorrectAnswer = option == question.correctAnswer;

                    Color backgroundColor = Colors.white;
                    Color borderColor = const Color(0xFFE0E0E0);
                    Color textColor = Colors.black;

                    if (_showFeedback) {
                      if (isSelected) {
                        if (isCorrectAnswer) {
                          backgroundColor = const Color(0xFF6A994E);
                          borderColor = const Color(0xFF6A994E);
                          textColor = Colors.white;
                        } else {
                          backgroundColor = const Color(0xFFBC4749);
                          borderColor = const Color(0xFFBC4749);
                          textColor = Colors.white;
                        }
                      } else if (isCorrectAnswer) {
                        backgroundColor = const Color(0xFF6A994E).withAlpha(50);
                        borderColor = const Color(0xFF6A994E);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 250),
                        tween: Tween<double>(
                          begin: 1.0,
                          end: (isSelected && _showFeedback) ? 1.05 : 1.0,
                        ),
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: _showFeedback ? null : () => _onAnswerSelected(option),
                          child: Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width * 0.85,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(10),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              
              const SizedBox(height: 32),
            ],
          ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadQuiz() async {
    try {
      final questions = await QuizGenerator.generateQuizFromCsv(widget.missionId);
      setState(() {
        _questions = questions;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _score = 0;
      });
      
      // Charger et lancer l'audio de la première question
      if (questions.isNotEmpty) {
        _loadAndPlayAudio(questions[0].audioUrl);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Erreur lors du chargement du quiz: $e');
    }
  }

  Future<void> _loadAndPlayAudio(String audioUrl) async {
    try {
      // Arrêter l'audio en cours s'il y en a un
      await _audioPlayer.stop();
      
      // Vérifier que l'URL audio n'est pas vide
      if (audioUrl.isEmpty) {
        _showAudioErrorDialog('Aucun fichier audio disponible pour cette question.');
        return;
      }
      
      // Charger le nouvel audio
        await _audioPlayer.setUrl(audioUrl);
      
      // Lancer la lecture automatiquement
      await _audioPlayer.play();
      
      setState(() {
        _currentAudioUrl = audioUrl;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement audio: $e');
      _showAudioErrorDialog('Impossible de charger l\'audio. Vérifiez votre connexion internet.');
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final playingState = _audioPlayer.playing;
      if (playingState) {
        await _audioPlayer.pause();
      } else {
        // Vérifier qu'il y a un audio chargé avant de jouer
        if (_currentAudioUrl.isNotEmpty) {
          await _audioPlayer.play();
        } else {
          _showAudioErrorDialog('Aucun audio disponible pour cette question.');
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du toggle audio: $e');
      _showAudioErrorDialog('Erreur lors de la lecture audio. Veuillez réessayer.');
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Erreur lors de l\'arrêt audio: $e');
    }
  }

  Future<void> _onAnswerSelected(String selectedAnswer) async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = selectedAnswer == currentQuestion.correctAnswer;
    
    // Arrêter l'audio immédiatement quand une réponse est sélectionnée
    await _stopAudio();
    
    // Consommer une vie si la réponse est incorrecte
    if (!isCorrect) {
      QuizLifeManager.loseLife();
    }
    
    setState(() {
      _selectedAnswer = selectedAnswer;
      _showFeedback = true;
      _isCorrect = isCorrect;
      
      // Incrémenter le score si la réponse est correcte
      if (isCorrect) {
        _score++;
      }
    });

    // Afficher le message de feedback
    await Future.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return;
    setState(() {
      _showFeedbackMessage = true;
      _feedbackMessage = isCorrect 
          ? "Bravo, c'était bien ${currentQuestion.correctAnswer} !"
          : "Raté ! C'était ${currentQuestion.correctAnswer}";
    });

    // Afficher le feedback pendant le délai configuré puis passer à la question suivante
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!context.mounted) return;
    _goToNextQuestion();
  }

  void _goToNextQuestion() async {
    // Vérifier si on a atteint la dernière question
    if (_currentQuestionIndex >= _questions.length - 1) {
      _onQuizCompleted();
      return;
    }
    
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _showFeedback = false;
      _showFeedbackMessage = false;
      _feedbackMessage = '';
    });
    
    // Charger et lancer l'audio de la nouvelle question
    final nextQuestion = _questions[_currentQuestionIndex];
    _loadAndPlayAudio(nextQuestion.audioUrl);
  }

  void _onQuizCompleted() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Finaliser le quiz et synchroniser les vies
        await QuizLifeManager.finishQuiz(user.uid);
      }
    } catch (e) {
      // En cas d'erreur, continuer quand même
      debugPrint('Erreur lors de la finalisation du quiz: $e');
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizEndPage(
          score: _score,
          totalQuestions: _questions.length,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  void _showAudioErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur Audio'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: _isLoading
          ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                  CircularProgressIndicator(color: Color(0xFF6A994E)),
                  SizedBox(height: 16),
                                      Text(
                    'Chargement du quiz...',
                                        style: TextStyle(
                                          fontFamily: 'Quicksand',
                      fontSize: 16,
                      color: Color(0xFF386641),
                    ),
                  ),
                ],
              ),
            )
          : _questions.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune question disponible',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 18,
                      color: Color(0xFF386641),
                    ),
                  ),
                )
              : PageTransitionSwitcher(
                  transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                    return FadeThroughTransition(
                      animation: primaryAnimation,
                      secondaryAnimation: secondaryAnimation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentQuestionIndex),
                    child: _buildQuestionPage(
                      _questions[_currentQuestionIndex],
                      _currentQuestionIndex,
          ),
        ),
      ),
    );
  }
}