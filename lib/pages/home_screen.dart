import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/biome_carousel_enhanced.dart';
import '../data/milieu_data.dart';
import '../models/mission.dart';

import '../pages/auth/login_screen.dart';
import '../pages/mission_loading_screen.dart';
import '../services/life_sync_service.dart';
import '../services/life_system_test.dart';
import '../services/mission_loader_service.dart';
import '../services/mission_persistence_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: const HomeContent(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF6A994E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), // Réduit de 8 à 6
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.quiz, 'Quiz', false),
                _buildNavItem(1, Icons.home, 'Accueil', true),
                _buildNavItem(2, Icons.person, 'Profil', false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        // TODO: Implémenter la navigation vers les différentes pages
        // setState(() => _currentIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFFEC868) : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? const Color(0xFFFEC868) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
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
      await _loadMissionsForBiome(_selectedBiome);
      // Attendre un peu avant de recharger les vies pour s'assurer que la synchronisation est terminée
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadCurrentLives(); // Recharger les vies mises à jour
    });
  }

  /// Charge les vies actuelles depuis Firestore et vérifie la réinitialisation quotidienne
  Future<void> _loadCurrentLives() async {
    try {
      final uid = LifeSyncService.getCurrentUserId();
      if (kDebugMode) debugPrint('🔍 Vérification utilisateur (HomeScreen): UID=$uid, Connecté=${LifeSyncService.isUserLoggedIn}');
      
      if (uid != null) {
        if (kDebugMode) debugPrint('🔄 Chargement des vies depuis Firestore pour utilisateur $uid');
        
        // Vérifier les vies avant checkAndResetLives
        final livesBefore = await LifeSyncService.getCurrentLives(uid);
        if (kDebugMode) debugPrint('📊 Vies dans Firestore avant checkAndResetLives: $livesBefore');
        
        final lives = await LifeSyncService.checkAndResetLives(uid);
        
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

  /// Réinitialise les vies à 5 (fonction de test uniquement)
  Future<void> _resetVies() async {
    try {
      final uid = LifeSystemTest.getCurrentUserId();
      if (uid == null) {
        if (kDebugMode) debugPrint('⚠️ Aucun utilisateur connecté');
        return;
      }

      await LifeSystemTest.resetVies(uid);
      
      // Recharger les vies depuis Firestore après la réinitialisation
      if (mounted) {
        await _loadCurrentLives();
        if (!mounted) return;
        
        // Afficher un SnackBar de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vies réinitialisées à 5 !',
              style: TextStyle(fontFamily: 'Quicksand'),
            ),
            backgroundColor: Color(0xFF6A994E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la réinitialisation des vies: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la réinitialisation: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Quicksand'),
            ),
            backgroundColor: const Color(0xFFBC4749),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  @override
  void dispose() {
    _missionScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMissionsForBiome(String biomeName) async {
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
            _missionVisibility = List.generate(filteredMissions.length, (index) => false);
            _isLoadingMissions = false;
          });
          
          _animateMissionsAppearance();
        }
        return;
      }
      
      // Charger les missions depuis le CSV
      final List<Mission> allMissions = await MissionLoaderService.loadMissionsForBiome(biomeName.toLowerCase());
      
      // Mettre en cache
      _missionsCache[biomeName] = allMissions;
      
      // Synchroniser en arrière-plan pour les autres biomes
      _syncOtherBiomesInBackground(biomeName);
      
      // Filtrer et organiser les missions selon les critères
      final List<Mission> filteredMissions = _filterAndOrganizeMissions(allMissions);
      
      if (mounted) {
        setState(() {
          _currentMissions = filteredMissions;
          _missionVisibility = List.generate(filteredMissions.length, (index) => false);
          _isLoadingMissions = false;
        });
        
        _animateMissionsAppearance();
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
              final missions = await MissionLoaderService.loadMissionsForBiome(biomeName.toLowerCase());
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
    
    // Vérifier si le biome actuel est débloqué
    final isCurrentBiomeUnlocked = _isBiomeUnlocked(_selectedBiome);
    
    // Trier les missions par niveau
    allMissions.sort((a, b) => a.index.compareTo(b.index));
    
    for (int i = 0; i < allMissions.length; i++) {
      final mission = allMissions[i];
      
      // Si le biome n'est pas débloqué, toutes les missions sont verrouillées
      if (!isCurrentBiomeUnlocked) {
        filteredMissions.add(mission.copyWith(status: 'locked'));
        continue;
      }
      
      // La première mission (index 1) est accessible si le biome est débloqué
      if (mission.index == 1) {
        filteredMissions.add(mission.copyWith(status: 'available'));
        continue;
      }
      
      // Pour les missions suivantes, vérifier si la mission précédente a au moins 2 étoiles
      final previousMission = allMissions.where((m) => m.index == mission.index - 1).firstOrNull;
      if (previousMission != null && previousMission.lastStarsEarned >= 2) {
        // Mission débloquée - ajouter avec statut 'available'
        filteredMissions.add(mission.copyWith(status: 'available'));
      } else {
        // Mission verrouillée - ajouter avec statut 'locked'
        filteredMissions.add(mission.copyWith(status: 'locked'));
      }
    }
    
    return filteredMissions;
  }



  Future<void> _signOut() async {
    try {
      debugPrint('🔄 Déconnexion en cours...');
      await FirebaseAuth.instance.signOut();
      debugPrint('✅ Déconnexion Firebase réussie');
      
      if (!mounted) return;
      
      // Navigation vers l'écran de connexion avec pushReplacement
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      debugPrint('✅ Navigation vers l\'écran de connexion réussie');
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la déconnexion: $e');
      if (!mounted) return;
      
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la déconnexion: $e'),
          backgroundColor: const Color(0xFFBC4749),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Stack(
          children: [
            // Boutons en haut à gauche
            Positioned(
              top: 12,
              left: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bouton de déconnexion
                  GestureDetector(
                onTap: _signOut,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF386641).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF386641),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Color(0xFF386641),
                    size: 24,
                  ),
                    ),
                  ),
                  
                  // Bouton développeur pour réinitialiser les vies (debug uniquement)
                  if (kDebugMode) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _resetVies,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBC4749).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBC4749),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Color(0xFFBC4749),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Icône de vie avec compteur en haut à droite
            Positioned(
              top: 4,
              right: 4,
              child: SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  children: [
                    // Icône de vie en arrière-plan
                    Image.asset(
                      'assets/Images/Bouton/Group 15.png',
                      width: 110,
                      height: 110,
                    ),
                    // Compteur de vies centré par-dessus
                    Positioned.fill(
                      child: Transform.translate(
                        offset: const Offset(15, 35), // Ajustement fin de la position verticale
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            _currentLives.toString(),
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 32,
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
            

            
            Padding(
              padding: const EdgeInsets.only(top: 50), // Ajoute 50px d'espace en haut
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12), // Réduit de 16 à 12
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 4),

                      ],
                    ),
                  ),
                  BiomeCarouselEnhanced(
                    onBiomeSelected: (biome) {
                      setState(() {
                        _selectedBiome = biome.name;
                      });
                      _loadMissionsForBiome(biome.name);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Expanded(
                            child: Stack(
                              children: [
                                ListView(
                                  controller: _missionScrollController,
                                  padding: const EdgeInsets.only(bottom: 20),
                                  children: [
                                    _buildQuizCards(),
                                    const SizedBox(height: 60),
                                  ],
                                ),
                                // Effet de fondu au bas de la liste
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 30,
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
                                // Effet de fondu en haut de la liste
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 25,
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
          ],
        ),
    );
  }



  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Les habitats',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF344356),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Le voyage ne fait que commencer...\nFaites défiler pour découvrir la suite des habitats.',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF344356),
            height: 1.4,
          ),
        ),
      ],
    );
  }



  Widget _buildQuizCards() {
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
            child: _buildQuizCardMission(mission),
          ),
        );
      }),
    );
  }

  Widget _buildQuizCardMission(Mission mission) {
    final hasCsvFile = mission.csvFile != null;
    final isUnlocked = mission.status == 'available';
    
    return _AnimatedMissionCard(
      mission: mission,
      hasCsvFile: hasCsvFile,
      isUnlocked: isUnlocked,
      onTap: (hasCsvFile && isUnlocked)
          ? () => _handleQuizLaunch(mission.id)
          : null,
      onMissionConsulted: () => _loadMissionsForBiome(_selectedBiome),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  color: Color(0xFF6A994E),
                  fontWeight: FontWeight.w600,
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

class _AnimatedMissionCard extends StatefulWidget {
  final Mission mission;
  final bool hasCsvFile;
  final bool isUnlocked;
  final VoidCallback? onTap;
  final VoidCallback? onMissionConsulted;

  const _AnimatedMissionCard({
    required this.mission,
    required this.hasCsvFile,
    required this.isUnlocked,
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
    
    // Animation de flottement pour le badge
    _badgeFloatController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    
    // Déclencher l'animation du badge si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_getAvailabilityText() != null) {
        _badgeAnimationController.forward().then((_) {
          // Démarrer l'animation de flottement seulement après l'apparition
          _badgeFloatController.repeat();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _badgeAnimationController.dispose();
    _badgeFloatController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      // Marquer la mission comme consultée de manière persistante
      // Dès qu'on clique sur une mission débloquée nouvellement (sans étoiles)
      if (widget.isUnlocked && widget.mission.lastStarsEarned == 0) {
        MissionPersistenceService.markMissionAsConsulted(widget.mission.id);
        // Notifier le parent pour recharger les missions
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
                  height: 88.0, // Hauteur fixe uniforme pour toutes les missions
                  margin: const EdgeInsets.only(bottom: 12), // Réduit de 16 à 12
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Padding réduit pour plus d'espace à l'icône
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: widget.isUnlocked 
                        ? Border.all(color: const Color(0xFF6A994E).withAlpha(77), width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Espacement pour déplacer l'icône vers la droite
                      const SizedBox(width: 4),
                      // Image de la mission
                      Container(
                        width: 64,
                        height: 64,
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
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback vers l'icône de cadenas si l'image ne charge pas
                                    return SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Icon(
                                        Icons.lock,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                    );
                                  },
                                )
                              : widget.mission.iconUrl != null
                                  ? Image.asset(
                                      widget.mission.iconUrl!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        // Fallback vers l'icône si l'image ne charge pas
                                        return SizedBox(
                                          width: 64,
                                          height: 64,
                                          child: Icon(
                                            Icons.quiz,
                                            color: const Color(0xFF6A994E),
                                            size: 32,
                                          ),
                                        );
                                      },
                                    )
                                  : SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Icon(
                                        Icons.quiz,
                                        color: const Color(0xFF6A994E),
                                        size: 32,
                                      ),
                                    ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: widget.isUnlocked 
                                    ? const Color(0xFF344356)
                                    : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Expanded(
                              child: Text(
                                widget.mission.sousTitre ?? 'Mission ${widget.mission.index} - ${widget.mission.milieu}',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 14.0, // Taille fixe
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
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      

                    ],
                  ),
                ),
                
                // Système d'étoiles positionné à droite de la case mission (seulement pour les missions débloquées)
                if (widget.isUnlocked)
                  Positioned(
                    top: 5, // Espace en haut similaire au padding de la case mission
                    bottom: 17, // Espace en bas similaire au padding de la case mission
                    right: 7, // Décalé vers la gauche pour plus d'espace avec le texte
                    child: Container(
                      width: 28,
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
                          // Première étoile
                          Transform.translate(
                            offset: const Offset(-0.8, 0),
                            child: Image.asset(
                              widget.mission.lastStarsEarned >= 1 
                                  ? 'assets/Images/Bouton/etoile_check.png'
                                  : 'assets/Images/Bouton/etoile-nocheck.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Deuxième étoile
                          Transform.translate(
                            offset: const Offset(-0.8, 0),
                            child: Image.asset(
                              widget.mission.lastStarsEarned >= 2 
                                  ? 'assets/Images/Bouton/etoile_check.png'
                                  : 'assets/Images/Bouton/etoile-nocheck.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Troisième étoile
                          Transform.translate(
                            offset: const Offset(-0.8, 0),
                            child: Image.asset(
                              widget.mission.lastStarsEarned >= 3 
                                  ? 'assets/Images/Bouton/etoile_check.png'
                                  : 'assets/Images/Bouton/etoile-nocheck.png',
                              width: 24,
                              height: 24,
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
                    top: -6, // Déborde légèrement au-dessus de la carte
                    right: 35, // Déplacé vers la gauche par rapport au bord droit
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_badgeAnimationController, _badgeFloatController]),
                      builder: (context, child) {
                        // Calcul du mouvement de flottement fluide
                        final floatValue = _badgeFloatController.value;
                        final floatOffset = math.sin(floatValue * 2 * math.pi) * 2; // Déplacement de ±2 pixels
                        // Zoom fluide sans paliers - utilise une fonction sinusoïdale lissée
                        final zoomScale = 1.0 - 0.015 * (math.sin(floatValue * 2 * math.pi) + 1) / 2;
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
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6A994E),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _getAvailabilityText()!,
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 12,
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
