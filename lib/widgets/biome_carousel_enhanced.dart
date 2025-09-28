import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
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
  final bool legacyStyle; // si true: désactive les tweaks desktop et respecte strictement viewport/itemSize d’origine

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
    this.legacyStyle = false,
  });

  @override
  State<BiomeCarouselEnhanced> createState() => _BiomeCarouselEnhancedState();
}

class _BiomeCarouselEnhancedState extends State<BiomeCarouselEnhanced>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  double _currentPageFloat = 0.0;
  late AnimationController _scaleController;
  late AnimationController _opacityController;
  int _initialPage = 0;
  double _activeViewport = 0.55;
  bool _viewportChangeScheduled = false;
  
  final List<Biome> biomes = [
    Biome(name: 'Urbain', imageAsset: 'assets/Images/Milieu/Milieu_urbain.png'),
    Biome(name: 'Forestier', imageAsset: 'assets/Images/Milieu/Milieu_forestier.png'),
    Biome(name: 'Agricole', imageAsset: 'assets/Images/Milieu/Milieu_agricole.png'),
    Biome(name: 'Humide', imageAsset: 'assets/Images/Milieu/Milieu_humide.png'),
    Biome(name: 'Montagnard', imageAsset: 'assets/Images/Milieu/Milieu_montagnard.png'),
    Biome(name: 'Littoral', imageAsset: 'assets/Images/Milieu/Milieu_littoral.png'),
  ];

  void _attachControllerListener() {
    _pageController.addListener(() {
      final page = _pageController.page ?? _initialPage.toDouble();
      if (!mounted) return;
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
    });
  }

  void _recreateController(double newViewport) {
    final mapped = _currentPage;
    _pageController.dispose();
    _initialPage = widget.loopInfinite ? biomes.length * 1000 + mapped : mapped;
    _activeViewport = newViewport;
    _pageController = PageController(viewportFraction: _activeViewport, initialPage: _initialPage);
    _attachControllerListener();
    if (mounted) setState(() {});
  }

  void _scheduleViewportChange(double newViewport) {
    if (_viewportChangeScheduled) return;
    _viewportChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recreateController(newViewport);
      _viewportChangeScheduled = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _initialPage = widget.loopInfinite ? biomes.length * 1000 : 0;
    _activeViewport = widget.viewportFraction;
    _pageController = PageController(viewportFraction: _activeViewport, initialPage: _initialPage);
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _opacityController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _attachControllerListener();
  }

  @override
  void didUpdateWidget(covariant BiomeCarouselEnhanced oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportFraction != widget.viewportFraction || oldWidget.loopInfinite != widget.loopInfinite) {
      _recreateController(widget.viewportFraction);
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
        final double screenW = MediaQuery.of(context).size.width;
        final bool isDesktop = (kIsWeb && screenW >= 1024) || (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux));
        final bool legacy = widget.legacyStyle;

        // Échelle progressive pour grands téléphones
        final double phoneScaleUp = !isTablet ? (m.shortest / 400.0).clamp(1.0, 1.15) : 1.0;

        // Paramètres visuels
        double itemSize = widget.compactStyle
            ? (isTablet ? m.dp(200, tabletFactor: 1.2, min: 180, max: 320)
                        : m.dp(160, tabletFactor: 1.0, min: 140, max: 190))
            : (isTablet ? m.dp(250, tabletFactor: 1.5, min: 260, max: 420)
                        : 250 * phoneScaleUp);
        final double radius = widget.compactStyle ? (itemSize * 0.12).clamp(16, 28).toDouble() : 28;
        final double blur = isTablet ? m.dp(12, tabletFactor: 1.2, min: 10, max: 18) : 12;
        final double offsetY = isTablet ? m.dp(6, tabletFactor: 1.2, min: 4, max: 10) : 6;
        double padH = widget.compactStyle
            ? (isTablet ? m.dp(1, tabletFactor: 1.0, min: 1, max: 2) : m.dp(1))
            : (isTablet ? m.dp(4, tabletFactor: 1.2, min: 4, max: 10) : 4 * phoneScaleUp);

        // Viewport: si legacy, respecter strictement la valeur fournie
        final double desiredViewport = legacy ? widget.viewportFraction : (isDesktop ? 0.40 : widget.viewportFraction);
        if (!legacy && (desiredViewport - _activeViewport).abs() > 0.0001) {
          _scheduleViewportChange(desiredViewport);
        }

        // En desktop, ajuster la taille visuelle de la tuile à la largeur du viewport (sauf legacy)
        if (isDesktop && !legacy) {
          final double pageW = _activeViewport * constraints.maxWidth;
          // Occuper ~96% du viewport, avec plafond raisonnable pour éviter l’overflow vertical
          itemSize = (pageW * 0.96).clamp(220.0, 360.0);
          padH = 6.0;
        }

        final double dotsActive = isTablet ? 14 : (12 * phoneScaleUp);
        final double dotsInactive = isTablet ? 10 : (8 * phoneScaleUp);
        final double dotsGap = isTablet ? 8 : (6 * phoneScaleUp);
        final double dotsExtra = widget.showDots
            ? (widget.compactStyle
                ? m.dp(24, tabletFactor: 1.0, min: 16, max: 40)
                : (isTablet ? m.dp(30, tabletFactor: 1.0, min: 24, max: 56) : 24))
            : 0.0;
        double computedHeight = widget.compactStyle
            ? (itemSize + dotsExtra)
            : (isTablet ? (itemSize + (dotsExtra > 0 ? dotsExtra : m.dp(40, tabletFactor: 1.0, min: 30, max: 60))) : (300 * phoneScaleUp));
        // Borne par la hauteur parent si finie
        final double maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : computedHeight;
        if (computedHeight > maxH) {
          // Réduire d’abord itemSize, garder les dots s’ils sont affichés
          final double targetItem = (maxH - dotsExtra).clamp(120.0, itemSize);
          itemSize = targetItem;
          computedHeight = math.min(computedHeight, maxH);
        }
        final double height = computedHeight;

        return Column(
          children: [
            SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ScrollConfiguration(
                    behavior: const _DesktopDragScrollBehavior(),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.loopInfinite ? 1000000 : biomes.length,
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
                      onPageChanged: (index) {
                        final mapped = widget.loopInfinite ? index % biomes.length : index;
                        if (mounted) setState(() => _currentPage = mapped);
                        if (widget.selectOnPageChange) widget.onBiomeSelected?.call(biomes[mapped]);
                      },
                      itemBuilder: (context, index) {
                        final mapped = widget.loopInfinite ? index % biomes.length : index;
                        final biome = biomes[mapped];

                        if (_currentPage == 0 && index == biomes.length - 1) return const SizedBox.shrink();

                        final isUnlocked = widget.isBiomeUnlocked?.call(biome.name) ?? true;

                        final distance = widget.loopInfinite
                            ? ((_currentPageFloat - (mapped.toDouble()))).abs()
                            : (_currentPageFloat - index).abs();
                        double opacity;
                        double scale;
                        if (isDesktop && !legacy) {
                          final double d = distance.clamp(0.0, 1.0);
                          final double o = (1.0 - 0.12 * d).clamp(0.85, 1.0);
                          opacity = isUnlocked ? o : (o * 0.5);
                          scale = 1.0 - 0.06 * d; // léger différentiel pour les adjacents
                        } else {
                          final double baseOpacity = widget.compactStyle
                              ? (1.0 - (distance * distance) * 0.7).clamp(0.35, 1.0)
                              : (1.0 - (distance * 0.4)).clamp(0.3, 1.0);
                          opacity = isUnlocked ? baseOpacity : (baseOpacity * 0.5);
                          final double baseScale = widget.compactStyle
                              ? (isTablet ? 0.88 : 0.88)
                              : (isTablet ? 0.82 : (0.75 + (phoneScaleUp - 1.0) * 0.2));
                          final double maxScale = 1.0;
                          scale = baseScale + ((maxScale - baseScale) * (1.0 - distance.clamp(0.0, 1.0)));
                        }

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
                                child: child,
                              ),
                            );
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: SizedBox(
                              width: itemSize,
                              height: itemSize,
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
                                                  child: const Icon(Icons.image_not_supported, color: Color(0xFF6A994E), size: 60),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!isUnlocked)
                                        Container(
                                          width: itemSize,
                                          height: itemSize,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(radius),
                                          ),
                                          child: const Center(child: Icon(Icons.lock, color: Colors.white)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ),
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final double width = constraints.maxWidth;
                          final double dx = details.localPosition.dx;
                          final double centerX = width / 2;

                          final bool goPrev = dx < centerX;
                          if (widget.loopInfinite) {
                            final int currentAbs = (_pageController.page ?? _initialPage.toDouble()).round();
                            final int targetAbs = currentAbs + (goPrev ? -1 : 1);
                            if (widget.disableTapCenterAnimation) {
                              _pageController.jumpToPage(targetAbs);
                            } else {
                              _pageController.animateToPage(targetAbs, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
                            }
                          } else {
                            final int nextIndex = _currentPage + (goPrev ? -1 : 1);
                            if (nextIndex < 0 || nextIndex >= biomes.length) return;
                            if (widget.disableTapCenterAnimation) {
                              _pageController.jumpToPage(nextIndex);
                            } else {
                              _pageController.animateToPage(nextIndex, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                          width: (isActive ? (isTablet ? 14 : 12) : (isTablet ? 10 : 8)) * dotScale,
                          height: (isActive ? (isTablet ? 14 : 12) : (isTablet ? 10 : 8)) * dotScale,
                          decoration: BoxDecoration(
                            color: (isActive ? const Color(0xFF6A994E) : const Color(0xFF344356).withValues(alpha: 0.3)).withValues(alpha: dotOpacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index < biomes.length - 1) SizedBox(width: isTablet ? 8 : (6 * phoneScaleUp)),
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

class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
} 