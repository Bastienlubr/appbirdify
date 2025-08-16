import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../ui/responsive/responsive.dart';

// Clipper pour créer la forme arrondie du haut (identique au panel)
class _RoundedTopClipper extends CustomClipper<Path> {
  final double radius;

  const _RoundedTopClipper({required this.radius});

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Commence en bas à gauche
    path.moveTo(0, size.height);
    
    // Monte sur le côté gauche jusqu'au début de la courbe
    path.lineTo(0, radius);
    
    // Arc de cercle pour le coin gauche (identique au BorderRadius du panel)
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    
    // Ligne droite en haut (partie arrondie)
    path.lineTo(size.width - radius, 0);
    
    // Arc de cercle pour le coin droit (identique au BorderRadius du panel)
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    
    // Descend sur le côté droit
    path.lineTo(size.width, size.height);
    
    // Ligne droite en bas pour fermer
    path.lineTo(0, size.height);
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// -----------------------------------------------------------------------------
// Physique personnalisée pour un carrousel stable (limite l'inertie et l'effet
// ping-pong). On part de PageScrollPhysics pour garder le comportement natif,
// mais on resserre le ressort + plafonne la vélocité.
// -----------------------------------------------------------------------------
class StableCarouselPhysics extends PageScrollPhysics {
  const StableCarouselPhysics({super.parent});

  @override
  StableCarouselPhysics applyTo(ScrollPhysics? ancestor) {
    return StableCarouselPhysics(parent: buildParent(ancestor));
  }

    @override
  SpringDescription get spring => const SpringDescription(
        mass: 8.0,           // Équilibré pour fluidité constante
        stiffness: 1800.0,   // Rigidité optimisée pour tous les modes
        damping: 10.0,       // Amortissement parfait pour la fluidité
       );

  @override
  double carriedMomentum(double existingVelocity) {
    // Momentum ultra-réduit pour des transitions parfaitement contrôlées
    return existingVelocity * 0.01;
  }

  @override
  double get maxFlingVelocity => 120.0;  // Vitesse très limitée pour plus de contrôle

  @override
  double get minFlingVelocity => 500.0;  // Seuil élevé pour éviter les micro-mouvements
}

// -----------------------------------------------------------------------------
// BIRD DETAIL PAGE
// -----------------------------------------------------------------------------
class BirdDetailPage extends StatefulWidget {
  final Bird bird;
  
  const BirdDetailPage({super.key, required this.bird});

