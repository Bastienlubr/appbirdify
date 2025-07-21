import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/biome_carousel_enhanced.dart';
import '../data/milieu_data.dart';
import '../models/mission.dart';
import '../pages/quiz_page.dart'; // Added import for QuizPage
import '../widgets/lives_display_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _missionScrollController = ScrollController();
    _loadMissionsForBiome(_selectedBiome);
  }

  @override
  void dispose() {
    _missionScrollController.dispose();
    super.dispose();
  }

  void _loadMissionsForBiome(String biomeName) {
    final missions = missionsParBiome[biomeName] ?? [];
    setState(() {
      _currentMissions = missions;
      _missionVisibility = List.generate(missions.length, (index) => false);
    });
    
    // Réinitialiser la position du scroll vers le haut
    _missionScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    
    // Animer l'apparition des missions une par une
    // Délai initial de 100ms avant la première mission, puis 150ms entre chaque mission
    for (int i = 0; i < missions.length; i++) {
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

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      
      // Navigation vers l'écran de connexion
      final navigator = Navigator.of(context);
      navigator.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
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
            // Bouton de déconnexion en haut à gauche
            Positioned(
              top: 12,
              left: 24,
              child: GestureDetector(
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
            // Bloc de compteurs et mascotte en haut à droite
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 24), // Réduit de 16 à 12
                child: _buildStatsBlock(),
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

  Widget _buildStatsBlock() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Fond du rectangle - plus petit et à droite
        Positioned(
          right: -35,
          top: -28,
          child: Image.asset(
            'assets/Images/Bouton/caseviestrick.png',
            width: 150,  // Plus petit
            height: 150,  // Plus petit
          ),
        ),
        // Contenu des compteurs - Streak
        Positioned(
          right: 20,  // Contrôlez la position gauche/droite du streak
          top: 36,    // Contrôlez la position haut/bas du streak
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/Images/Bouton/strick.png',
                width: 30,  // Contrôlez la taille du streak
                height: 30,  // Contrôlez la taille du streak
              ),
              const SizedBox(width: 2),
              const Text(
                '2',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 24,  // Contrôlez la taille du texte streak
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF473C33),
                ),
              ),
            ],
          ),
        ),
        // Contenu des compteurs - Vies
        Positioned(
          right: 20,  // Contrôlez la position gauche/droite des vies
          top: 65,    // Contrôlez la position haut/bas des vies
          child: const LivesStatsWidget(),
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
    
    return _AnimatedMissionCard(
      mission: mission,
      hasCsvFile: hasCsvFile,
      onTap: hasCsvFile
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizPage(missionId: mission.csvFile!),
                ),
              );
            }
          : null,
    );
  }
}

class _AnimatedMissionCard extends StatefulWidget {
  final Mission mission;
  final bool hasCsvFile;
  final VoidCallback? onTap;

  const _AnimatedMissionCard({
    required this.mission,
    required this.hasCsvFile,
    this.onTap,
  });

  @override
  State<_AnimatedMissionCard> createState() => _AnimatedMissionCardState();
}

class _AnimatedMissionCardState extends State<_AnimatedMissionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      _animationController.forward().then((_) {
        _animationController.reverse();
        widget.onTap!();
      });
    }
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
            child: Container(
      margin: const EdgeInsets.only(bottom: 12), // Réduit de 16 à 12
      padding: const EdgeInsets.all(12), // Réduit de 16 à 12
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
                border: widget.hasCsvFile 
                    ? Border.all(color: const Color(0xFF6A994E).withValues(alpha: 0.3), width: 1)
                    : null,
      ),
      child: Row(
        children: [
                  // Icône de mission
          Container(
            width: 44, // Réduit de 48 à 44
            height: 44, // Réduit de 48 à 44
            decoration: BoxDecoration(
                      color: widget.hasCsvFile 
                          ? const Color(0xFFF2E8CF)
                          : Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                      widget.hasCsvFile ? Icons.quiz : Icons.lock,
                      color: widget.hasCsvFile 
                          ? const Color(0xFF6A994E)
                          : Colors.grey,
              size: 22, // Réduit de 24 à 22
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Contenu texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                          widget.mission.title ?? 'Mission ${widget.mission.index}',
                          style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                            color: widget.hasCsvFile 
                                ? const Color(0xFF344356)
                                : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                          'Mission ${widget.mission.index} - ${widget.mission.milieu}',
                          style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                            color: widget.hasCsvFile 
                                ? const Color(0xFF344356).withValues(alpha: 0.7)
                                : Colors.grey,
                          ),
                        ),
                        if (!widget.hasCsvFile) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Bientôt disponible',
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
          
                  // Indicateur de disponibilité
                  if (widget.hasCsvFile)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A994E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Disponible',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6A994E),
              ),
            ),
          ),
        ],
      ),
            ),
          ),
        );
      },
    );
  }
}
