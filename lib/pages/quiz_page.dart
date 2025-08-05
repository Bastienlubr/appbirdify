import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:animations/animations.dart';
import 'package:rive/rive.dart' as rive;
import 'package:flutter_svg/flutter_svg.dart';
import '../services/quiz_generator.dart';
import '../services/life_sync_service.dart';
import '../services/mission_preloader.dart';
import '../services/image_cache_service.dart';
import '../models/mission.dart';
import '../models/bird.dart';
import 'quiz_end_page.dart';
import 'mission_unloading_screen.dart';

class QuizPage extends StatefulWidget {
  final String missionId;
  final Mission? mission;
  final Map<String, Bird>? preloadedBirds;
  
  const QuizPage({
    super.key,
    required this.missionId,
    this.mission,
    this.preloadedBirds,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<QuizQuestion> _questions = [];
  String? _selectedAnswer;
  bool _showFeedback = false;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int _score = 0;
  
  int _visibleLives = 5;
  bool _isLivesSyncing = false;
  
  late AudioPlayer _audioPlayer;
  String _currentAudioUrl = '';
  bool _isAudioLooping = false;
  bool _audioAnimationOn = true;
  
  bool _showCorrectAnswerImage = false;
  String _correctAnswerImageUrl = '';
  


  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioLooping();
    _initializeQuiz();
  }

  void _setupAudioLooping() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _isAudioLooping && mounted) {
        Future.microtask(() => _restartAudioAtRandomPosition());
      }
    });
  }

  Future<void> _initializeQuiz() async {
    await _loadLivesWithRetry();
    
    if (widget.preloadedBirds != null && widget.preloadedBirds!.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Utilisation des oiseaux préchargés (${widget.preloadedBirds!.length} oiseaux)');
      
      for (final entry in widget.preloadedBirds!.entries) {
        MissionPreloader.addBirdToCache(entry.key, entry.value);
      }
    } else {
      try {
        if (kDebugMode) debugPrint('🔄 Préchargement complet de la mission ${widget.missionId}...');
        await MissionPreloader.preloadMission(widget.missionId);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur lors du préchargement: $e');
      }
    }
    
    _loadQuiz();
  }

  Future<void> _loadLivesWithRetry() async {
    const maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final uid = LifeSyncService.getCurrentUserId();
        if (uid != null) {
          if (kDebugMode) debugPrint('🔄 Tentative ${retryCount + 1}/$maxRetries de chargement des vies pour $uid');
          
          final lives = await LifeSyncService.checkAndResetLives(uid);
          if (mounted) {
            setState(() {
              _visibleLives = lives;
            });
          }
          return;
        } else {
          if (mounted) {
            setState(() {
              _visibleLives = 5;
            });
          }
          return;
        }
      } catch (e) {
        retryCount++;
        if (kDebugMode) debugPrint('❌ Erreur lors du chargement des vies (tentative $retryCount/$maxRetries): $e');
        
        if (retryCount >= maxRetries) {
          if (mounted) {
            setState(() {
              _visibleLives = 5;
            });
          }
        } else {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }





  Widget _buildQuestionPage(QuizQuestion question, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Effet d'auréole en arrière-plan (feedback visuel subtil)
            if (_showFeedback)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showFeedback ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.bottomCenter,
                        radius: 1.8, // Rayon encore plus grand pour couvrir plus de zone
                        colors: [
                          // Déterminer la couleur selon la réponse
                          (_selectedAnswer == question.correctAnswer 
                              ? const Color(0xFF6A994E) // Vert pour bonne réponse
                              : const Color(0xFFBC4749) // Rouge pour mauvaise réponse
                          ).withValues(alpha: 0.25), // Opacité significativement augmentée
                          (_selectedAnswer == question.correctAnswer 
                              ? const Color(0xFF6A994E) // Vert pour bonne réponse
                              : const Color(0xFFBC4749) // Rouge pour mauvaise réponse
                          ).withValues(alpha: 0.15), // Couche intermédiaire plus visible
                          (_selectedAnswer == question.correctAnswer 
                              ? const Color(0xFF6A994E) // Vert pour bonne réponse
                              : const Color(0xFFBC4749) // Rouge pour mauvaise réponse
                          ).withValues(alpha: 0.08), // Couche externe subtile
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.6, 0.9], // Dégradé plus étendu et progressif
                      ),
                    ),
                  ),
                ),
              ),
            
            // Zone supérieure avec bouton échappe
            Positioned(
              top: 30, // Exactement la même hauteur que le compteur
              left: 35,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Quitter le quiz
                      _exitQuiz();
                    },
                    child: SvgPicture.asset(
                      "assets/Images/cross.svg",
                      width: 30,
                      height: 30,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF473C33),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),

                ],
              ),
            ),
            
            // Icône de vie avec compteur en haut à droite
            Positioned(
              top: 5,
              right: 30,
              child: _LivesDisplayWidget(
                lives: _visibleLives,
                isSyncing: _isLivesSyncing,
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
                    '${_currentQuestionIndex + 1} sur ${_questions.length}',
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
            
            // Bouton audio en overlay (position fixe)
            Positioned(
              top: 200, // Position fixe pour le bouton audio
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleAudio,
                  child: _AudioAnimationWidget(
                    isOn: _audioAnimationOn,
                  ),
                ),
              ),
            ),
            
            // Image de la bonne réponse en overlay (par-dessus le bouton audio)
            Positioned(
              top: 200, // Position plus basse pour éviter le titre et être plus proche des réponses
              left: 0,
              right: 0,
              child: Center(
                child: Builder(
                  builder: (context) {
                    return IgnorePointer(
                      ignoring: !_showCorrectAnswerImage, // Ignorer les interactions quand l'image n'est pas visible
                      child: _showCorrectAnswerImage && _correctAnswerImageUrl.isNotEmpty
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: SizedBox(
                                    height: 280, // Plus haut pour un format vertical
                                    width: 210, // Plus étroit pour un ratio 4:3
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15), // Coins moins arrondis
                                      child: _buildCachedImage(),
                                    ),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
            
                        // Contenu principal du quiz
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
              child: Column(
                children: [
                  // Espace supplémentaire pour éviter le chevauchement avec la barre de progression
                  const SizedBox(height: 80),
              
                  const SizedBox(height: 16),
              
              // Titre principal
              Text(
                'Quel oiseau se cache derrière ce son ?',
                                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 28,
                    fontWeight: FontWeight.w900, // Plus gras que bold
                    color: Color(0xFF344356),
                    letterSpacing: 0.5, // Espacement entre les lettres
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                      ),
                    ],
                  ),
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 2,
              ),
              
                  const SizedBox(height: 0),
              
              const SizedBox(height: 0),
              
              const SizedBox(height: 320), // Questions plus basses
              
              // Options de réponse positionnées vers le centre de l'écran
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 5),
                  
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
                        backgroundColor = const Color.fromRGBO(106, 153, 78, 0.2);
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
                                  color: const Color.fromRGBO(0, 0, 0, 0.04),
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
              
              const SizedBox(height: 20),
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
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _score = 0;
        _audioAnimationOn = true; // Animation "on" au démarrage
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
      if (audioUrl.isEmpty) {
        _showAudioErrorDialog('Aucun fichier audio disponible pour cette question.');
        return;
      }
      
      final currentQuestion = _questions[_currentQuestionIndex];
      final birdName = currentQuestion.correctAnswer;
      final preloadedAudio = MissionPreloader.getPreloadedAudio(birdName);
      
      if (preloadedAudio != null) {
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(preloadedAudio.audioSource!);
        
        _isAudioLooping = true;
        await _playAudioAtRandomPosition();
        
        if (!mounted) return;
        setState(() {
          _currentAudioUrl = audioUrl;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        
        _isAudioLooping = true;
        await _playAudioAtRandomPosition();
        
        if (!mounted) return;
        setState(() {
          _currentAudioUrl = audioUrl;
        });
      }
    } catch (e) {
      _showAudioErrorDialog('Impossible de charger l\'audio. Vérifiez votre connexion internet.');
    }
  }
  


  Future<void> _playAudioAtRandomPosition() async {
    try {
      if (_audioPlayer.audioSource == null) {
        return;
      }
      
      await _audioPlayer.play();
      
      final duration = _audioPlayer.duration;
      if (duration != null && duration.inSeconds > 0) {
        final maxStartPosition = (duration.inSeconds * 0.7).round();
        final randomPosition = maxStartPosition > 0 
            ? Duration(seconds: _getRandomInt(0, maxStartPosition))
            : Duration.zero;
        
        if (randomPosition < duration) {
          await _audioPlayer.seek(randomPosition);
        }
      }
    } catch (e) {
      try {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      } catch (fallbackError) {
        // Erreur fallback ignorée
      }
    }
  }

  Future<void> _restartAudioAtRandomPosition() async {
    if (!_isAudioLooping || !mounted) {
      return;
    }
    
    try {
      await _playAudioAtRandomPosition();
    } catch (e) {
      // Erreur ignorée
    }
  }

  int _getRandomInt(int min, int max) {
    return min + (DateTime.now().millisecondsSinceEpoch % (max - min + 1));
  }

  Future<void> _toggleAudio() async {
    try {
      final playingState = _audioPlayer.playing;
      
      setState(() {
        _audioAnimationOn = !_audioAnimationOn;
      });
      
      if (playingState) {
        _isAudioLooping = false;
        
        _audioPlayer.pause().catchError((e) {
          // Erreur ignorée
        });
      } else {
        if (_currentAudioUrl.isNotEmpty) {
          _isAudioLooping = true;
          
          _playAudioAtRandomPosition().catchError((e) {
            // Erreur ignorée
          });
        } else {
          _showAudioErrorDialog('Aucun audio disponible pour cette question.');
        }
      }
    } catch (e) {
      _showAudioErrorDialog('Erreur lors de la lecture audio. Veuillez réessayer.');
    }
  }

  Future<void> _stopAudio() async {
    try {
      _isAudioLooping = false;
      
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      // Erreur ignorée
    }
  }

  Future<void> _onAnswerSelected(String selectedAnswer) async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = selectedAnswer == currentQuestion.correctAnswer;
    
    await _stopAudio();
    
    if (!mounted) return;
    
    String imageUrl = '';
    try {
      final birdData = MissionPreloader.getBirdData(currentQuestion.correctAnswer);
      if (birdData != null) {
        imageUrl = birdData.urlImage;
      } else {
        try {
          await MissionPreloader.loadBirdifyData();
          final retryBirdData = MissionPreloader.getBirdData(currentQuestion.correctAnswer);
          if (retryBirdData != null) {
            imageUrl = retryBirdData.urlImage;
          }
        } catch (retryError) {
          // Erreur ignorée
        }
      }
    } catch (e) {
      // Erreur ignorée
    }
    
    setState(() {
      _selectedAnswer = selectedAnswer;
      _showFeedback = true;
      _showCorrectAnswerImage = true;
      _correctAnswerImageUrl = imageUrl;
      
      if (isCorrect) {
        _score++;
      } else {
        _visibleLives--;
        _syncLivesImmediately();
      }
    });

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!context.mounted) return;
    
    if (_visibleLives <= 0) {
      _onQuizFailed();
    } else {
      _goToNextQuestion();
    }
  }

  Future<void> _syncLivesImmediately() async {
    if (_isLivesSyncing) {
      return;
    }
    
    _isLivesSyncing = true;
    
    try {
      final uid = LifeSyncService.getCurrentUserId();
      if (uid != null) {
        await LifeSyncService.syncLivesAfterQuiz(uid, _visibleLives);
      }
    } catch (e) {
      // Ne pas faire échouer le quiz pour une erreur de synchronisation
    } finally {
      _isLivesSyncing = false;
    }
  }



  Widget _buildCachedImage() {
    if (_correctAnswerImageUrl.isEmpty) {
      return Container(
        width: 300,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text(
                'Image non disponible',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final imageCacheService = ImageCacheService();
    final cachedImage = imageCacheService.getCachedImage(_correctAnswerImageUrl);

    if (cachedImage != null) {
      // Image en cache - affichage instantané
      return Image(
        image: cachedImage,
        fit: BoxFit.cover, // Utilise cover pour remplir le conteneur
      );
    } else {
      // Image pas en cache - fallback vers Image.network
      return Image.network(
        _correctAnswerImageUrl,
        fit: BoxFit.cover, // Utilise cover pour remplir le conteneur
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF6A994E),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chargement...',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Image non disponible',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _goToNextQuestion() async {
    if (_currentQuestionIndex >= _questions.length - 1) {
      _onQuizCompleted();
      return;
    }
    
    _isAudioLooping = false;
    
    final nextQuestion = _questions[_currentQuestionIndex + 1];
    
    _loadAndPlayAudio(nextQuestion.audioUrl);
    
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _showFeedback = false;
      _showCorrectAnswerImage = false;
      _correctAnswerImageUrl = '';
      _audioAnimationOn = true;
    });
  }

  void _exitQuiz() async {
    if (!mounted) return;
    
    await _stopAudio();
    
    if (!_isLivesSyncing) {
      try {
        final uid = LifeSyncService.getCurrentUserId();
        if (uid != null) {
          await LifeSyncService.syncLivesAfterQuiz(uid, _visibleLives);
        }
      } catch (e) {
        // Continuer même en cas d'erreur
      }
    }
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MissionUnloadingScreen(
            livesRemaining: _visibleLives,
            missionId: widget.missionId,
          ),
        ),
      );
    }
  }



  void _onQuizCompleted() async {
    if (!mounted) return;

    await _stopAudio();

    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizEndPage(
          score: _score,
          totalQuestions: _questions.length,
          mission: widget.mission,
        ),
      ),
    );
  }

  void _onQuizFailed() async {
    if (!mounted) return;

    await _stopAudio();

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Quiz échoué !',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
            color: Color(0xFFBC4749),
          ),
        ),
        content: Text(
          'Vous avez perdu toutes vos vies !\nScore final : $_score/${_questions.length}',
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MissionUnloadingScreen(
                    livesRemaining: _visibleLives,
                    missionId: widget.missionId,
                  ),
                ),
              );
            },
            child: const Text(
              'Retour',
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: Color(0xFF6A994E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erreur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                'Détails techniques:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mission ID: ${widget.missionId}\n'
                'Chemin attendu: assets/Missionhome/questionMission/${widget.missionId}.csv',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MissionUnloadingScreen(
                      livesRemaining: _visibleLives,
                      missionId: widget.missionId,
                    ),
                  ),
                );
              }
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erreur Audio'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MissionUnloadingScreen(
                      livesRemaining: _visibleLives,
                      missionId: widget.missionId,
                    ),
                  ),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Intercepter le bouton retour du téléphone
  
          _exitQuiz();
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}

