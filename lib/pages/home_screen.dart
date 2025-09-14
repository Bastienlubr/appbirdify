import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../widgets/biome_carousel_enhanced.dart';
import '../widgets/home_bottom_nav_bar.dart';
import 'Perchoir/base_ornitho_page.dart';
import 'Profil/profil_page.dart';
import '../data/milieu_data.dart';
import '../models/mission.dart';
import 'MissionHabitat/mission_loading_screen.dart';
import '../services/Users/user_orchestra_service.dart';
import '../services/Mission/communs/commun_chargeur_missions.dart';
import '../services/Mission/communs/commun_persistance_consultation.dart';
import '../services/Mission/communs/commun_strategie_progression.dart';
import '../widgets/dev_tools_menu.dart';
import '../ui/responsive/responsive.dart';
import 'Accueil/widgets/lives_popover.dart';
import 'Quiz/quiz_selection_page.dart';
// import '../ui/animations/transitions.dart'; // (désactivé) Animations centralisées



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // 0: Quiz, 1: Accueil, 2: Profil, 3: Bibliothèque
  // int _previousIndex = 1; // plus utilisé
  final GlobalKey<_HomeContentState> _homeContentKey = GlobalKey<_HomeContentState>();
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 1) Fermer le popover des vies s'il est ouvert
        final handled = _homeContentKey.currentState?.closeLivesPopoverIfOpen() ?? false;
        if (handled) return;
        // 2) Si on n'est pas sur Accueil, y retourner
        if (_currentIndex != 1) {
          setState(() => _currentIndex = 1);
          return;
        }
        // 3) Déjà sur Accueil sans popover: ne pas quitter l'app (on absorbe le retour)
        return;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: (
        _currentIndex == 3 
          ? const BaseOrnithoPage() 
          : _currentIndex == 2 
            ? const ProfilPage() 
            : _currentIndex == 0
              ? const QuizSelectionPage()
              : HomeContent(key: _homeContentKey)
      ),
      bottomNavigationBar: HomeBottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: (idx) {
          if (kDebugMode) debugPrint('🧭 Onglet sélectionné: $idx');
          setState(() {
            // _previousIndex = _currentIndex;
            _currentIndex = idx;
          });
        },
      ),
    ));
  }

  // ✅ Transitions gérées par AppTransitions.smartTransitionBuilder
  // Anciennes méthodes supprimées pour simplicité et performance
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String _selectedBiome = 'Urbain';
  List<bool> _missionVisibility = [];
  List<Mission> _currentMissions = [];
  late ScrollController _missionScrollController;
  
  // Cache pour les missions déjà chargées
  final Map<String, List<Mission>> _missionsCache = {};
  bool _isLoadingMissions = false;
  
  // Gestion des vies
  int _currentLives = 5;
  final LayerLink _livesLink = LayerLink();
  OverlayEntry? _livesEntry;
  final GlobalKey<LivesPopoverState> _livesPopoverKey = GlobalKey<LivesPopoverState>();


  @override
  void initState() {
    super.initState();
    _missionScrollController = ScrollController();
    _loadMissionsForBiome(_selectedBiome);
    _loadCurrentLives();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharger les missions et les vies quand on revient d'un quiz
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Invalider le cache du biome actuel pour forcer un rechargement depuis Firestore
      // afin de refléter immédiatement les étoiles gagnées après un quiz
      _missionsCache.remove(_selectedBiome);
      // Recharger les missions avec la progression mise à jour
      await _loadMissionsForBiome(_selectedBiome);
      // Attendre un peu avant de recharger les vies pour s'assurer que la synchronisation est terminée
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadCurrentLives(); // Recharger les vies mises à jour
    });
  }

  /// Charge les vies actuelles depuis Firestore et vérifie la réinitialisation quotidienne
  Future<void> _loadCurrentLives() async {
    try {
      final uid = UserOrchestra.currentUserId;
      if (kDebugMode) debugPrint('🔍 Vérification utilisateur (HomeScreen): UID=$uid, Connecté=${UserOrchestra.isUserLoggedIn}');
      
      if (uid != null) {
        if (kDebugMode) debugPrint('🔄 Chargement des vies depuis Firestore pour utilisateur $uid');
        
        // Vérifier les vies avant checkAndResetLives
        final livesBefore = await UserOrchestra.getCurrentLives(uid);
        if (kDebugMode) debugPrint('📊 Vies dans Firestore avant checkAndResetLives: $livesBefore');
        
        final lives = await UserOrchestra.checkAndResetLives(uid);
        
        if (mounted) {
          setState(() {
            _currentLives = lives;
          });
          if (kDebugMode) debugPrint('✅ Vies chargées depuis Firestore: $_currentLives vies (était $livesBefore)');
        }
      } else {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté, vies non chargées');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des vies: $e');
      if (kDebugMode) debugPrint('   Stack trace: ${e.toString()}');
      // Fallback à 5 vies en cas d'erreur
      if (mounted) {
        setState(() {
          _currentLives = 5;
        });
      }
    }
  }





  @override
  void dispose() {
    _removeLivesPopover();
    _missionScrollController.dispose();
    super.dispose();
  }

  void _toggleLivesPopover(BuildContext context, {required double size}) {
    if (_livesEntry != null) {
      // Fermer avec animation inverse avant de retirer l'overlay
      _livesPopoverKey.currentState?.dismissWithAnimation(onCompleted: _removeLivesPopover);
      return;
    }

    final RenderBox box = context.findRenderObject() as RenderBox;
    // Ancre au bas-centre du widget vies pour que la flèche pointe dessous
    final Offset bottomCenter = box.localToGlobal(Offset(box.size.width / 2, box.size.height));

    _livesEntry = OverlayEntry(
      builder: (ctx) {
        return LivesPopover(
          key: _livesPopoverKey,
          currentLives: _currentLives,
          anchor: bottomCenter,
          onClose: () {
            _removeLivesPopover();
          },
          onLivesChanged: (newLives) {
            if (mounted) {
              setState(() {
                _currentLives = newLives;
              });
            }
          },
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_livesEntry!);
  }

  void _removeLivesPopover() {
    _livesEntry?.remove();
    _livesEntry = null;
  }

  // Exposé à HomeScreen pour intercepter le bouton retour
  bool get isLivesPopoverOpen => _livesEntry != null;
  bool closeLivesPopoverIfOpen() {
    if (_livesEntry != null) {
      _livesPopoverKey.currentState?.dismissWithAnimation(onCompleted: _removeLivesPopover);
      return true;
    }
    return false;
  }

  Future<void> _loadMissionsForBiome(String biomeName, {bool animateAppearance = true}) async {
    if (_isLoadingMissions) return; // Éviter les chargements multiples
    
    setState(() {
      _isLoadingMissions = true;
    });
    
    try {
      // Vérifier si les missions sont déjà en cache
      if (_missionsCache.containsKey(biomeName)) {
        final cachedMissions = _missionsCache[biomeName]!;
        final filteredMissions = _filterAndOrganizeMissions(cachedMissions);
        
        if (mounted) {
          setState(() {
            _currentMissions = filteredMissions;
            _missionVisibility = animateAppearance
                ? List.generate(filteredMissions.length, (index) => false)
                : List.generate(filteredMissions.length, (index) => true);
            _isLoadingMissions = false;
          });
          if (animateAppearance) {
            _animateMissionsAppearance();
          }
        }
        return;
      }
      
      // Charger les missions depuis le CSV avec progression Firestore
      final uid = UserOrchestra.currentUserId;
      List<Mission> allMissions;
      
      if (uid != null) {
        // Utiliser le système existant avec progression
        allMissions = await MissionLoaderService.loadMissionsForBiomeWithProgression(uid, biomeName.toLowerCase());
        
        // Initialiser la progression des missions si nécessaire
        if (allMissions.isNotEmpty) {
          await MissionProgressionInitService.initializeBiomeProgress(biomeName, allMissions);
        }
        
        if (kDebugMode) {
          debugPrint('🔄 Missions chargées avec progression pour le biome $biomeName:');
          for (final mission in allMissions) {
            debugPrint('   ${mission.id}: ${mission.lastStarsEarned} étoiles, statut: ${mission.status}');
          }
        }
      } else {
        // Fallback sans progression si pas d'utilisateur connecté
        allMissions = await MissionLoaderService.loadMissionsForBiome(biomeName.toLowerCase());
        
        if (kDebugMode) {
          debugPrint('⚠️ Missions chargées sans progression (utilisateur non connecté)');
        }
      }
      
      // Mettre en cache
      _missionsCache[biomeName] = allMissions;
      
      // Synchroniser en arrière-plan pour les autres biomes (sans étoiles pour l'instant)
      _syncOtherBiomesInBackground(biomeName);
      
      // Filtrer et organiser les missions selon les critères
      final List<Mission> filteredMissions = _filterAndOrganizeMissions(allMissions);
      
      if (mounted) {
        setState(() {
          _currentMissions = filteredMissions;
          _missionVisibility = animateAppearance
              ? List.generate(filteredMissions.length, (index) => false)
              : List.generate(filteredMissions.length, (index) => true);
          _isLoadingMissions = false;
        });
        if (animateAppearance) {
          _animateMissionsAppearance();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des missions: $e');
      // En cas d'erreur, utiliser les missions statiques comme fallback
      final missions = missionsParBiome[biomeName] ?? [];
      setState(() {
        _currentMissions = missions;
        _missionVisibility = List.generate(missions.length, (index) => false);
        _isLoadingMissions = false;
      });
    }
  }

  /// Anime l'apparition des missions avec des délais optimisés
  void _animateMissionsAppearance() {
    // Réinitialiser la position du scroll vers le haut
    _missionScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200), // Réduit de 300 à 200
      curve: Curves.easeOut,
    );
    
    // Animer l'apparition des missions une par une avec des délais réduits
    for (int i = 0; i < _currentMissions.length; i++) {
      Future.delayed(Duration(milliseconds: 50 + (i * 100)), () { // Réduit de 100+150 à 50+100
        if (mounted && _selectedBiome == _selectedBiome) {
          setState(() {
            if (i < _missionVisibility.length) {
              _missionVisibility[i] = true;
            }
          });
        }
      });
    }
  }



  /// Synchronise les autres biomes en arrière-plan pour vérifier le déblocage
  void _syncOtherBiomesInBackground(String currentBiome) {
    // Charger en arrière-plan pour ne pas bloquer l'interface
    Future.microtask(() async {
      try {
        for (final biomeName in _biomeUnlockOrder) {
          if (biomeName != currentBiome && !_missionsCache.containsKey(biomeName)) {
            try {
              final uid = UserOrchestra.currentUserId;
              List<Mission> missions;
              
              if (uid != null) {
                // Charger avec progression si utilisateur connecté
                missions = await MissionLoaderService.loadMissionsForBiomeWithProgression(uid, biomeName.toLowerCase());
                if (kDebugMode) {
                  debugPrint('🔄 Missions chargées en arrière-plan pour le biome $biomeName (avec progression)');
                }
              } else {
                // Fallback sans progression
                missions = await MissionLoaderService.loadMissionsForBiome(biomeName.toLowerCase());
                if (kDebugMode) {
                  debugPrint('🔄 Missions chargées en arrière-plan pour le biome $biomeName (sans progression)');
                }
              }
              
              _missionsCache[biomeName] = missions;
              
              // Mettre à jour la map statique pour la compatibilité
              missionsParBiome[biomeName] = missions;
            } catch (e) {
              if (kDebugMode) debugPrint('⚠️ Erreur lors du chargement en arrière-plan du biome $biomeName: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Erreur lors de la synchronisation en arrière-plan: $e');
      }
    });
  }

  /// Définit l'ordre de déblocage des biomes
  List<String> get _biomeUnlockOrder => [
    'Urbain',
    'Forestier', 
    'Agricole',
    'Humide',
    'Montagnard',
    'Littoral',
  ];

  /// Vérifie si un biome peut être débloqué
  bool _isBiomeUnlocked(String biomeName) {
    // Premium: tous les biomes sont accessibles
    if (UserOrchestra.isPremium) return true;
    // Le premier biome (Urbain) est toujours débloqué
    if (biomeName == 'Urbain') return true;
    
    final biomeIndex = _biomeUnlockOrder.indexOf(biomeName);
    if (biomeIndex <= 0) return true; // Premier biome ou biome non trouvé
    
    // Vérifier si le biome précédent est complété
    final previousBiome = _biomeUnlockOrder[biomeIndex - 1];
    return _isBiomeCompleted(previousBiome);
  }

  /// Vérifie si un biome est complété (dernière mission avec 2+ étoiles)
  bool _isBiomeCompleted(String biomeName) {
    try {
      // Utiliser le cache en priorité, sinon la map statique
      final biomeMissions = _missionsCache[biomeName] ?? missionsParBiome[biomeName] ?? [];
      if (biomeMissions.isEmpty) return false;
      
      // Trouver la dernière mission du biome
      final lastMission = biomeMissions.reduce((a, b) => a.index > b.index ? a : b);
      
      // Vérifier si la dernière mission a au moins 2 étoiles
      return lastMission.lastStarsEarned >= 2;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la vérification du biome $biomeName: $e');
      return false;
    }
  }

  /// Filtre et organise les missions selon les critères de déverrouillage basés sur les étoiles
  List<Mission> _filterAndOrganizeMissions(List<Mission> allMissions) {
    final List<Mission> filteredMissions = [];
    
    // Vérifier si le biome actuel est débloqué (premium => true)
    final isCurrentBiomeUnlocked = UserOrchestra.isPremium || _isBiomeUnlocked(_selectedBiome);
    
    // Trier les missions par niveau
    allMissions.sort((a, b) => a.index.compareTo(b.index));
    
    for (int i = 0; i < allMissions.length; i++) {
      final mission = allMissions[i];
      
      // Si le biome n'est pas débloqué, toutes les missions sont verrouillées
      if (!isCurrentBiomeUnlocked) {
        filteredMissions.add(mission.copyWith(status: 'locked'));
        continue;
      }
      
      // Utiliser le statut déjà calculé par le service de chargement des missions
      // Premium: on conserve la logique de progression normale (seule différence: biome toujours déverrouillé)
      if (mission.status == 'available' || mission.status == 'locked') {
        // Le statut est déjà correct, l'utiliser tel quel
        filteredMissions.add(mission);
      } else {
        // Fallback pour les missions sans statut défini
        if (mission.index == 1) {
          filteredMissions.add(mission.copyWith(status: 'available'));
        } else {
          // Pour les missions suivantes, vérifier si la mission précédente a au moins 2 étoiles
          final previousMission = allMissions.where((m) => m.index == mission.index - 1).firstOrNull;
          if (previousMission != null && previousMission.lastStarsEarned >= 2) {
            filteredMissions.add(mission.copyWith(status: 'available'));
          } else {
            filteredMissions.add(mission.copyWith(status: 'locked'));
          }
        }
      }
    }
    
    return filteredMissions;
  }





  @override
  Widget build(BuildContext context) {
    final s = useScreenSize(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size box = constraints.biggest;
        final double shortest = box.shortestSide;
        final bool isWide = box.aspectRatio >= 0.70;
        final bool isTablet = shortest >= 600;
        final double scale = s.textScale();
        final double localScale = isTablet
            ? (shortest / 800.0).clamp(0.85, 1.2)
            : (shortest / 600.0).clamp(0.92, 1.45);
        // Échelle progressive pour grands téléphones sans toucher A54
        final double phoneScaleUp = !isTablet ? (shortest / 400.0).clamp(1.0, 1.12) : 1.0;
        final double spacing = isTablet
            ? (s.spacing() * localScale * 1.08).clamp(14.0, 44.0).toDouble()
            : 24.0 * phoneScaleUp;

        final double topPadding = isTablet ? (spacing * 1.2) : 50.0;
        final double titleFontSize = isTablet
            ? (30.0 * scale * 1.10).clamp(28.0, 46.0).toDouble()
            : 30.0 * phoneScaleUp;
        final double subtitleFontSize = isTablet
            ? (14.0 * scale * 1.10).clamp(13.0, 22.0).toDouble()
            : 14.0 * phoneScaleUp;
        // Removed unused navIconSize/navLabelSize

        final double livesSize = isTablet
            ? (shortest * (isWide ? 0.135 : 0.165)).clamp(150.0, 230.0).toDouble()
            : 92.0 * phoneScaleUp;
        final double livesOffsetX = 24.0 * (livesSize / 110.0);
        final double livesOffsetY = 28.0 * (livesSize / 110.0);
        final double livesFontSize = 43.0 * (livesSize / 110.0) * (isTablet ? 1.06 : 1.0);

        // Échelle UI des cartes (1.0 mobile, >1 tablette)
        final double uiScale = isTablet ? (localScale * 1.08).clamp(1.0, 1.3).toDouble() : 1.0;

        return SafeArea(
          child: Stack(
            children: [
              DevToolsMenu(
                onLivesRestored: () {
                  if (kDebugMode) debugPrint('🔄 Rechargement forcé des vies après restauration...');
                  _loadCurrentLives();
                },
                onStarsReset: () {
                  if (kDebugMode) debugPrint('🔄 Rechargement forcé des missions après reset des étoiles...');
                  _loadMissionsForBiome(_selectedBiome);
                },
              ),

              // Bouton debug secondaire déplacé dans le menu développeur

              Positioned(
                top: 10,
                right: 18,
                child: CompositedTransformTarget(
                  link: _livesLink,
                  child: _LivesAnchor(
                    size: livesSize,
                    offset: Offset(livesOffsetX, livesOffsetY),
                    fontSize: livesFontSize,
                    lives: _currentLives,
                    onTap: (ctx) => _toggleLivesPopover(ctx, size: livesSize),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? (isWide ? 1000.0 : 900.0) : 720.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: spacing * 0.3),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitleSection(titleFontSize, subtitleFontSize),
                              SizedBox(height: spacing * 0.1),
                            ],
                          ),
                        ),
                        BiomeCarouselEnhanced(
                          // Slide (changement de page) => sélectionne et charge normalement (avec animation d’apparition)
                          onBiomeSelected: (biome) {
                            setState(() {
                              _selectedBiome = biome.name;
                            });
                            _loadMissionsForBiome(biome.name, animateAppearance: true);
                          },
                          // Désactiver l'action au tap dans Home: slide uniquement
                          onBiomeTapped: null,
                          isBiomeUnlocked: (biomeName) => _isBiomeUnlocked(biomeName),
                          selectOnPageChange: true,
                          disableTapCenterAnimation: true,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: spacing),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: spacing * 0.2),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ListView(
                                        controller: _missionScrollController,
                                        padding: EdgeInsets.only(bottom: spacing * 0.8),
                                        children: [
                                          _buildQuizCards(uiScale),
                                          SizedBox(height: spacing * 2.0),
                                        ],
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 30 * uiScale,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                                                const Color(0xFFF3F5F9).withValues(alpha: 0.4),
                                                const Color(0xFFF3F5F9).withValues(alpha: 0.7),
                                              ],
                                              stops: const [0.0, 0.6, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 25 * uiScale,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                                                const Color(0xFFF3F5F9).withValues(alpha: 0.3),
                                                const Color(0xFFF3F5F9).withValues(alpha: 0.6),
                                              ],
                                              stops: const [0.0, 0.7, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildTitleSection(double titleFontSize, double subtitleFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Les habitats',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF344356),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Le voyage ne fait que commencer...\nFaites défiler pour découvrir la suite des habitats.',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF344356),
            height: 1.4,
          ),
        ),
      ],
    );
  }



  Widget _buildQuizCards(double uiScale) {
    return Column(
      key: ValueKey(_selectedBiome),
      children: List.generate(_currentMissions.length, (index) {
        final mission = _currentMissions[index];
        return AnimatedOpacity(
          opacity: _missionVisibility[index] ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _missionVisibility[index] ? 0 : 20,
              0,
            ),
            child: _buildQuizCardMission(mission, uiScale),
          ),
        );
      }),
    );
  }

  Widget _buildQuizCardMission(Mission mission, double uiScale) {
    final hasCsvFile = mission.csvFile != null;
    // Sécuriser l'accès à la première mission du biome: toujours déverrouillée si le biome est débloqué
    final bool firstMissionUnlocked = (mission.index == 1) && _isBiomeUnlocked(_selectedBiome);
    final isUnlocked = firstMissionUnlocked || (mission.status == 'available');
    
    return _AnimatedMissionCard(
      mission: mission,
      hasCsvFile: hasCsvFile,
      isUnlocked: isUnlocked,
      uiScale: uiScale,
      onTap: (hasCsvFile && isUnlocked)
          ? () => _handleQuizLaunch(mission.id)
          : null,
      onMissionConsulted: () {
        if (kDebugMode) debugPrint('🔄 Callback onMissionConsulted appelé pour ${mission.id}');
        // Invalider le cache pour forcer le rechargement avec le nouveau statut hasBeenSeen
        _missionsCache.remove(_selectedBiome);
        _loadMissionsForBiome(_selectedBiome);
      },
    );
  }

  /// Gère le lancement d'un quiz
  Future<void> _handleQuizLaunch(String missionId) async {
    if (!mounted) return;
    
    // Vérifier si l'utilisateur a des vies disponibles
    if (_currentLives == 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF3F5F9),
          title: const Text(
            "Plus de vies",
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.bold,
              color: Color(0xFFBC4749),
            ),
          ),
          content: const Text(
            "Vous n'avez plus de vies disponibles. Revenez demain à minuit pour les restaurer.",
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 16,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE1E7EE),
                foregroundColor: const Color(0xFF334355),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFDADADA), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                "OK",
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }
    
    // Navigation vers l'écran de chargement qui préchargera les images
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionLoadingScreen(
          missionId: missionId,
          missionName: 'Mission $missionId',
        ),
      ),
    );
    
    // Recharger les vies depuis Firestore après le retour du quiz
    if (mounted) {
      await _loadCurrentLives();
      if (!mounted) return;
    }
  }






}

