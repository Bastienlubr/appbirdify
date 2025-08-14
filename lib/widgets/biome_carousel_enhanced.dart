import 'package:flutter/material.dart';
import '../models/biome.dart';
import '../ui/responsive/responsive.dart';

class BiomeCarouselEnhanced extends StatefulWidget {
  final Function(Biome)? onBiomeSelected;

  const BiomeCarouselEnhanced({
    super.key,
    this.onBiomeSelected,
  });

  @override
  State<BiomeCarouselEnhanced> createState() => _BiomeCarouselEnhancedState();
}

class _BiomeCarouselEnhancedState extends State<BiomeCarouselEnhanced> {
  final PageController _pageController = PageController(viewportFraction: 0.55);
  int _currentPage = 0;
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
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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

        final double itemSize = isTablet
            ? m.dp(250, tabletFactor: 1.5, min: 260, max: 420)
            : 250 * phoneScaleUp;
        final double radius = isTablet ? m.dp(28, tabletFactor: 1.2, min: 28, max: 40) : 28;
        final double blur = isTablet ? m.dp(12, tabletFactor: 1.2, min: 10, max: 18) : 12;
        final double offsetY = isTablet ? m.dp(6, tabletFactor: 1.2, min: 4, max: 10) : 6;
        final double padH = isTablet ? m.dp(4, tabletFactor: 1.2, min: 4, max: 10) : 4 * phoneScaleUp;
        final double dotsActive = isTablet ? 14 : (12 * phoneScaleUp);
        final double dotsInactive = isTablet ? 10 : (8 * phoneScaleUp);
        final double dotsGap = isTablet ? 8 : (6 * phoneScaleUp);
        final double height = isTablet
            ? (itemSize + m.dp(60, tabletFactor: 1.0, min: 50, max: 90))
            : (300 * phoneScaleUp);

        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _pageController,
                itemCount: biomes.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  widget.onBiomeSelected?.call(biomes[index]);
                },
                itemBuilder: (context, index) {
                  final biome = biomes[index];
                  final isCenter = index == _currentPage;

                  if (_currentPage == 0 && index == biomes.length - 1) {
                    return const SizedBox.shrink();
                  }

                  final double scale = isTablet ? (isCenter ? 1.0 : 0.82) : (isCenter ? 1.0 : (0.75 + (phoneScaleUp - 1.0) * 0.2));

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH),
                    child: Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: itemSize,
                              height: itemSize,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(radius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: blur,
                                    offset: Offset(0, offsetY),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(radius),
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(biomes.length, (index) {
                final isActive = index == _currentPage;
                return Row(
                  children: [
                    Container(
                      width: isActive ? dotsActive : dotsInactive,
                      height: isActive ? dotsActive : dotsInactive,
                      decoration: BoxDecoration(
                        color: isActive 
                          ? const Color(0xFF6A994E)
                          : const Color(0xFF344356).withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (index < biomes.length - 1)
                      SizedBox(width: dotsGap),
                  ],
                );
              }),
            ),
          ],
        );
      },
    );
  }
} 