class _AudioAnimationWidget extends StatefulWidget {
  final bool isOn;
  
  const _AudioAnimationWidget({
    required this.isOn,
  });

  @override
  State<_AudioAnimationWidget> createState() => _AudioAnimationWidgetState();
}

class _AudioAnimationWidgetState extends State<_AudioAnimationWidget> {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 50), // Transition ultra-rapide
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: SizedBox(
        key: ValueKey('audio_${widget.isOn ? 'on' : 'off'}'),
        width: 160,
        height: 160,
        child: rive.RiveAnimation.asset(
          widget.isOn 
              ? 'assets/animations/audio_on.riv'
              : 'assets/animations/audio_off.riv',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _LivesDisplayWidget extends StatefulWidget {
  final int lives;
  final bool isSyncing;
  
  const _LivesDisplayWidget({
    required this.lives,
    required this.isSyncing,
  });

  @override
  State<_LivesDisplayWidget> createState() => _LivesDisplayWidgetState();
}

class _LivesDisplayWidgetState extends State<_LivesDisplayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void didUpdateWidget(_LivesDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.lives != oldWidget.lives) {
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                Image.asset(
                  'assets/Images/Bouton/barvie.png',
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(188, 71, 73, 0.2),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFFBC4749),
                        size: 40,
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: const Offset(18, -0.5),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        widget.lives.toString(),
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: widget.lives <= 1 
                              ? const Color(0xFFBC4749)
                              : const Color(0xFF473C33),
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        );
      },
    );
  }
}