class _LivesAnchor extends StatelessWidget {
  final double size;
  final Offset offset;
  final double fontSize;
  final int lives;
  final void Function(BuildContext)? onTap;

  const _LivesAnchor({
    required this.size,
    required this.offset,
    required this.fontSize,
    required this.lives,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onTap?.call(context),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Image.asset(
              'assets/Images/Bouton/barviemascotte.png',
              width: size,
              height: size,
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: offset,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    lives.toString(),
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: fontSize,
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
    );
  }
}

class _AnimatedMissionCard extends StatefulWidget {
  final Mission mission;
  final bool hasCsvFile;
  final bool isUnlocked;
  final VoidCallback? onTap;
  final VoidCallback? onMissionConsulted;
  final double uiScale;

  const _AnimatedMissionCard({
    required this.mission,
    required this.hasCsvFile,
    required this.isUnlocked,
    required this.uiScale,
    this.onTap,
    this.onMissionConsulted,
  });

  @override
  State<_AnimatedMissionCard> createState() => _AnimatedMissionCardState();
}

class _AnimatedMissionCardState extends State<_AnimatedMissionCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _badgeAnimationController;
  late Animation<double> _badgeOpacityAnimation;
  late Animation<double> _badgeScaleAnimation;
  late AnimationController _badgeFloatController;
  
