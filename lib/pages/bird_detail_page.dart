import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../ui/responsive/responsive.dart';
import '../models/fiche_oiseau.dart';
import '../services/fiche_oiseau_service.dart';

// (supprimé) _RoundedTopClipper non utilisé

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

  // Données Firestore (fiche)
  FicheOiseau? _fiche;
  bool _ficheLoading = false;
  StreamSubscription<FicheOiseau?>? _ficheSubscription;
  StreamSubscription<FicheOiseau?>? _ficheFrSubscription;
  StreamSubscription<FicheOiseau?>? _ficheAppIdSubscription;

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
      'title': 'Protection et état actuel',
      'icon': Icons.security,
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
        Future.delayed(const Duration(milliseconds: 200), () async {
          if (!mounted) return;
          _forceRecenterSelectedTab();
          _startPeriodicCenteringCheck();

          // Écouter la fiche Firestore via appId (prioritaire) puis noms
          _startWatchingFiche();
        });
      }
    });
  }

  // (supprimé) _loadFiche non utilisé

  void _startWatchingFiche() {
    if (_ficheLoading) return;
    setState(() => _ficheLoading = true);

    final nomScientifique = '${widget.bird.genus} ${widget.bird.species}';
    final nomFrancais = widget.bird.nomFr;
    final appId = '${widget.bird.genus.toLowerCase()}_${widget.bird.species.toLowerCase()}';

    _ficheSubscription?.cancel();
    _ficheFrSubscription?.cancel();
    _ficheAppIdSubscription?.cancel();

    bool received = false;

    // 1) appId prioritaire
    _ficheAppIdSubscription = FicheOiseauService
        .watchFicheByAppId(appId)
        .listen((fiche) {
      if (!mounted || fiche == null) return;
      // Debug: log réception fiche par appId
      try {
        final idLen = fiche.identification.description?.length ?? 0;
        final habLen = fiche.habitat.description?.length ?? 0;
        final alimLen = fiche.alimentation.description?.length ?? 0;
        final reproLen = fiche.reproduction.description?.length ?? 0;
        final repLen = fiche.protectionEtatActuel?.description?.length ?? 0;
        // ignore: avoid_print
        print('📥 Fiche reçue (appId=$appId): id=$idLen, hab=$habLen, alim=$alimLen, repro=$reproLen, prot=$repLen');
      } catch (_) {}
      if (!received) received = true;
      setState(() {
        _fiche = fiche;
        _ficheLoading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _ficheLoading = false);
    });

    // 2) Fallbacks par noms
    _ficheSubscription = FicheOiseauService
        .watchFicheByNomScientifique(nomScientifique)
        .listen((fiche) {
      if (!mounted || fiche == null || received) return;
      // Debug: log réception fiche par nom scientifique
      try {
        final idLen = fiche.identification.description?.length ?? 0;
        final habLen = fiche.habitat.description?.length ?? 0;
        final alimLen = fiche.alimentation.description?.length ?? 0;
        final reproLen = fiche.reproduction.description?.length ?? 0;
        final repLen = fiche.protectionEtatActuel?.description?.length ?? 0;
        // ignore: avoid_print
        print('📥 Fiche reçue (nomSci=$nomScientifique): id=$idLen, hab=$habLen, alim=$alimLen, repro=$reproLen, prot=$repLen');
      } catch (_) {}
      received = true;
      setState(() {
        _fiche = fiche;
        _ficheLoading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _ficheLoading = false);
    });

    _ficheFrSubscription = FicheOiseauService
        .watchFicheByNomFrancais(nomFrancais)
        .listen((fiche) {
      if (!mounted || fiche == null || received) return;
      // Debug: log réception fiche par nom français
      try {
        final idLen = fiche.identification.description?.length ?? 0;
        final habLen = fiche.habitat.description?.length ?? 0;
        final alimLen = fiche.alimentation.description?.length ?? 0;
        final reproLen = fiche.reproduction.description?.length ?? 0;
        final repLen = fiche.protectionEtatActuel?.description?.length ?? 0;
        // ignore: avoid_print
        print('📥 Fiche reçue (nomFr=$nomFrancais): id=$idLen, hab=$habLen, alim=$alimLen, repro=$reproLen, prot=$repLen');
      } catch (_) {}
      received = true;
      setState(() {
        _fiche = fiche;
        _ficheLoading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _ficheLoading = false);
    });
  }

  @override
  void dispose() {
    _panelAnimation.removeListener(_onPanelPositionChanged);
    _panelController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    _ficheSubscription?.cancel();
    _ficheFrSubscription?.cancel();
    _ficheAppIdSubscription?.cancel();
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
          
          if ((currentPage - targetPage).abs() > 0.15) {
            _tabController.animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            );
          }
        }
        _startPeriodicCenteringCheck();
      }
    });
  }

  // Variables pour détecter les changements de mode
  bool _wasInExtendedMode = false;
  bool _wasInBasicMode = false;
  bool _isRecenteringScheduled = false;
  bool _miniTitleHidden = false;

  // Méthode appelée quand la position du panel change
  void _onPanelPositionChanged() {
    final isCurrentlyInBasicMode = _panelAnimation.value < 0.3; // Mode 2/3-1/3
    final isCurrentlyInExtendedMode = _panelAnimation.value > 0.7; // Mode étendu
    // Disparition progressive du petit titre après 5s en mode étendu
    if (isCurrentlyInExtendedMode && !_wasInExtendedMode) {
      _miniTitleHidden = false;
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_panelAnimation.value > 0.7) {
          setState(() => _miniTitleHidden = true);
        }
      });
    }
    if (!isCurrentlyInExtendedMode && _miniTitleHidden) {
      setState(() => _miniTitleHidden = false);
    }
    
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
  // (supprimé) _recenterSelectedTab non utilisé

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
                              : controller.initialPage.toDouble();

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
        // Réaffiche le petit titre à chaque switch d'onglet; il sera masqué à nouveau au bout de 5s en mode étendu
        _miniTitleHidden = false;
      });

      // Si on est déjà en mode étendu, reprogrammer la disparition du petit titre après 3s
      if (_panelAnimation.value > 0.7) {
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          if (_panelAnimation.value > 0.7) {
            setState(() => _miniTitleHidden = true);
          }
        });
      }
      
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

               // (Titre overlay supprimé, le titre revient dans le panel)

                              

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
          image: (_fiche?.medias.imagePrincipale != null && _fiche!.medias.imagePrincipale!.isNotEmpty)
              ? NetworkImage(_fiche!.medias.imagePrincipale!)
              : (widget.bird.urlImage.isNotEmpty
                  ? NetworkImage(widget.bird.urlImage)
                  : const NetworkImage("https://placehold.co/400x600")),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // _buildCenteredHeroTitle supprimé (titre géré dans le panel)

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
              top: showBasicInfo ? m.dp(4, tabletFactor: 1.0) : m.dp(16, tabletFactor: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: showBasicInfo ? m.dp(2, tabletFactor: 1.0) : m.dp(0, tabletFactor: 1.0)),

                // Infos de base (nom, famille)
                AnimatedOpacity(
                  opacity: showBasicInfo ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: showBasicInfo ? null : 0,
                    child: showBasicInfo
                        ? _buildInfoSection(m)
                        : const SizedBox.shrink(),
                  ),
                ),

                if (showBasicInfo) SizedBox(height: m.dp(16, tabletFactor: 1.1)),

                // Carrousel d'onglets
                Transform.translate(
                  offset: Offset(0, showBasicInfo ? 0 : -m.dp(0, tabletFactor: 1.1)),
                  child: _buildTabButtons(m),
                ),

                Transform.translate(
                  offset: Offset(0, showBasicInfo ? -m.dp(16, tabletFactor: 1.0) : -m.dp(8, tabletFactor: 1.0)),
                  child: _buildAnimatedTabTitle(m),
                ),

                SizedBox(height: showBasicInfo ? m.dp(12, tabletFactor: 1.1) : m.dp(4, tabletFactor: 1.1)),

                Transform.translate(
                  offset: Offset(0, showBasicInfo ? 0 : -m.dp(12, tabletFactor: 1.1)),
                  child: AnimatedOpacity(
                  opacity: showBasicInfo ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutQuart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: showBasicInfo ? 0 : 3,
              width: double.infinity,
              decoration: BoxDecoration(
                      color: const Color(0x70344356),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  ),
                ),

                SizedBox(height: showBasicInfo ? 0 : m.dp(4, tabletFactor: 1.1)),

                // Titre principal de l'onglet courant (dans le panel, en haut)
                Align(
                  alignment: _panelAnimation.value > 0.7 ? Alignment.center : Alignment.centerLeft,
                        child: Text(
                    _tabs[_selectedTabIndex]['title'],
                    textAlign: _panelAnimation.value > 0.7 ? TextAlign.center : TextAlign.left,
                          style: TextStyle(
                      color: textColor,
                      fontSize: m.font(32, tabletFactor: 1.1, min: 24, max: 40),
                            fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w900,
                    ),
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
        _buildInfoRow(m, 'Nom', _fiche?.nomFrancais.isNotEmpty == true ? _fiche!.nomFrancais : widget.bird.nomFr),
        SizedBox(height: m.dp(8, tabletFactor: 1.0)),
        _buildInfoRow(
            m, 'N. Scientifique', _fiche?.nomScientifique.isNotEmpty == true ? _fiche!.nomScientifique : '${widget.bird.genus} ${widget.bird.species}'),
        SizedBox(height: m.dp(8, tabletFactor: 1.0)),
        _buildInfoRow(m, 'Famille', _fiche?.famille.isNotEmpty == true ? _fiche!.famille : _familyName),
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
                          '$index-${isSelected ? "select" : "deselect"}')
,
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

  // Titre animé de l'onglet sélectionné - petit et toujours visible (disparaît après un délai en mode étendu)
  Widget _buildAnimatedTabTitle(ResponsiveMetrics m) {
    return SizedBox(
      height: m.dp(25, tabletFactor: 1.0), // Plus de hauteur pour éviter la coupure
      child: Align(
        alignment: Alignment.topCenter, // Colle en haut du conteneur
        child: TweenAnimationBuilder<double>(
          key: ValueKey('title-$_selectedTabIndex-$_previousTabIndex'),
          duration: const Duration(milliseconds: 280), // Synchronisé avec les onglets
          curve: Curves.easeOutCubic, // Même courbe que les onglets
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, animValue, child) {
            // Animation entrante optimisée pour fluidité maximale
            final opacity = animValue; // Animation simple et fluide
            final yOffset = 8.0 * (1.0 - animValue); // Descente simple et douce
            final scale = 0.85 + (0.15 * animValue); // Scaling modéré
 
            return AnimatedOpacity(
              opacity: _miniTitleHidden ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: Transform.translate(
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
        showBasicInfo ? m.dp(360, tabletFactor: 1.2) : m.dp(520, tabletFactor: 1.2);

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
        final id = _fiche?.identification;
        final mesures = id?.mesures;
        final ressemblantes = id?.especesRessemblantes;
        final tiles = <Widget>[];
        if ((mesures?.poids?.isNotEmpty ?? false) || (mesures?.taille?.isNotEmpty ?? false) || (mesures?.envergure?.isNotEmpty ?? false)) {
          tiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (mesures?.poids?.isNotEmpty ?? false)
                    _miniInfoCard(title: 'Poids', value: mesures!.poids!, m: m),
                  if (mesures?.taille?.isNotEmpty ?? false)
                    _miniInfoCard(title: 'Taille', value: mesures!.taille!, m: m),
                  if (mesures?.envergure?.isNotEmpty ?? false)
                    _miniInfoCard(title: 'Envergure', value: mesures!.envergure!, m: m),
                ],
              ),
            ),
          );
        }
        if ((ressemblantes?.exemples.isNotEmpty ?? false) || (ressemblantes?.differenciation?.isNotEmpty ?? false)) {
          tiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Espèces ressemblantes', style: _subtitleTextStyle(m)),
                const SizedBox(height: 6),
                if (ressemblantes?.exemples.isNotEmpty ?? false)
                  Text('Exemples: ${ressemblantes!.exemples.join(', ')}', style: _contentTextStyle(m)),
                if (ressemblantes?.differenciation?.isNotEmpty ?? false)
                  Text('À ne pas confondre: ${ressemblantes!.differenciation}', style: _contentTextStyle(m)),
              ]),
            ),
          );
        }
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Classification', style: _subtitleTextStyle(m)),
          const SizedBox(height: 6),
          Text(_buildClassificationSentence(), style: _contentTextStyle(m)),
          const SizedBox(height: 12),
          Text('Morphologie', style: _subtitleTextStyle(m)),
          if ((id?.morphologie?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(id!.morphologie!, style: _contentTextStyle(m)),
            ),
          if (!(id?.morphologie?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Description morphologique à venir.', style: _contentTextStyle(m)),
            ),
          ...tiles,
        ]);
        break;
      case 'habitat':
        final h = _fiche?.habitat;
        final milieux = h?.milieux ?? const <String>[];
        final descriptionHab = h?.description ?? '';
        final zones = h?.zonesObservation ?? '';
        final mig = h?.migration;
        final mois = mig?.mois;
        final migTiles = <Widget>[];
        if ((mois?.debut?.isNotEmpty ?? false) || (mois?.fin?.isNotEmpty ?? false)) {
          migTiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                if (mois?.debut?.isNotEmpty ?? false) _miniInfoCard(title: 'Début', value: mois!.debut!, m: m),
                if (mois?.fin?.isNotEmpty ?? false) _miniInfoCard(title: 'Fin', value: mois!.fin!, m: m),
              ]),
            ),
          );
        }
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Type de milieu', style: _subtitleTextStyle(m)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_buildTypeMilieuText(milieux, descriptionHab, h?.altitude), style: _contentTextStyle(m)),
          ),
          if (zones.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Où l\'observer', style: _subtitleTextStyle(m))),
          if (zones.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(zones, style: _contentTextStyle(m))),
          if ((mig?.description?.isNotEmpty ?? false)) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Migration', style: _subtitleTextStyle(m))),
          if ((mig?.description?.isNotEmpty ?? false)) Padding(padding: const EdgeInsets.only(top: 6), child: Text(mig!.description!, style: _contentTextStyle(m))),
          ...migTiles,
        ]);
        break;
      case 'alimentation':
        final alim = _fiche?.alimentation;
        final parts = <String>[];
        if (alim?.regimePrincipal != null && alim!.regimePrincipal!.isNotEmpty) {
          parts.add('Régime: ${alim.regimePrincipal}');
        }
        if (alim?.proiesPrincipales.isNotEmpty == true) {
          parts.add('Proies: ${alim!.proiesPrincipales.join(', ')}');
        }
        if (alim?.description != null && alim!.description!.isNotEmpty) {
          parts.add(alim.description!);
        }
        content = Text(parts.isNotEmpty ? parts.join('. ') : 'Données d\'alimentation à venir.', style: _contentTextStyle(m));
        break;
      case 'reproduction':
        final r = _fiche?.reproduction;
        final desc = r?.description ?? '';
        final periode = r?.periode;
        final tiles = <Widget>[];
        if ((periode?.debutMois?.isNotEmpty ?? false) || (periode?.finMois?.isNotEmpty ?? false)) {
          tiles.add(_miniInfoCard(title: 'Période', value: [periode?.debutMois, periode?.finMois].where((e) => (e ?? '').isNotEmpty).join(' → '), m: m));
        }
        if (r?.nbOeufsParPondee?.isNotEmpty ?? false) tiles.add(_miniInfoCard(title: 'Œufs', value: r!.nbOeufsParPondee!, m: m));
        if (r?.incubationJours?.isNotEmpty ?? false) tiles.add(_miniInfoCard(title: 'Incubation', value: r!.incubationJours!, m: m));
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (desc.isNotEmpty) Text(desc, style: _contentTextStyle(m)),
          if (tiles.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 10, runSpacing: 10, children: tiles)),
          if (desc.isEmpty && tiles.isEmpty) Text('Données de reproduction à venir.', style: _contentTextStyle(m)),
        ]);
        break;
      case 'repartition':
        final p = _fiche?.protectionEtatActuel;
        final tiles = <Widget>[];
        if (p?.statutFrance?.isNotEmpty ?? false) tiles.add(_miniInfoCard(title: 'France', value: p!.statutFrance!, m: m));
        if (p?.statutMonde?.isNotEmpty ?? false) tiles.add(_miniInfoCard(title: 'Monde', value: p!.statutMonde!, m: m));
        final hasTiles = tiles.isNotEmpty;
        final desc = p?.description ?? '';
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasTiles) Wrap(spacing: 10, runSpacing: 10, children: tiles),
          if (p?.actions?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Actions: ${p!.actions!}', style: _contentTextStyle(m))),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(desc, style: _contentTextStyle(m))),
          if (!hasTiles && desc.isEmpty) Text('Données de protection à venir.', style: _contentTextStyle(m)),
        ]);
        break;
      default:
        content = Text(
          'Informations sur ${_tabs[index]['title'].toString().toLowerCase()} du ${widget.bird.nomFr}. ',
          style: _contentTextStyle(m),
        );
        break;
    }

    if (showBasicInfo) {
      return content; // pas de scroll interne, panel gère le scroll
    } else {
      // Assure un scroll jusqu'au bas de l'écran pour éviter la frustration
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: m.dp(40, tabletFactor: 1.0)),
        child: content,
      );
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

  TextStyle _subtitleTextStyle(ResponsiveMetrics m) {
    return TextStyle(
      color: const Color(0xFF606D7C),
      fontSize: m.font(15, tabletFactor: 1.0, min: 13, max: 18),
      fontFamily: 'Quicksand',
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
  }

  String _buildClassificationSentence() {
    final nom = _fiche?.nomFrancais.isNotEmpty == true ? _fiche!.nomFrancais : widget.bird.nomFr;
    final sci = _fiche?.nomScientifique.isNotEmpty == true ? _fiche!.nomScientifique : '${widget.bird.genus} ${widget.bird.species}';
    final fam = _fiche?.famille.isNotEmpty == true ? _fiche!.famille : _familyName;
    final ordre = _fiche?.ordre.isNotEmpty == true ? _fiche!.ordre : '';
    final parts = <String>[
      nom,
      sci,
      if (fam.isNotEmpty) 'famille $fam',
      if (ordre.isNotEmpty) 'ordre $ordre',
    ];
    return '${parts.join(', ')}.';
  }

  String _buildTypeMilieuText(List<String> milieux, String descriptionHab, String? altitude) {
    final items = <String>[];
    if (milieux.isNotEmpty) {
      items.add('Milieux: ${milieux.join(', ')}');
    }
    if ((altitude != null && altitude.trim().isNotEmpty) || descriptionHab.toLowerCase().contains('altitude')) {
      // Essaie d'inclure l'altitude ou un indice d'altitude trouvé dans la description
      items.add('Altitude: ${altitude?.trim().isNotEmpty == true ? altitude!.trim() : 'hautes altitudes'}');
    }
    if (descriptionHab.trim().isNotEmpty) {
      // Ajoute un court extrait descriptif sans dupliquer l'information "Où l'observer"
      items.add(descriptionHab.trim());
    }
    return items.isNotEmpty ? items.join('. ') : '';
  }

  Widget _miniInfoCard({required String title, required String value, required ResponsiveMetrics m}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _contentTextStyle(m, underline: true)),
          const SizedBox(height: 4),
          Text(value, style: _contentTextStyle(m)),
        ],
      ),
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
