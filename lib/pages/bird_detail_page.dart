import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../ui/responsive/responsive.dart';

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
        mass: 8.0,           // Plus lourd pour plus de stabilité
        stiffness: 1500.0,   // Plus rigide pour arrêt net
        damping: 8.0,        // Plus d'amortissement pour éviter le rebond
       );

  @override
  double carriedMomentum(double existingVelocity) {
    // Élimine presque tout l'élan pour éviter le wiggle
    return existingVelocity * 0.02;
  }

  @override
  double get maxFlingVelocity => 150.0;  // Limite encore plus la vitesse

  @override
  double get minFlingVelocity => 400.0;  // Seuil plus élevé pour déclencher
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

    // Démarre loin pour scroller dans les deux sens
    final seed = _nTabs * 1000;
    _contentController = PageController(initialPage: seed);
    _tabController = PageController(
      initialPage: seed,
      viewportFraction: 0.2,
    );

    // Position basse par défaut (panel = 1/3 visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelController.value = 0.0;
    });
  }

  @override
  void dispose() {
    _panelController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
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
      final duration = const Duration(milliseconds: 180);
      final curve = Curves.easeOutQuart;

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

              // Bouton retour
              _buildBackButton(m),

              // Dots latéraux (placeholder – à adapter si besoin)
              _buildSideDots(m, screenHeight),

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

  // --- Side dots (placeholder décoratif) ------------------------------------
  Widget _buildSideDots(ResponsiveMetrics m, double screenHeight) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: m.dp(20, tabletFactor: 1.1),
            bottom: screenHeight * 0.08,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Container(
                width: m.dp(11, tabletFactor: 1.0),
                height: m.dp(11, tabletFactor: 1.0),
                margin:
                    EdgeInsets.symmetric(vertical: m.dp(4, tabletFactor: 1.0)),
                decoration: BoxDecoration(
                  color: index == 0 ? Colors.white : const Color(0xCC473C33),
                  shape: BoxShape.circle,
                  boxShadow: index == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
      ),
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
            padding:
                EdgeInsets.symmetric(horizontal: m.dp(24, tabletFactor: 1.1)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: m.dp(8, tabletFactor: 1.0)),

                // Infos de base (nom, famille) – visible en position basse
                AnimatedOpacity(
                  opacity: showBasicInfo ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: showBasicInfo ? null : 0,
                    child: showBasicInfo
                        ? _buildInfoSection(m)
                        : const SizedBox.shrink(),
                  ),
                ),

                if (showBasicInfo) SizedBox(height: m.dp(20, tabletFactor: 1.1)),

                // Carrousel d'onglets
                _buildTabButtons(m),

                // Titre animé de l'onglet sélectionné (collé aux onglets)
                Transform.translate(
                  offset: Offset(0, -m.dp(10, tabletFactor: 1.0)), // Remonte le titre
                  child: _buildAnimatedTabTitle(m),
                ),

                SizedBox(height: m.dp(16, tabletFactor: 1.1)),

                // Séparateur visible en mode étendu
                AnimatedOpacity(
                  opacity: showBasicInfo ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: showBasicInfo ? 0 : 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0x70344356),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),

                SizedBox(height: showBasicInfo ? 0 : m.dp(16, tabletFactor: 1.1)),

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
      height: m.dp(80, tabletFactor: 1.1),
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
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutQuart,
                      tween: Tween<double>(
                        begin: isSelected ? 0.0 : 1.0,
                        end: isSelected ? 1.0 : 0.0,
                      ),
                      builder: (context, animValue, child) {
                        // Calcul des valeurs interpolées
                        final size = 60.0 + (5.0 * animValue); // 60 -> 65
                        final iconSize =
                            28.0 + (2.0 * animValue); // 28 -> 30
                        final yOffset = -3.0 * animValue; // 0 -> -3
                        final colorAlpha =
                            0.3 + (0.7 * animValue); // 0.3 -> 1.0
                        final titleHeight = 6.0 * animValue; // 0 -> 6

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
                                                alpha: 0.15 * animValue),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
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
      height: m.dp(20, tabletFactor: 1.0), // Assez de hauteur pour ne pas couper le texte
      child: Align(
        alignment: Alignment.topCenter, // Colle en haut du conteneur
        child: TweenAnimationBuilder<double>(
          key: ValueKey('title-$_selectedTabIndex-${_previousTabIndex}'),
          duration: const Duration(milliseconds: 180), // Même durée que les onglets
          curve: Curves.easeOutQuart, // Même courbe que les onglets
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, animValue, child) {
            // Animation entrante pour le nouveau titre
            final opacity = animValue;
            final yOffset = 6.0 * (1.0 - animValue); // Descend de 6px vers 0
            final scale = 0.85 + (0.15 * animValue); // Grandit de 0.85 à 1.0

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
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    } else {
      _panelController.animateTo(0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    }
  }

  void _onPanelPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity.abs() > 500) {
      if (velocity < 0) {
        _panelController.animateTo(1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      } else {
        _panelController.animateTo(0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      }
    } else {
      if (_panelController.value < 0.5) {
        _panelController.animateTo(0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      } else {
        _panelController.animateTo(1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      }
    }
  }

  String get _familyName => '${widget.bird.genus}idés';
}