  @override
  State<BirdDetailPage> createState() => _BirdDetailPageState();
}

class _BirdDetailPageState extends State<BirdDetailPage>
    with TickerProviderStateMixin {
  // Panel
  late final AnimationController _panelController;
  late final Animation<double> _panelAnimation;

  // Contrôleurs de pages
  late final PageController _contentController; // contenu principal
  late final PageController _tabController; // carrousel d'onglets (infini)

  // États
  int _selectedTabIndex = 0;
  int _previousTabIndex = 0; // Pour animer la désélection
  bool _programmaticAnimating = false; // bloque les callbacks concurrents

  // Onglets (id, titre, icône, couleur)
  static const List<Map<String, dynamic>> _tabs = [
    {
      'id': 'identification',
      'title': 'Identification',
      'icon': Icons.search,
      'color': Color(0xFF606D7C),
    },
    {
      'id': 'habitat',
      'title': 'Habitat',
      'icon': Icons.landscape,
      'color': Color(0xFFABC270),
    },
    {
      'id': 'alimentation',
      'title': 'Alimentation',
      'icon': Icons.restaurant,
      'color': Color(0xFFFC826A),
    },
    {
      'id': 'reproduction',
      'title': 'Reproduction',
      'icon': Icons.favorite,
      'color': Color(0xFFF899D9),
    },
    {
      'id': 'repartition',
      'title': 'Répartition',
      'icon': Icons.public,
      'color': Color(0xFFFEC868),
    },
  ];

  int get _nTabs => _tabs.length;

  @override
  void initState() {
    super.initState();

    _panelController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOut,
    );

    // Écouter les changements du panel pour recentrer l'onglet
    _panelAnimation.addListener(_onPanelPositionChanged);

    // Démarre loin pour scroller dans les deux sens
    final seed = _nTabs * 1000;
    _contentController = PageController(initialPage: seed);
    _tabController = PageController(
      initialPage: seed,
      viewportFraction: 0.2,
    );

    // Position basse par défaut (panel = 1/3 visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _panelController.value = 0.0;
        // S'assurer que l'onglet initial est centré
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _forceRecenterSelectedTab();
            
            // Vérification périodique pour maintenir le centrage
            _startPeriodicCenteringCheck();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _panelAnimation.removeListener(_onPanelPositionChanged);
    _panelController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Vérification périodique pour maintenir le centrage parfait
  void _startPeriodicCenteringCheck() {
    if (!mounted) return;
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _tabController.hasClients && !_programmaticAnimating) {
        final isInBasicMode = _panelAnimation.value < 0.3;
        final isInExtendedMode = _panelAnimation.value > 0.7;
        final isInStableMode = isInBasicMode || isInExtendedMode;
        
        if (isInStableMode) {
          final targetPage = _nearestPageForIndex(_tabController, _selectedTabIndex);
          final currentPage = _tabController.page ?? _tabController.initialPage.toDouble();
          
          // Si pas parfaitement centré, correction douce
          if ((currentPage - targetPage).abs() > 0.15) {
            _tabController.animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            );
          }
        }
        
        // Relancer la vérification
        _startPeriodicCenteringCheck();
      }
    });
  }

  // Variables pour détecter les changements de mode
  bool _wasInExtendedMode = false;
  bool _wasInBasicMode = false;
  bool _isRecenteringScheduled = false;

  // Méthode appelée quand la position du panel change
  void _onPanelPositionChanged() {
    final isCurrentlyInBasicMode = _panelAnimation.value < 0.3; // Mode 2/3-1/3
    final isCurrentlyInExtendedMode = _panelAnimation.value > 0.7; // Mode étendu
    
    // Détecter TOUTE transition vers un mode stable (2/3-1/3 OU étendu)
    final shouldRecenter = (isCurrentlyInBasicMode && !_wasInBasicMode) || 
                          (isCurrentlyInExtendedMode && !_wasInExtendedMode);
    
    if (shouldRecenter && !_isRecenteringScheduled) {
      _isRecenteringScheduled = true;
      
      // Attendre que l'animation du panel soit complètement terminée
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _forceRecenterSelectedTab();
            _isRecenteringScheduled = false;
          }
        });
      });
    }
    
    // Mettre à jour les états précédents
    _wasInExtendedMode = isCurrentlyInExtendedMode;
    _wasInBasicMode = isCurrentlyInBasicMode;
  }

  // Recentrer l'onglet sélectionné dans le carousel (version douce)
  void _recenterSelectedTab() {
    if (!mounted || !_tabController.hasClients || _programmaticAnimating) return;
    
    // Calculer la page cible pour centrer l'onglet sélectionné
    final targetPage = _nearestPageForIndex(_tabController, _selectedTabIndex);
    
    // Vérifier si on a vraiment besoin de recentrer
    final currentPage = _tabController.page ?? _tabController.initialPage.toDouble();
    if ((currentPage - targetPage).abs() > 0.3) { // Seuil plus sensible pour recentrer plus souvent
      _programmaticAnimating = true;
      
      // Petit délai pour s'assurer que les autres animations sont terminées
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _tabController.hasClients) {
          _tabController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300), // Animation rapide mais douce
            curve: Curves.easeOutCubic,
          ).then((_) {
            if (mounted) _programmaticAnimating = false;
          });
        } else {
          _programmaticAnimating = false;
        }
      });
    }
  }

  // Forcer le recentrage (version robuste pour les transitions de mode)
  void _forceRecenterSelectedTab() {
    if (!mounted || !_tabController.hasClients) return;
    
    // Calculer la page cible pour centrer l'onglet sélectionné
    final targetPage = _nearestPageForIndex(_tabController, _selectedTabIndex);
    final currentPage = _tabController.page ?? _tabController.initialPage.toDouble();
    
    // TOUJOURS recentrer, même si ça semble proche
    if ((currentPage - targetPage).abs() > 0.1) {
      _programmaticAnimating = true;
      
      // Animation garantie vers la position centrale
      _tabController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      ).then((_) {
        if (mounted) {
          _programmaticAnimating = false;
          
          // Vérification finale - si toujours pas centré, utiliser jumpToPage
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _tabController.hasClients) {
              final finalPage = _tabController.page ?? _tabController.initialPage.toDouble();
              final finalTarget = _nearestPageForIndex(_tabController, _selectedTabIndex);
              if ((finalPage - finalTarget).abs() > 0.2) {
                _tabController.jumpToPage(finalTarget);
              }
            }
          });
        }
      });
    } else if ((currentPage - targetPage).abs() > 0.05) {
      // Petite correction avec jumpToPage si très proche mais pas parfait
      _tabController.jumpToPage(targetPage);
    }
  }

  // ------------------------------ LOGIQUE "NEAREST PAGE" ---------------------
  // Calcule la page cible la plus proche ayant (page % n == desiredIndex)
  int _nearestPageForIndex(PageController controller, int desiredIndex) {
    final double current =
        controller.hasClients ? (controller.page ?? controller.initialPage.toDouble())
                              : controller.initialPage?.toDouble() ?? 0.0;

    final int currentRound = current.round();
    final int currentMod = ((currentRound % _nTabs) + _nTabs) % _nTabs;

    int diff = desiredIndex - currentMod;
    // Normalise pour prendre le plus court chemin (wrap inclus)
    if (diff > _nTabs / 2) diff -= _nTabs;
    if (diff < -_nTabs / 2) diff += _nTabs;

    return currentRound + diff;
  }

  // ------------------------------ Sélection/Sync -----------------------------
  void _changeSelection(int newIndex) {
    if (newIndex != _selectedTabIndex) {
      setState(() {
        _previousTabIndex = _selectedTabIndex;
        _selectedTabIndex = newIndex;
      });
      
      // Recentrer l'onglet dans TOUS les modes stables AVEC délai pour éviter conflits
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          final isInBasicMode = _panelAnimation.value < 0.3;
          final isInExtendedMode = _panelAnimation.value > 0.7;
          final isInStableMode = isInBasicMode || isInExtendedMode;
          
          if (isInStableMode && mounted && !_programmaticAnimating && !_isRecenteringScheduled) {
            _forceRecenterSelectedTab(); // Version robuste pour tous les modes
          }
        });
      });
    }
  }

  // Quand on **fait défiler** les onglets - SIMPLE ET DIRECT
  void _onTabCarouselChanged(int pageIndex) {
    if (_programmaticAnimating) return;

    final actualIndex = pageIndex % _nTabs;
    final currentIndex = _selectedTabIndex;
    final diff = (actualIndex - currentIndex + _nTabs) % _nTabs;

    // Autorise les mouvements adjacents + wrap SEULEMENT
    if (diff == 1 || diff == (_nTabs - 1) || diff == 0) {
      _changeSelection(actualIndex);

      // Synchronise le contenu INSTANTANÉMENT - pas d'animation concurrente
      if (_contentController.hasClients) {
        final target = _nearestPageForIndex(_contentController, actualIndex);
        _contentController.jumpToPage(target);
      }
    } else if (diff != 0) {
      // Mouvement non autorisé → SNAP vers l'adjacent sans animation
      final targetIndex = diff <= _nTabs ~/ 2
          ? (currentIndex + 1) % _nTabs
          : (currentIndex - 1 + _nTabs) % _nTabs;

      _changeSelection(targetIndex);

      // SNAP instantané pour éviter le wiggle
      if (_contentController.hasClients) {
        final t = _nearestPageForIndex(_contentController, targetIndex);
        _contentController.jumpToPage(t);
      }

      if (_tabController.hasClients) {
        final t = _nearestPageForIndex(_tabController, targetIndex);
        _tabController.jumpToPage(t);
      }
    }
  }

  // Quand on **tape** un onglet - ANIMATION FLUIDE UNIQUE
  void _onTabSelected(int index) {
    if (_programmaticAnimating) return;

    final currentIndex = _selectedTabIndex;
    final diff = (index - currentIndex + _nTabs) % _nTabs;

    // Autorise adjacent + wrap
    if (diff == 1 || diff == (_nTabs - 1) || diff == 0) {
      _programmaticAnimating = true;
      _changeSelection(index);

      // Animation SIMULTANÉE des deux PageViews vers la même position
      final duration = const Duration(milliseconds: 280); // Synchronisé avec les onglets
      final curve = Curves.easeOutCubic; // Même courbe que les onglets

      List<Future> animations = [];

      // Contenu → page la plus proche
      if (_contentController.hasClients) {
        final t = _nearestPageForIndex(_contentController, index);
        animations.add(_contentController.animateToPage(t, duration: duration, curve: curve));
      }

      // Onglets → page la plus proche 
      if (_tabController.hasClients) {
        final t = _nearestPageForIndex(_tabController, index);
        animations.add(_tabController.animateToPage(t, duration: duration, curve: curve));
      }

      // Attendre que TOUTES les animations se terminent
      Future.wait(animations).whenComplete(() => _programmaticAnimating = false);
    } else {
      // Non autorisé → SNAP vers l'adjacent le plus cohérent
      final targetIndex = diff <= _nTabs ~/ 2
          ? (currentIndex + 1) % _nTabs
          : (currentIndex - 1 + _nTabs) % _nTabs;

      _changeSelection(targetIndex);

      // SNAP instantané pour éviter conflit
      if (_contentController.hasClients) {
        final t = _nearestPageForIndex(_contentController, targetIndex);
        _contentController.jumpToPage(t);
      }

      if (_tabController.hasClients) {
        final t = _nearestPageForIndex(_tabController, targetIndex);
        _tabController.jumpToPage(t);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final m = buildResponsiveMetrics(context, constraints);
          final screenHeight = constraints.maxHeight;

                      return Stack(
                     children: [
               // Image full screen
               _buildBackgroundImage(screenHeight),

               // Fade d'harmonisation image/panel (visible en mode 2/3-1/3 seulement)
               _buildImagePanelFade(m, screenHeight),

               // Bouton retour
               _buildBackButton(m),

                             

              // Panel
              AnimatedBuilder(
                animation: _panelAnimation,
                builder: (context, _) {
                  final initialPanelHeight = screenHeight * 0.33; // 1/3 visible
                  final maxPanelHeight = screenHeight * 0.95; // jusqu’à 95%
                  final currentPanelHeight = initialPanelHeight +
                      (_panelAnimation.value *
                          (maxPanelHeight - initialPanelHeight));

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: _togglePanel,
                      onPanUpdate: (details) {
                        final delta = -details.delta.dy / screenHeight;
                        final newValue = (_panelController.value + delta * 2)
                            .clamp(0.0, 1.0);
                        _panelController.value = newValue;
                      },
                      onPanEnd: _onPanelPanEnd,
                      child: Container(
                        width: double.infinity,
                        height: currentPanelHeight,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(65),
                            topRight: Radius.circular(65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 10,
                              offset: Offset(0, -5),
                              spreadRadius: 0,
                            )
                          ],
                        ),
                        child: _buildPanelContent(m),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Background image ------------------------------------------------------
  Widget _buildBackgroundImage(double screenHeight) {
    return Container(
      width: double.infinity,
      height: screenHeight,
        decoration: BoxDecoration(
        image: DecorationImage(
          image: widget.bird.urlImage.isNotEmpty
              ? NetworkImage(widget.bird.urlImage)
              : const NetworkImage("https://placehold.co/400x600"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // --- Back button -----------------------------------------------------------
  Widget _buildBackButton(ResponsiveMetrics m) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
          child: Container(
            width: m.dp(50, tabletFactor: 1.1),
            height: m.dp(50, tabletFactor: 1.1),
            decoration: BoxDecoration(
              color: const Color(0xFF473C33).withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: m.dp(24, tabletFactor: 1.1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Fade d'harmonisation image/panel (animation progressive) ---
  Widget _buildImagePanelFade(ResponsiveMetrics m, double screenHeight) {
    return AnimatedBuilder(
      animation: _panelAnimation,
      builder: (context, _) {
        // Calculer les positions du panel
        final initialPanelHeight = screenHeight * 0.33; // Position 2/3-1/3
        final maxPanelHeight = screenHeight * 0.95; // Position étendue
        final currentPanelHeight = initialPanelHeight +
            (_panelAnimation.value * (maxPanelHeight - initialPanelHeight));
        
        // Position du panel depuis le bas
        final panelTop = screenHeight - currentPanelHeight;
        
        // Opacité du fade : transition progressive et fluide
        final fadeOpacity = math.max(0.0, math.min(1.0, (1.0 - _panelAnimation.value) * 1.2));
        
        return Positioned(
          left: 0,
          right: 0,
          top: panelTop - m.dp(140, tabletFactor: 1.1), // Zone étendue
          height: m.dp(200, tabletFactor: 1.1), // Hauteur pour couvrir la transition
          child: AnimatedOpacity(
            opacity: fadeOpacity, // Animation automatique de l'opacité
            duration: const Duration(milliseconds: 150), // Transition douce
            curve: Curves.easeOut, // Courbe naturelle
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, // Complètement transparent en haut
                    const Color(0xFFAEB7C2).withValues(alpha: 0.1), // Très léger
                    const Color(0xFFAEB7C2).withValues(alpha: 0.2), // Subtil
                    const Color(0xFFAEB7C2).withValues(alpha: 0.4), // Progression douce
                    const Color(0xFFAEB7C2).withValues(alpha: 0.6), // Plus visible
                    const Color(0xFFAEB7C2).withValues(alpha: 0.8), // Fort
                    const Color(0xFFAEB7C2), // Opaque au niveau du panel
                  ],
                  stops: const [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0], // Transition ultra progressive
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // --- Panel content ---------------------------------------------------------
  Widget _buildPanelContent(ResponsiveMetrics m) {
    const textColor = Color(0xFF606D7C);

    final showBasicInfo = _panelAnimation.value < 0.3; // infos visibles en bas

    return Column(
      children: [
        // Poignée
        Container(
          width: m.dp(40, tabletFactor: 1.1),
          height: m.dp(4, tabletFactor: 1.0),
          margin: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
          decoration: BoxDecoration(
            color: const Color(0x70344356),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Contenu
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: m.dp(24, tabletFactor: 1.1),
              right: m.dp(24, tabletFactor: 1.1),
              top: showBasicInfo ? m.dp(4, tabletFactor: 1.0) : m.dp(16, tabletFactor: 1.0), // Plus d'espace en mode étendu pour les animations
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: showBasicInfo ? m.dp(2, tabletFactor: 1.0) : m.dp(0, tabletFactor: 1.0)), // Plus d'espace en mode étendu pour les animations

                // Infos de base (nom, famille) – visible en position basse
                AnimatedOpacity(
                  opacity: showBasicInfo ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350), // Plus fluide
                  curve: Curves.easeInOutCubic, // Courbe douce
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350), // Synchronisé
                    height: showBasicInfo ? null : 0,
                    child: showBasicInfo
                        ? _buildInfoSection(m)
                        : const SizedBox.shrink(),
                  ),
                ),

                if (showBasicInfo) SizedBox(height: m.dp(16, tabletFactor: 1.1)), // Moins d'espace entre infos et onglets en 2/3-1/3

                // Carrousel d'onglets avec remontée en mode étendu
                Transform.translate(
                  offset: Offset(0, showBasicInfo ? 0 : -m.dp(0, tabletFactor: 1.1)), // Remonte les onglets en mode étendu
                  child: _buildTabButtons(m),
                ),

                // Titre animé de l'onglet sélectionné (suit la remontée des onglets)
                Transform.translate(
                  offset: Offset(0, showBasicInfo ? -m.dp(16, tabletFactor: 1.0) : -m.dp(8, tabletFactor: 1.0)), // Ajustement selon le mode
                  child: _buildAnimatedTabTitle(m),
                ),

                SizedBox(height: showBasicInfo ? m.dp(12, tabletFactor: 1.1) : m.dp(4, tabletFactor: 1.1)), // Moins d'espace avant séparateur en mode étendu

                // Séparateur visible en mode étendu avec remontée
                Transform.translate(
                  offset: Offset(0, showBasicInfo ? 0 : -m.dp(12, tabletFactor: 1.1)), // Remonte la ligne en mode étendu
                  child: AnimatedOpacity(
                  opacity: showBasicInfo ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 400), // Plus long pour effet dramatique
                  curve: Curves.easeInOutQuart, // Courbe plus marquée
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400), // Synchronisé
                    height: showBasicInfo ? 0 : 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0x70344356),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  ),
                ),

                SizedBox(height: showBasicInfo ? 0 : m.dp(4, tabletFactor: 1.1)), // Moins d'espace avant titre principal en mode étendu

                // Titre principal de l'onglet courant
                Text(
                  _tabs[_selectedTabIndex]['title'],
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: textColor,
                    fontSize:
                        m.font(32, tabletFactor: 1.1, min: 24, max: 40),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: m.dp(16, tabletFactor: 1.1)),

                // Contenu principal (PageView synchronisé)
                _buildMainContent(m),

                SizedBox(height: m.dp(40, tabletFactor: 1.1)),
              ],
            ),
          ),
          ),
      ],
    );
  }

  Widget _buildInfoSection(ResponsiveMetrics m) {
    return Column(
      children: [
        _buildInfoRow(m, 'Nom', widget.bird.nomFr),
        SizedBox(height: m.dp(8, tabletFactor: 1.0)),
        _buildInfoRow(
            m, 'N. Scientifique', '${widget.bird.genus} ${widget.bird.species}'),
        SizedBox(height: m.dp(8, tabletFactor: 1.0)),
        _buildInfoRow(m, 'Famille', _familyName),
        SizedBox(height: m.dp(16, tabletFactor: 1.1)),
        Container(
          height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
            color: const Color(0x70344356),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ResponsiveMetrics m, String label, String value) {
    const labelColor = Color(0xFF606D7C);
    const valueColor = Color(0xFF606D7C);

    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        SizedBox(
          width: m.dp(125, tabletFactor: 1.1),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: labelColor,
              fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
          Text(
          ' : ',
          style: TextStyle(
            color: labelColor,
            fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w300,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w500,
            ),
            ),
          ),
        ],
    );
  }

  // --- Carrousel d'onglets avec effet fade sur les côtés ------------------
  Widget _buildTabButtons(ResponsiveMetrics m) {
    return SizedBox(
      height: m.dp(90, tabletFactor: 1.1), // Plus de hauteur pour les animations
      child: Stack(
        children: [
          // Le carousel principal
          PageView.builder(
            controller: _tabController,
            onPageChanged: _onTabCarouselChanged,
            physics: const StableCarouselPhysics(),
            pageSnapping: true,
            itemBuilder: (context, pageIndex) {
          final index = pageIndex % _nTabs;
          final tab = _tabs[index];
          final isSelected = index == _selectedTabIndex;
          final wasJustDeselected = index == _previousTabIndex;

          // Seulement les onglets impliqués dans le changement s'animent
          final shouldAnimate = isSelected || wasJustDeselected;

          return Center(
            child: GestureDetector(
              onTap: () => _onTabSelected(index),
              child: shouldAnimate
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey(
                          '$index-${isSelected ? "select" : "deselect"}'),
                      duration: const Duration(milliseconds: 280), // Plus fluide
                      curve: Curves.easeOutCubic, // Courbe plus naturelle
                      tween: Tween<double>(
                        begin: isSelected ? 0.0 : 1.0,
                        end: isSelected ? 1.0 : 0.0,
                      ),
                      builder: (context, animValue, child) {
                        // Calcul des valeurs interpolées optimisées pour la fluidité
                        final size = 60.0 + (6.0 * animValue); // 60 -> 66 simple
                        final iconSize = 28.0 + (3.0 * animValue); // 28 -> 31 plus modéré
                        final yOffset = -4.0 * animValue; // Montée simple et fluide
                        final colorAlpha = 0.3 + (0.7 * animValue); // 0.3 -> 1.0
                        final titleHeight = 6.0 * animValue; // 0 -> 6 simple
                        final shadowIntensity = 0.15 * animValue; // Ombre plus douce

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.translate(
                              offset: Offset(
                                  0.0, yOffset * m.dp(1, tabletFactor: 1.0)),
                              child: Container(
                                width: m.dp(size, tabletFactor: 1.1),
                                height: m.dp(size, tabletFactor: 1.1),
      decoration: BoxDecoration(
                                  color: (tab['color'] as Color)
                                      .withValues(alpha: colorAlpha),
                                  borderRadius: BorderRadius.circular(
                                    m.dp(16, tabletFactor: 1.0),
                                  ),
                                  boxShadow: animValue > 0.5
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: 0.15 * shadowIntensity),
                                            blurRadius: 4 + (2 * animValue), // Ombre plus douce
                                            offset: Offset(0, 2 + (1 * animValue)), // Se déplace moins
                                            spreadRadius: 0.5 * animValue, // S'étend moins
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  tab['icon'],
        color: Colors.white,
                                  size:
                                      m.dp(iconSize, tabletFactor: 1.1),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: m.dp(titleHeight, tabletFactor: 1.0),
                              child: animValue > 0.1
                                  ? Padding(
                                      padding: EdgeInsets.only(
                                          top: m.dp(6, tabletFactor: 1.0)),
                                      child: Opacity(
                                        opacity: animValue,
                                        child: Text(
                                          tab['title'],
            style: TextStyle(
                                            color: const Color(0x7F606D7C),
                                            fontSize: m.font(12,
                                                tabletFactor: 1.0,
                                                min: 10,
                                                max: 16),
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      },
                    )
                  :
                  // Onglets non impliqués : état statique
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
          Container(
                        width: m.dp(60, tabletFactor: 1.1),
                        height: m.dp(60, tabletFactor: 1.1),
            decoration: BoxDecoration(
                          color:
                              (tab['color'] as Color).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(
                            m.dp(16, tabletFactor: 1.0),
                          ),
                        ),
                        child: Icon(
                          tab['icon'],
                          color: Colors.white,
                          size: m.dp(28, tabletFactor: 1.1),
                        ),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
            ),
          );
        },
      ),
          
          // Masque fade gauche - couleur panel pour effet naturel
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: m.dp(40, tabletFactor: 1.1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFF3F5F9), // Couleur de fond du panel
                    const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.2],
                ),
              ),
            ),
          ),
          
          // Masque fade droite - couleur panel pour effet naturel
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: m.dp(40, tabletFactor: 1.1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    const Color(0xFFF3F5F9), // Couleur de fond du panel
                    const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Titre animé de l'onglet sélectionné - petit et toujours visible
  Widget _buildAnimatedTabTitle(ResponsiveMetrics m) {
    return SizedBox(
      height: m.dp(25, tabletFactor: 1.0), // Plus de hauteur pour éviter la coupure
      child: Align(
        alignment: Alignment.topCenter, // Colle en haut du conteneur
        child: TweenAnimationBuilder<double>(
          key: ValueKey('title-$_selectedTabIndex-${_previousTabIndex}'),
          duration: const Duration(milliseconds: 280), // Synchronisé avec les onglets
          curve: Curves.easeOutCubic, // Même courbe que les onglets
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, animValue, child) {
            // Animation entrante optimisée pour fluidité maximale
            final opacity = animValue; // Animation simple et fluide
            final yOffset = 8.0 * (1.0 - animValue); // Descente simple et douce
            final scale = 0.85 + (0.15 * animValue); // Scaling modéré

            return Transform.translate(
              offset: Offset(0.0, yOffset),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    _tabs[_selectedTabIndex]['title'],
                    textAlign: TextAlign.center,
      style: TextStyle(
                      color: const Color(0x7F606D7C), // Même couleur que sous les onglets
                      fontSize: m.font(12, tabletFactor: 1.0, min: 10, max: 16), // Plus petit
        fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w900, // Même poids que sous les onglets
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Contenu principal synchronisé ----------------------------------------
  Widget _buildMainContent(ResponsiveMetrics m) {
    final showBasicInfo = _panelAnimation.value < 0.3;
    final baseHeight =
        showBasicInfo ? m.dp(300, tabletFactor: 1.2) : m.dp(400, tabletFactor: 1.2);

    return SizedBox(
      height: baseHeight,
      child: PageView.builder(
        controller: _contentController,
                 onPageChanged: (pageIndex) {
           if (_programmaticAnimating) return; // éviter ping-pong

           final actualIndex = pageIndex % _nTabs;
           final currentIndex = _selectedTabIndex;
           final diff = (actualIndex - currentIndex + _nTabs) % _nTabs;

           // Autorise adjacent + wrap SEULEMENT
           if (diff == 1 || diff == (_nTabs - 1) || diff == 0) {
             _changeSelection(actualIndex);

             // Synchronise l'onglet INSTANTANÉMENT
             if (_tabController.hasClients) {
               final t = _nearestPageForIndex(_tabController, actualIndex);
               _tabController.jumpToPage(t);
             }
           } else if (diff != 0) {
             // Mouvement non autorisé → SNAP vers l'adjacent
             final targetIndex = diff <= _nTabs ~/ 2
                 ? (currentIndex + 1) % _nTabs
                 : (currentIndex - 1 + _nTabs) % _nTabs;

             _changeSelection(targetIndex);

             // SNAP instantané pour éviter le wiggle
             final t = _nearestPageForIndex(_contentController, targetIndex);
             _contentController.jumpToPage(t);

             if (_tabController.hasClients) {
               final tt = _nearestPageForIndex(_tabController, targetIndex);
               _tabController.jumpToPage(tt);
             }
           }
         },
        // itemCount null => "infini"
        itemCount: null,
        itemBuilder: (context, pageIndex) {
          final index = pageIndex % _nTabs;
          return _buildContentForTab(m, index);
        },
      ),
    );
  }

  Widget _buildContentForTab(ResponsiveMetrics m, int index) {
    final showBasicInfo = _panelAnimation.value < 0.3;

    Widget content;
    switch (_tabs[index]['id']) {
      case 'identification':
        content = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    'Chez nous en Europe, cet oiseau de la taille d\'un geai est unique et inconfondable. '
                    'Quand on observe un ${widget.bird.nomFr}, on voit un oiseau bleu. En effet chez lui, la tête, les ',
                style: _contentTextStyle(m),
              ),
              TextSpan(
                text: 'ailes',
                style: _contentTextStyle(m, underline: true),
              ),
              TextSpan(
                text:
                    ' et toutes les parties inférieures sont d\'un bleu aigue-marine, tout au moins chez l\'adulte. '
                    'En vol, c\'est le festival de couleurs car s\'ajoute au panel le noir ou le bleu des ',
                style: _contentTextStyle(m),
              ),
              TextSpan(
                text: 'rémiges',
                style: _contentTextStyle(m, underline: true),
              ),
              TextSpan(
                text:
                    ' suivant qu\'on l\'observe en vol de dessus ou de dessous. La tête est barrée latéralement de noir. Les ',
                style: _contentTextStyle(m),
              ),
              TextSpan(
                text: 'pattes',
                style: _contentTextStyle(m, underline: true),
              ),
              TextSpan(
                text: ' sont rosées. Les sexes sont semblables.',
                style: _contentTextStyle(m),
              ),
            ],
          ),
        );
        break;
      default:
        content = Text(
          'Informations sur ${_tabs[index]['title'].toString().toLowerCase()} du ${widget.bird.nomFr}. '
          'Ces données seront complétées avec les informations spécifiques à chaque espèce.',
          style: _contentTextStyle(m),
        );
        break;
    }

    if (showBasicInfo) {
      return content; // pas de scroll interne, panel gère le scroll
    } else {
      return SingleChildScrollView(child: content);
    }
  }

  TextStyle _contentTextStyle(ResponsiveMetrics m, {bool underline = false}) {
    return TextStyle(
      color: const Color(0xFF606D7C),
      fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
      fontFamily: 'Quicksand',
      fontWeight: FontWeight.w500,
      decoration: underline ? TextDecoration.underline : null,
      height: 1.4,
    );
  }

  // --- Helpers panel ---------------------------------------------------------
  void _togglePanel() {
    if (_panelController.value < 0.5) {
      _panelController.animateTo(1.0,
          duration: const Duration(milliseconds: 420), // Plus fluide
          curve: Curves.easeOutBack); // Effet rebond élégant
    } else {
      _panelController.animateTo(0.0,
          duration: const Duration(milliseconds: 380), // Légèrement plus rapide pour fermer
          curve: Curves.easeInBack); // Effet d'aspiration
    }
  }

  void _onPanelPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity.abs() > 500) {
      if (velocity < 0) {
        _panelController.animateTo(1.0,
            duration: const Duration(milliseconds: 380), // Plus fluide
            curve: Curves.easeOutBack); // Rebond pour ouverture rapide
      } else {
        _panelController.animateTo(0.0,
            duration: const Duration(milliseconds: 320), // Plus fluide
            curve: Curves.easeOutQuart); // Fermeture douce
      }
    } else {
      if (_panelController.value < 0.5) {
        _panelController.animateTo(0.0,
            duration: const Duration(milliseconds: 350), // Plus fluide
            curve: Curves.easeInOutCubic); // Transition douce
      } else {
        _panelController.animateTo(1.0,
            duration: const Duration(milliseconds: 350), // Plus fluide
            curve: Curves.easeInOutCubic); // Transition douce
      }
    }
  }

  String get _familyName => '${widget.bird.genus}idés';
}
