import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/biome_carousel_enhanced.dart';
import '../data/milieu_data.dart';
import '../models/mission.dart';
import '../pages/quiz_page.dart'; // Added import for QuizPage
import '../pages/auth/login_screen.dart';
import '../services/life_sync_service.dart';
import '../services/life_system_test.dart';
import '../services/mission_loader_service.dart';
import '../services/mission_view_service.dart';


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
  
  // Gestion des vies
  int _currentLives = 5;


  @override
  void initState() {
    super.initState();
    _missionScrollController = ScrollController();
    _loadMissionsForBiome(_selectedBiome);
    _loadCurrentLives();
  }

  /// Charge les vies actuelles depuis Firestore et vérifie la réinitialisation quotidienne
  Future<void> _loadCurrentLives() async {
    try {
      final uid = LifeSyncService.getCurrentUserId();
      if (uid != null) {
        final lives = await LifeSyncService.checkAndResetLives(uid);
        if (mounted) {
          setState(() {
            _currentLives = lives;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des vies: $e');
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
    try {
      // Charger les missions depuis le CSV
      final List<Mission> allMissions = await MissionLoaderService.loadMissionsForBiome(biomeName.toLowerCase());
      
      // Filtrer et organiser les missions selon les critères
      final List<Mission> filteredMissions = _filterAndOrganizeMissions(allMissions);
      
      if (mounted) {
        setState(() {
          _currentMissions = filteredMissions;
          _missionVisibility = List.generate(filteredMissions.length, (index) => false);
        });
        
        // Réinitialiser la position du scroll vers le haut
        _missionScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        
        // Animer l'apparition des missions une par une
        // Délai initial de 100ms avant la première mission, puis 150ms entre chaque mission
        for (int i = 0; i < filteredMissions.length; i++) {
          Future.delayed(Duration(milliseconds: 100 + (i * 150)), () {
            if (mounted && _selectedBiome == biomeName) {
              setState(() {
                if (i < _missionVisibility.length) {
                  _missionVisibility[i] = true;
                }
              });
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors du chargement des missions: $e');
      // En cas d'erreur, utiliser les missions statiques comme fallback
      final missions = missionsParBiome[biomeName] ?? [];
      setState(() {
        _currentMissions = missions;
        _missionVisibility = List.generate(missions.length, (index) => false);
      });
    }
  }

  /// Filtre et organise les missions selon les critères de déverrouillage
  List<Mission> _filterAndOrganizeMissions(List<Mission> allMissions) {
    final List<Mission> filteredMissions = [];
    
    // Trier les missions par niveau
    allMissions.sort((a, b) => a.index.compareTo(b.index));
    
    for (final mission in allMissions) {
      // Cacher les missions de niveau > 2 si la précédente n'est pas déverrouillée
      if (mission.index > 2) {
        final previousMission = allMissions.where((m) => m.index == mission.index - 1).firstOrNull;
        if (previousMission != null && previousMission.status == 'locked') {
          continue;
        }
      }
      
      // Ajouter toutes les missions visibles (déverrouillées ET verrouillées visibles)
      filteredMissions.add(mission);
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
                            child: ListView(
                              controller: _missionScrollController,
                              padding: const EdgeInsets.only(bottom: 20),
                              children: [
                                _buildQuizCards(),
                                const SizedBox(height: 60),
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
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(missionId: missionId),
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

  const _AnimatedMissionCard({
    required this.mission,
    required this.hasCsvFile,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  State<_AnimatedMissionCard> createState() => _AnimatedMissionCardState();
}

class _AnimatedMissionCardState extends State<_AnimatedMissionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // État local pour tracker si la mission a été vue
  bool _hasBeenSeen = false;
  bool _isLoadingViewedState = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Charger l'état "vu" depuis SharedPreferences
    _loadViewedState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Charge l'état "vu" depuis SharedPreferences
  Future<void> _loadViewedState() async {
    try {
      final isViewed = await MissionViewService.isMissionViewed(widget.mission.id);
      if (mounted) {
        setState(() {
          _hasBeenSeen = isViewed;
          _isLoadingViewedState = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors du chargement de l\'état vu pour ${widget.mission.id}: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingViewedState = false;
        });
      }
    }
  }

  void _handleTap() async {
    if (widget.onTap != null) {
      // Marquer la mission comme vue lors du premier clic
      if (widget.isUnlocked && !_hasBeenSeen) {
        await MissionViewService.markMissionAsViewed(widget.mission.id);
        setState(() {
          _hasBeenSeen = true;
        });
      }
      
      _animationController.forward().then((_) {
        _animationController.reverse();
        widget.onTap!();
      });
    }
  }

  /// Détermine le texte à afficher selon l'état de la mission
  String? _getAvailabilityText() {
    // Si on est encore en train de charger l'état, ne rien afficher
    if (_isLoadingViewedState) {
      return null;
    }
    
    // Si la mission a déjà été vue, ne rien afficher
    if (_hasBeenSeen) {
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
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12), // Réduit de 16 à 12
                  padding: const EdgeInsets.all(12), // Réduit de 16 à 12
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
          // Image de la mission
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isUnlocked 
                  ? const Color(0xFFF2E8CF)
                  : Colors.grey.withAlpha(77),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.mission.iconUrl != null
                  ? Image.asset(
                      widget.mission.iconUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback vers l'icône si l'image ne charge pas
                        return Icon(
                          widget.isUnlocked ? Icons.quiz : Icons.lock,
                          color: widget.isUnlocked 
                              ? const Color(0xFF6A994E)
                              : Colors.grey,
                          size: 22,
                        );
                      },
                    )
                  : Icon(
                      widget.isUnlocked ? Icons.quiz : Icons.lock,
                      color: widget.isUnlocked 
                          ? const Color(0xFF6A994E)
                          : Colors.grey,
                      size: 22,
                    ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Contenu texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
                const SizedBox(height: 4),
                Text(
                  widget.mission.sousTitre ?? 'Mission ${widget.mission.index} - ${widget.mission.milieu}',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.isUnlocked 
                        ? const Color(0xFF344356).withAlpha(179)
                        : Colors.grey,
                  ),
                ),
                if (!widget.isUnlocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Mission verrouillée',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      
      // Nouvel indicateur "NOUVEAU" positionné en haut à droite
      if (_getAvailabilityText() != null)
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6A994E),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              _getAvailabilityText()!,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
}
