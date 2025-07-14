import 'package:flutter/material.dart';
import '../models/biome.dart';

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
    return Column(
      children: [
        SizedBox(
          height: 300,
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
              
              // Condition pour ne pas afficher l'élément précédent si currentPage == 0
              if (_currentPage == 0 && index == biomes.length - 1) {
                return const SizedBox.shrink();
              }
              
              // Facteur de zoom : 1.0 pour le centre, 0.75 pour les côtés
              final scale = isCenter ? 1.0 : 0.75;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        // Image du biome
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
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
        
        // Points indicateurs
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(biomes.length, (index) {
            final isActive = index == _currentPage;
            return Row(
              children: [
                Container(
                  width: isActive ? 12 : 8,
                  height: isActive ? 12 : 8,
                  decoration: BoxDecoration(
                    color: isActive 
                      ? const Color(0xFF6A994E)
                      : const Color(0xFF344356).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (index < biomes.length - 1)
                  const SizedBox(width: 6),
              ],
            );
          }),
        ),
      ],
    );
  }
} 