  // Variables pour optimiser l'affichage du badge
  bool _badgeShouldShow = false;
  bool _badgeLogShown = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Animation pour le badge "NOUVEAU"
    _badgeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _badgeOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _badgeAnimationController,
      curve: Curves.easeOut,
    ));
    _badgeScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _badgeAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Animation de flottement pour le badge (optimisée pour la performance)
    _badgeFloatController = AnimationController(
      duration: const Duration(milliseconds: 6000), // Plus lent pour économiser l'énergie
      vsync: this,
    );
    
    // Déclencher l'animation du badge si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartBadgeAnimation();
    });
  }
  
  /// Vérifie et démarre l'animation du badge de manière optimisée
  void _checkAndStartBadgeAnimation() {
    final shouldShow = _getAvailabilityText() != null;
    
    if (shouldShow != _badgeShouldShow) {
      _badgeShouldShow = shouldShow;
      
      if (shouldShow) {
        // Afficher le log une seule fois
        if (!_badgeLogShown) {
          if (kDebugMode) debugPrint('🏷️ Badge NOUVEAU affiché pour ${widget.mission.id}');
          _badgeLogShown = true;
        }
        
        // Démarrer l'animation
        _badgeAnimationController.forward().then((_) {
          // Démarrer l'animation de flottement seulement après l'apparition
          if (mounted && _badgeShouldShow) {
            _badgeFloatController.repeat();
          }
        });
      } else {
        // Arrêter l'animation si le badge ne doit plus être affiché
        _badgeAnimationController.reverse();
        _badgeFloatController.stop();
        _badgeLogShown = false;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _badgeAnimationController.dispose();
    _badgeFloatController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(_AnimatedMissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Si la mission a changé, réinitialiser l'état du badge
    if (oldWidget.mission.id != widget.mission.id || 
        oldWidget.isUnlocked != widget.isUnlocked ||
        oldWidget.mission.lastStarsEarned != widget.mission.lastStarsEarned ||
        oldWidget.mission.hasBeenSeen != widget.mission.hasBeenSeen) {
      
      _badgeLogShown = false;
      _checkAndStartBadgeAnimation();
    }
  }

  void _handleTap() {
    if (widget.onTap != null) {
      // Marquer la mission comme consultée de manière persistante
      // Dès qu'on clique sur une mission débloquée nouvellement (sans étoiles)
      if (widget.isUnlocked && widget.mission.lastStarsEarned == 0) {
        if (kDebugMode) {
          debugPrint('🔍 Mission ${widget.mission.id} cliquée - marquage comme consultée');
          debugPrint('   📊 État: débloquée=${widget.isUnlocked}, étoiles=${widget.mission.lastStarsEarned}, déjà consultée=${widget.mission.hasBeenSeen}');
        }
        
        MissionPersistenceService.markMissionAsConsulted(widget.mission.id);
        
        // Notifier le parent pour recharger les missions
        if (kDebugMode) debugPrint('🔄 Notification au parent pour recharger les missions');
        widget.onMissionConsulted?.call();
      }
      
      _animationController.forward().then((_) {
        _animationController.reverse();
        widget.onTap!();
      });
    }
  }



  /// Détermine le texte à afficher selon l'état de la mission
  String? _getAvailabilityText() {
    // Si c'est la première mission du biome (niveau 1), ne jamais afficher "NOUVEAU"
    if (widget.mission.index == 1) {
      return null;
    }
    
    // Si la mission a déjà été consultée, ne pas afficher "NOUVEAU"
    if (widget.mission.hasBeenSeen) {
      return null;
    }
    
    // Si la mission est déverrouillée et n'a pas encore d'étoiles, afficher "NOUVEAU"
    if (widget.isUnlocked && widget.mission.lastStarsEarned == 0) {
      return 'NOUVEAU';
    }
    
    // Sinon ne rien afficher
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double ui = widget.uiScale;
    final double cardHeight = 88.0 * ui;
    final double bottomMargin = 12.0 * ui;
    final double cardPadding = 8.0 * ui;
    final double missionImageSize = 64.0 * ui;
    final double titleFont = 16.0 * ui;
    final double subtitleFont = 14.0 * ui;
    final double starsRailWidth = 28.0 * ui;
    final double starSize = 24.0 * ui;
    final double starTop = 5.0 * ui;
    final double starBottom = 17.0 * ui;
    final double starRight = 7.0 * ui;
    final double badgeTop = -6.0 * ui;
    final double badgeRight = 45.0 * ui;
    final double badgeFont = 12.0 * ui;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _handleTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Carte principale de la mission
                Container(
                  height: cardHeight,
                  margin: EdgeInsets.only(bottom: bottomMargin),
                  padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: cardPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 8 * ui,
                        offset: Offset(0, 2 * ui),
                      ),
                    ],
                    border: widget.isUnlocked 
                        ? Border.all(color: const Color(0xFF6A994E).withAlpha(77), width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Espacement pour déplacer l'icône vers la droite
                      SizedBox(width: 4 * ui),
                      // Image de la mission
                      Container(
                        width: missionImageSize,
                        height: missionImageSize,
                        decoration: BoxDecoration(
                          color: widget.isUnlocked 
                              ? const Color(0xFFD2DBB2)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: !widget.isUnlocked
                              ? Image.asset(
                                  'assets/Missionhome/Images/logolock.png',
                                  width: missionImageSize,
                                  height: missionImageSize,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback vers l'icône de cadenas si l'image ne charge pas
                                    return SizedBox(
                                      width: missionImageSize,
                                      height: missionImageSize,
                                      child: Icon(
                                        Icons.lock,
                                        color: Colors.grey,
                                        size: 32 * ui,
                                      ),
                                    );
                                  },
                                )
                              : widget.mission.iconUrl != null
                                  ? Image.asset(
                                      widget.mission.iconUrl!,
                                      width: missionImageSize,
                                      height: missionImageSize,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        // Fallback vers l'icône si l'image ne charge pas
                                        return SizedBox(
                                          width: missionImageSize,
                                          height: missionImageSize,
                                          child: Icon(
                                            Icons.quiz,
                                            color: const Color(0xFF6A994E),
                                            size: 32 * ui,
                                          ),
                                        );
                                      },
                                    )
                                  : SizedBox(
                                      width: missionImageSize,
                                      height: missionImageSize,
                                      child: Icon(
                                        Icons.quiz,
                                        color: const Color(0xFF6A994E),
                                        size: 32 * ui,
                                      ),
                                    ),
                        ),
                      ),
                      
                      SizedBox(width: 16 * ui),
                      
                      // Contenu texte (largeur augmentée pour s'approcher des étoiles)
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.52, // Largeur augmentée pour s'approcher des étoiles
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.mission.titreMission ?? widget.mission.title ?? 'Mission ${widget.mission.index}',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: titleFont,
                                fontWeight: FontWeight.w700,
                                color: widget.isUnlocked 
                                    ? const Color(0xFF344356)
                                    : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2 * ui),
                            Expanded(
                              child: Text(
                                widget.mission.sousTitre ?? 'Mission ${widget.mission.index} - ${widget.mission.milieu}',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: subtitleFont,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isUnlocked 
                                      ? const Color(0xFF344356).withAlpha(179)
                                      : Colors.grey,
                                ),
                                maxLines: 4, // Plus de lignes pour compenser la largeur réduite
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Espace supplémentaire pour le sous-titre
                            SizedBox(height: 4 * ui),
                          ],
                        ),
                      ),
                      

                    ],
                  ),
                ),
                
                // Système d'étoiles positionné à droite de la case mission (seulement pour les missions débloquées)
                if (widget.isUnlocked)
                  Positioned(
                    top: starTop,
                    bottom: starBottom,
                    right: starRight,
                    child: Container(
                      width: starsRailWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2DBB2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7.2),
                          bottomLeft: Radius.circular(7.2),
                          topRight: Radius.circular(16), // Même courbure que la case mission
                          bottomRight: Radius.circular(16), // Même courbure que la case mission
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Première étoile (8/10)
                          Transform.translate(
                            offset: Offset(-0.8 * ui, 0),
                            child: Image.asset(
                              widget.mission.lastStarsEarned >= 1 
                                  ? 'assets/Images/Bouton/etoile_check.png'
                                  : 'assets/Images/Bouton/etoile-nocheck.png',
                              width: starSize,
                              height: starSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Deuxième étoile (8/10)
                          Transform.translate(
                            offset: Offset(-0.8 * ui, 0),
                            child: Image.asset(
                              widget.mission.lastStarsEarned >= 2 
                                  ? 'assets/Images/Bouton/etoile_check.png'
                                  : 'assets/Images/Bouton/etoile-nocheck.png',
                              width: starSize,
                              height: starSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Troisième étoile (10/10)
                          Transform.translate(
                            offset: Offset(-0.8 * ui, 0),
                            child: Image.asset(
                              widget.mission.lastStarsEarned >= 3 
                                  ? 'assets/Images/Bouton/etoile_check.png'
                                  : 'assets/Images/Bouton/etoile-nocheck.png',
                              width: starSize,
                              height: starSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Étiquette "NOUVEAU" positionnée au-dessus de la carte, en haut à droite
                if (_getAvailabilityText() != null)
                  Positioned(
                    top: badgeTop,
                    right: badgeRight,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_badgeAnimationController, _badgeFloatController]),
                      builder: (context, child) {
                        // Calcul du mouvement de flottement fluide et optimisé
                        final floatValue = _badgeFloatController.value;
                        final floatOffset = math.sin(floatValue * 2 * math.pi) * 1.5; // Réduit de ±2 à ±1.5 pixels
                        // Zoom fluide optimisé - utilise une courbe plus douce
                        final zoomScale = 1.0 - 0.01 * (math.sin(floatValue * 2 * math.pi) + 1) / 2; // Réduit de 0.015 à 0.01
                        // Séparer l'animation d'apparition du zoom de flottement
                        final appearanceScale = _badgeScaleAnimation.value;
                        final combinedScale = appearanceScale * zoomScale;
                        
                        return Opacity(
                          opacity: _badgeOpacityAnimation.value,
                          child: Transform.scale(
                            scale: combinedScale,
                            child: Transform.translate(
                              offset: Offset(0, floatOffset),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 4 * ui, vertical: 1 * ui),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6A994E),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _getAvailabilityText()!,
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: badgeFont,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFFEC868),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
