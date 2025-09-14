import 'package:flutter/material.dart';
import '../models/biome.dart';
import '../ui/responsive/responsive.dart';

class BiomeCarouselEnhanced extends StatefulWidget {
  final Function(Biome)? onBiomeSelected;
  final Function(Biome)? onBiomeTapped; // callback distinct pour le tap
  final Function(String)? isBiomeUnlocked; // Fonction pour vérifier si un biome est déverrouillé
  final bool loopInfinite;
  final bool showDots;
  final double viewportFraction;
  final bool compactStyle; // style compact (Profil) vs style par défaut (Home)
  final bool selectOnPageChange; // sélection auto lors du slide
  final bool disableTapCenterAnimation; // désactiver l'animation de recentrage au tap

  const BiomeCarouselEnhanced({
    super.key,
    this.onBiomeSelected,
    this.onBiomeTapped,
    this.isBiomeUnlocked,
    this.loopInfinite = false,
    this.showDots = true,
    this.viewportFraction = 0.55,
    this.compactStyle = false,
    this.selectOnPageChange = false,
    this.disableTapCenterAnimation = false,
  });

  @override
  State<BiomeCarouselEnhanced> createState() => _BiomeCarouselEnhancedState();
}

class _BiomeCarouselEnhancedState extends State<BiomeCarouselEnhanced>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;
  double _currentPageFloat = 0.0;
  late AnimationController _scaleController;
  late AnimationController _opacityController;
  int _initialPage = 0;
  
  final List<Biome> biomes = [
    Biome(
      name: 'Urbain',
      imageAsset: 'assets/Images/Milieu/Milieu_urbain.png',
    ),
    Biome(
      name: 'Forestier',
      imageAsset: 'assets/Images/Milieu/Milieu_forestier.png',
    ),
    Biome(
      name: 'Agricole',
      imageAsset: 'assets/Images/Milieu/Milieu_agricole.png',
    ),
    Biome(
      name: 'Humide',
      imageAsset: 'assets/Images/Milieu/Milieu_humide.png',
    ),
    Biome(
      name: 'Montagnard',
      imageAsset: 'assets/Images/Milieu/Milieu_montagnard.png',
    ),
    Biome(
      name: 'Littoral',
      imageAsset: 'assets/Images/Milieu/Milieu_littoral.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initialPage = widget.loopInfinite ? biomes.length * 1000 : 0;
    _pageController = PageController(viewportFraction: widget.viewportFraction, initialPage: _initialPage);
    
    // Contrôleurs d'animation pour des transitions fluides
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    _pageController.addListener(() {
      final page = _pageController.page ?? _initialPage.toDouble();
      if (mounted) {
        setState(() {
          if (widget.loopInfinite) {
            final len = biomes.length;
            _currentPageFloat = (page % len);
            _currentPage = _currentPageFloat.round() % len;
          } else {
            _currentPageFloat = page;
            _currentPage = page.round();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant BiomeCarouselEnhanced oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportFraction != widget.viewportFraction || oldWidget.loopInfinite != widget.loopInfinite) {
      final mapped = _currentPage;
      _pageController.dispose();
      _initialPage = widget.loopInfinite ? biomes.length * 1000 + mapped : mapped;
      _pageController = PageController(viewportFraction: widget.viewportFraction, initialPage: _initialPage);
      _pageController.addListener(() {
        final page = _pageController.page ?? _initialPage.toDouble();
        if (mounted) {
          setState(() {
            if (widget.loopInfinite) {
              final len = biomes.length;
              _currentPageFloat = (page % len);
              _currentPage = _currentPageFloat.round() % len;
            } else {
              _currentPageFloat = page;
              _currentPage = page.round();
            }
          });
        }
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scaleController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final bool isTablet = m.isTablet;

        // Échelle progressive pour grands téléphones (sans toucher aux petits comme A54)
        final double phoneScaleUp = !isTablet ? (m.shortest / 400.0).clamp(1.0, 1.15) : 1.0;

        // Paramètres visuels selon style
        final double itemSize = widget.compactStyle
            ? (isTablet ? m.dp(200, tabletFactor: 1.2, min: 180, max: 320)
                        : m.dp(160, tabletFactor: 1.0, min: 140, max: 190))
            : (isTablet ? m.dp(250, tabletFactor: 1.5, min: 260, max: 420)
                        : 250 * phoneScaleUp);
        final double radius = widget.compactStyle
            ? (itemSize * 0.12).clamp(16, 28).toDouble()
            : 28;
        final double blur = isTablet ? m.dp(12, tabletFactor: 1.2, min: 10, max: 18) : 12;
        final double offsetY = isTablet ? m.dp(6, tabletFactor: 1.2, min: 4, max: 10) : 6;
        final double padH = widget.compactStyle
            ? (isTablet ? m.dp(1, tabletFactor: 1.0, min: 1, max: 2) : m.dp(1))
            : (isTablet ? m.dp(4, tabletFactor: 1.2, min: 4, max: 10) : 4 * phoneScaleUp);
        final double dotsActive = isTablet ? 14 : (12 * phoneScaleUp);
        final double dotsInactive = isTablet ? 10 : (8 * phoneScaleUp);
        final double dotsGap = isTablet ? 8 : (6 * phoneScaleUp);
        final double height = widget.compactStyle
            ? (itemSize + m.dp(40, tabletFactor: 1.0, min: 28, max: 56))
            : (isTablet
                ? (itemSize + m.dp(60, tabletFactor: 1.0, min: 50, max: 90))
                : (300 * phoneScaleUp));

        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.loopInfinite ? 1000000 : biomes.length,
                physics: const BouncingScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                onPageChanged: (index) {
                  final mapped = widget.loopInfinite ? index % biomes.length : index;
                  if (mounted) {
                    setState(() {
                      _currentPage = mapped;
                    });
                  }
                  // Selon le contexte (Home), déclencher la sélection au slide
                  if (widget.selectOnPageChange) {
                    widget.onBiomeSelected?.call(biomes[mapped]);
                  }
                },
                itemBuilder: (context, index) {
                  final mapped = widget.loopInfinite ? index % biomes.length : index;
                  final biome = biomes[mapped];
                  
                  if (_currentPage == 0 && index == biomes.length - 1) {
                    return const SizedBox.shrink();
                  }

                  // Vérifier si le biome est déverrouillé
                  final isUnlocked = widget.isBiomeUnlocked?.call(biome.name) ?? true;
                  
                  // Animation fluide basée sur la distance par rapport à la page courante
                  final distance = widget.loopInfinite
                      ? ((_currentPageFloat - (mapped.toDouble()))).abs()
                      : (_currentPageFloat - index).abs();
                  final double baseOpacity = widget.compactStyle
                      ? (1.0 - (distance * distance) * 0.7).clamp(0.35, 1.0)
                      : (1.0 - (distance * 0.4)).clamp(0.3, 1.0);
                  // Réduire l'opacité pour les biomes verrouillés
                  final opacity = isUnlocked ? baseOpacity : (baseOpacity * 0.5);
                  
                  // Échelle progressive
                  final baseScale = widget.compactStyle
                      ? (isTablet ? 0.88 : 0.88)
                      : (isTablet ? 0.82 : (0.75 + (phoneScaleUp - 1.0) * 0.2));
                  final maxScale = 1.0;
                  final scale = baseScale + ((maxScale - baseScale) * (1.0 - distance.clamp(0.0, 1.0)));

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH),
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: widget.compactStyle ? 120 : 150),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0.0, end: scale),
                      builder: (context, animatedScale, child) {
                        return Transform.scale(
                          scale: animatedScale,
                          child: AnimatedOpacity(
                            opacity: opacity,
                            duration: Duration(milliseconds: widget.compactStyle ? 80 : 100),
                            curve: Curves.easeInOut,
                            child: GestureDetector(
                            onTap: () {
                              final isCentered = mapped == _currentPage;
                              if (isCentered) {
                                // Tap sur l'élément centré: notifier explicitement via onBiomeTapped
                                widget.onBiomeTapped?.call(biomes[mapped]);
                              } else {
                                if (widget.disableTapCenterAnimation) {
                                  _pageController.jumpToPage(index);
                                } else {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: itemSize,
                                      height: itemSize,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(radius),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15 * opacity),
                                            blurRadius: blur,
                                            offset: Offset(0, offsetY),
                                            spreadRadius: distance < 1.0 ? 2.0 : 0.0,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(radius),
                                        child: ColorFiltered(
                                          colorFilter: isUnlocked 
                                            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                            : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                                          child: Image.asset(
                                            biome.imageAsset,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFFF2E8CF),
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Color(0xFF6A994E),
                                                  size: 60,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Overlay gris pour les biomes verrouillés
                                    if (!isUnlocked)
                                      Container(
                                        width: itemSize,
                                        height: itemSize,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(radius),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.lock,
                                            color: Colors.white,
                                            size: itemSize * 0.2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  );
                },
              ),
            ),

            // Indicateurs de page avec animations fluides
            if (widget.showDots)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(biomes.length, (index) {
                    final distance = (_currentPageFloat - index).abs();
                    final isActive = distance < 0.5;
                    final dotScale = isActive ? 1.0 : (1.0 - distance.clamp(0.0, 1.0) * 0.3);
                    final dotOpacity = (1.0 - distance.clamp(0.0, 1.0) * 0.7).clamp(0.3, 1.0);
                    
                    return Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOutCubic,
                          width: (isActive ? dotsActive : dotsInactive) * dotScale,
                          height: (isActive ? dotsActive : dotsInactive) * dotScale,
                          decoration: BoxDecoration(
                            color: (isActive 
                              ? const Color(0xFF6A994E)
                              : const Color(0xFF344356).withValues(alpha: 0.3)).withValues(alpha: dotOpacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index < biomes.length - 1)
                          SizedBox(width: dotsGap),
                      ],
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
} 