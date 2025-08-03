import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:animations/animations.dart';
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
  final Mission? mission; // Mission associée au quiz
  final Map<String, Bird>? preloadedBirds; // Oiseaux préchargés depuis l'écran de chargement
  
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
  
  // Gestion des vies
  int _visibleLives = 5;
  
    // Gestion de l'audio
  late AudioPlayer _audioPlayer;
  String _currentAudioUrl = '';
  bool _isAudioLooping = false;
  bool _isRestartingAudio = false; // Protection contre les relancements multiples
  
  // Gestion de l'affichage de l'image de la bonne réponse
  bool _showCorrectAnswerImage = false;
  String _correctAnswerImageUrl = '';
  


  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioLooping();
    _initializeQuiz();
  }

  /// Configure la boucle audio avec transition fluide
  void _setupAudioLooping() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _isAudioLooping && mounted) {
        // L'audio est terminé, relancer avec une position aléatoire
        // Utiliser un microtask pour éviter les appels multiples
        Future.microtask(() => _restartAudioAtRandomPosition());
      }
    });
  }

  Future<void> _initializeQuiz() async {
    // Charger les vies restantes depuis Firestore et vérifier la réinitialisation quotidienne
    try {
      final uid = LifeSyncService.getCurrentUserId();
      if (uid != null) {
        final lives = await LifeSyncService.checkAndResetLives(uid);
        if (mounted) {
          setState(() {
            _visibleLives = lives;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des vies: $e');
      // Fallback à 5 vies en cas d'erreur
      if (mounted) {
        setState(() {
          _visibleLives = 5;
        });
      }
    }
    
    // Si les oiseaux sont déjà préchargés, les utiliser directement
    if (widget.preloadedBirds != null && widget.preloadedBirds!.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Utilisation des oiseaux préchargés (${widget.preloadedBirds!.length} oiseaux)');
      
      // Ajouter les oiseaux préchargés au cache du MissionPreloader
      for (final entry in widget.preloadedBirds!.entries) {
        MissionPreloader.addBirdToCache(entry.key, entry.value);
      }
    } else {
      // Précharger tous les éléments de la mission (fallback)
      try {
        if (kDebugMode) debugPrint('🔄 Préchargement complet de la mission ${widget.missionId}...');
        final preloadResults = await MissionPreloader.preloadMission(widget.missionId);
        
        if (kDebugMode) {
          debugPrint('✅ Préchargement terminé:');
          debugPrint('   - Audios: ${preloadResults['successfulAudioPreloads']}/${preloadResults['totalBirds']}');
          debugPrint('   - Images: ${preloadResults['successfulImagePreloads']}/${preloadResults['totalBirds']}');
          debugPrint('   - Oiseaux: ${preloadResults['birdNames']}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur lors du préchargement: $e');
      }
    }
    
    _loadQuiz();
  }

  @override
  void dispose() {
    // Ne plus synchroniser automatiquement les vies ici
    // Cela sera fait par l'écran de déchargement
    
    _audioPlayer.dispose();
    
    // Ne plus nettoyer automatiquement le cache audio ici
    // Cela sera fait par l'écran de déchargement
    
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
            // Zone supérieure avec bouton échappe
            Positioned(
              top: 30, // Exactement la même hauteur que le compteur
              left: 35,
              child: GestureDetector(
                onTap: () {
                  // Quitter le quiz
                  _exitQuiz();
                },
                child: Image.asset(
                  "assets/Images/Bouton/Boutonechap2.png",
                  width: 30, // Beaucoup plus gros
                  height: 30, // Beaucoup plus gros
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF473C33),
                      size: 80,
                    );
                  },
                ),
              ),
            ),
            
            // Icône de vie avec compteur en haut à droite
            Positioned(
              top: 5,
              right: 30,
                              child: SizedBox(
                  width: 80,
                  height: 80,
                child: Stack(
                  children: [
                    // Icône de vie en arrière-plan
                    Image.asset(
                      'assets/Images/Bouton/barvie.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBC4749).withAlpha(51),
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
                    // Compteur de vies centré par-dessus
                    Positioned.fill(
                      child: Transform.translate(
                        offset: const Offset(18, -0.5), // Ajustement fin de la position verticale
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            _visibleLives.toString(),
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF473C33),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
              
                  const SizedBox(height: 16),
              
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
              
                  const SizedBox(height: 24),
              
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
              
              const SizedBox(height: 16),
              
              // Affichage de l'image de la bonne réponse
              SizedBox(
                height: 200,
                child: Center(
                  child: AnimatedScale(
                    scale: _showCorrectAnswerImage ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: _showCorrectAnswerImage && _correctAnswerImageUrl.isNotEmpty
                        ? Builder(
                            builder: (context) {
                              if (kDebugMode) debugPrint('🖼️ Rendu de l\'image: $_correctAnswerImageUrl');
                              
                              // Déterminer la couleur du contour selon la réponse
                              final isCorrectAnswer = _selectedAnswer == question.correctAnswer;
                              final borderColor = isCorrectAnswer 
                                  ? const Color(0xFF6A994E) // Vert pour bonne réponse
                                  : const Color(0xFFBC4749); // Rouge pour mauvaise réponse
                              
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor.withAlpha(60), // Bordure légère sur l'image
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    // Effet glowy intensifié avec plusieurs couches pour un fondu progressif
                                    BoxShadow(
                                      color: borderColor.withAlpha(120), // Plus intense
                                      blurRadius: 12,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 3),
                                    ),
                                    BoxShadow(
                                      color: borderColor.withAlpha(100), // Plus intense
                                      blurRadius: 20,
                                      spreadRadius: 6,
                                      offset: const Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: borderColor.withAlpha(80), // Plus intense
                                      blurRadius: 28,
                                      spreadRadius: 8,
                                      offset: const Offset(0, 7),
                                    ),
                                    BoxShadow(
                                      color: borderColor.withAlpha(60), // Plus intense
                                      blurRadius: 36,
                                      spreadRadius: 10,
                                      offset: const Offset(0, 9),
                                    ),
                                    BoxShadow(
                                      color: borderColor.withAlpha(40), // Couche supplémentaire
                                      blurRadius: 44,
                                      spreadRadius: 12,
                                      offset: const Offset(0, 11),
                                    ),
                                    BoxShadow(
                                      color: borderColor.withAlpha(20), // Couche finale
                                      blurRadius: 52,
                                      spreadRadius: 14,
                                      offset: const Offset(0, 13),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10), // Légèrement plus petit pour laisser place à la bordure
                                  child: _buildCachedImage(),
                                ),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
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
      });
      
      // Charger et lancer l'audio de la première question (utilise maintenant le cache)
      if (questions.isNotEmpty) {
        _loadAndPlayAudio(questions[0].audioUrl);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Erreur détaillée: $e');
      _showErrorDialog('Erreur lors du chargement du quiz: $e');
    }
  }

  Future<void> _loadAndPlayAudio(String audioUrl) async {
    try {
      // Vérifier que l'URL audio n'est pas vide
      if (audioUrl.isEmpty) {
        _showAudioErrorDialog('Aucun fichier audio disponible pour cette question.');
        return;
      }
      
      // Essayer d'utiliser l'audio préchargé depuis le cache
      final currentQuestion = _questions[_currentQuestionIndex];
      final birdName = currentQuestion.correctAnswer;
      final preloadedAudio = MissionPreloader.getPreloadedAudio(birdName);
      
      if (preloadedAudio != null) {
        if (kDebugMode) debugPrint('🎵 Utilisation de l\'audio préchargé pour: $birdName');
        
        // Arrêter l'audio en cours et utiliser l'audio préchargé simultanément
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(preloadedAudio.audioSource!);
        
        // Activer la boucle pour cette question
        _isAudioLooping = true;
        
        // Lancer la lecture à une position aléatoire immédiatement
        await _playAudioAtRandomPosition();
        
        if (!mounted) return;
        setState(() {
          _currentAudioUrl = audioUrl;
        });
      } else {
        if (kDebugMode) debugPrint('⚠️ Audio non trouvé en cache pour: $birdName, chargement normal');
        
        // Fallback : charger l'audio normalement
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        
        // Activer la boucle pour cette question
        _isAudioLooping = true;
        
        // Lancer la lecture à une position aléatoire
        await _playAudioAtRandomPosition();
        
        if (!mounted) return;
        setState(() {
          _currentAudioUrl = audioUrl;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement audio: $e');
      _showAudioErrorDialog('Impossible de charger l\'audio. Vérifiez votre connexion internet.');
    }
  }
  


  /// Lance l'audio à une position aléatoire
  Future<void> _playAudioAtRandomPosition() async {
    try {
      // Vérifier que l'audio est bien chargé
      if (_audioPlayer.audioSource == null) {
        debugPrint('❌ Aucune source audio chargée');
        return;
      }
      
      // Lancer la lecture immédiatement (position 0 pour plus de rapidité)
      await _audioPlayer.play();
      
      // Obtenir la durée totale de l'audio
      final duration = _audioPlayer.duration;
      if (duration != null && duration.inSeconds > 0) {
        // Calculer une position aléatoire dans le premier tiers de l'audio
        // pour s'assurer qu'il y a assez de temps pour entendre le chant
        final maxStartPosition = (duration.inSeconds * 0.7).round(); // 70% de la durée
        final randomPosition = maxStartPosition > 0 
            ? Duration(seconds: _getRandomInt(0, maxStartPosition))
            : Duration.zero;
        
        // Vérifier que la position n'est pas au-delà de la durée
        if (randomPosition < duration) {
          // Positionner l'audio à la position aléatoire après le démarrage
          await _audioPlayer.seek(randomPosition);
          
          if (kDebugMode) {
            debugPrint('🎵 Audio lancé à la position: ${randomPosition.inSeconds}s / ${duration.inSeconds}s');
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ Position aléatoire invalide, démarrage depuis le début');
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du lancement aléatoire: $e');
      // Fallback : lancer normalement depuis le début
      try {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      } catch (fallbackError) {
        debugPrint('❌ Erreur lors du fallback audio: $fallbackError');
      }
    }
  }

  /// Relance l'audio à une position aléatoire (pour la boucle)
  Future<void> _restartAudioAtRandomPosition() async {
    if (!_isAudioLooping || _isRestartingAudio || !mounted) return;
    
    _isRestartingAudio = true;
    
    try {
      // Attendre un court délai pour une transition plus naturelle
      await Future.delayed(const Duration(milliseconds: 50)); // Réduit pour plus de rapidité
      
      // Vérifier que la boucle est toujours active
      if (_isAudioLooping && mounted) {
        // Relancer à une position aléatoire
        await _playAudioAtRandomPosition();
        
        if (kDebugMode) {
          debugPrint('🔄 Audio relancé en boucle');
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du relancement: $e');
    } finally {
      _isRestartingAudio = false;
    }
  }

  /// Génère un nombre aléatoire entre min et max
  int _getRandomInt(int min, int max) {
    return min + (DateTime.now().millisecondsSinceEpoch % (max - min + 1));
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
      _isAudioLooping = false; // Désactiver la boucle
      _isRestartingAudio = false; // Réinitialiser le flag de protection
      
      // Arrêter l'audio seulement s'il est en cours de lecture
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
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
    
    if (!mounted) return;
    
    // Récupérer l'URL de l'image de la bonne réponse
    String imageUrl = '';
    try {
      if (kDebugMode) debugPrint('🔍 Recherche de l\'oiseau: ${currentQuestion.correctAnswer}');
      final birdData = MissionPreloader.getBirdData(currentQuestion.correctAnswer);
      if (birdData != null) {
        imageUrl = birdData.urlImage;
        if (kDebugMode) debugPrint('✅ Image trouvée: $imageUrl');
      } else {
        if (kDebugMode) debugPrint('❌ Aucune donnée trouvée pour: ${currentQuestion.correctAnswer}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la récupération de l\'image: $e');
    }
    
    setState(() {
      _selectedAnswer = selectedAnswer;
      _showFeedback = true;
      _showCorrectAnswerImage = true;
      _correctAnswerImageUrl = imageUrl;
      
      if (kDebugMode) debugPrint('🖼️ État mis à jour - showImage: $_showCorrectAnswerImage, url: $_correctAnswerImageUrl');
      
      // Incrémenter le score si la réponse est correcte
      if (isCorrect) {
        _score++;
      } else {
        // Décrémenter les vies si la réponse est incorrecte
        _visibleLives--;
      }
    });

    // Afficher l'image pendant un délai plus long
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!context.mounted) return;
    
    // Vérifier si le joueur a encore des vies
    if (_visibleLives <= 0) {
      _onQuizFailed();
    } else {
      _goToNextQuestion();
    }
  }

  /// Construit l'image en utilisant le cache pour un affichage instantané
  Widget _buildCachedImage() {
    if (_correctAnswerImageUrl.isEmpty) {
      return Container(
        width: 300,
        height: 180,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }

    final imageCacheService = ImageCacheService();
    final cachedImage = imageCacheService.getCachedImage(_correctAnswerImageUrl);

    if (cachedImage != null) {
      // Image en cache - affichage instantané
      if (kDebugMode) debugPrint('🚀 Image affichée instantanément depuis le cache: $_correctAnswerImageUrl');
      return Image(
        image: cachedImage,
        fit: BoxFit.contain, // Utilise contain pour garder les proportions naturelles
      );
    } else {
      // Image pas en cache - fallback vers Image.network
      if (kDebugMode) debugPrint('⚠️ Image non trouvée en cache, chargement réseau: $_correctAnswerImageUrl');
      return Image.network(
        _correctAnswerImageUrl,
        fit: BoxFit.contain, // Utilise contain pour garder les proportions naturelles
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
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
                      color: Colors.grey,
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

  void _goToNextQuestion() async {
    // Vérifier si on a atteint la dernière question
    if (_currentQuestionIndex >= _questions.length - 1) {
      _onQuizCompleted();
      return;
    }
    
    // Désactiver la boucle avant de changer de question
    _isAudioLooping = false;
    
    // Préparer la nouvelle question
    final nextQuestion = _questions[_currentQuestionIndex + 1];
    
    // Charger l'audio en arrière-plan pendant la transition
    _loadAndPlayAudio(nextQuestion.audioUrl);
    
    // Mettre à jour l'interface et lancer l'audio simultanément
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _showFeedback = false;
      _showCorrectAnswerImage = false;
      _correctAnswerImageUrl = '';
    });
  }

  /// Quitte le quiz
  /// Appelé quand l'utilisateur quitte manuellement la mission
  void _exitQuiz() async {
    if (!mounted) return;
    
    // Arrêter l'audio en cours
    await _stopAudio();
    
    // Naviguer vers l'écran de déchargement
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

    // Arrêter l'audio en cours
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

    // Arrêter l'audio en cours
    await _stopAudio();

    if (!mounted) return;
    
    // Afficher un dialogue d'échec
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
              Navigator.of(context).pop(); // Fermer le dialogue
              // Naviguer vers l'écran de déchargement
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
              Navigator.of(dialogContext).pop(); // Fermer le dialogue
              
              // Naviguer vers l'écran de déchargement
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
              // Naviguer vers l'écran de déchargement
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
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Intercepter le bouton retour du téléphone
          if (kDebugMode) debugPrint('🔄 Bouton retour intercepté, redirection vers l\'écran de déchargement');
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