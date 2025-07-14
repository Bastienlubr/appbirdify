import 'package:flutter/material.dart';
import '../theme/colors.dart'; // Adapte si ton fichier s'appelle autrement

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.antiflashWhite,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Salut, Carletti',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                fontFamily: 'Quicksand',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '👋',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),
            const Text(
              'Les habitats',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.fernGreen,
                fontFamily: 'Quicksand',
              ),
            ),
            const SizedBox(height: 16),
            // Slider visuel des biomes
            SizedBox(
              height: 240,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.7),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final biomeImages = [
                    'Milieu_urbain.png',
                    'Milieu_agricole.png',
                    'Milieu_forestier.png',
                    'Milieu_humide.png',
                    'Milieu_littoral.png',
                    'Milieu_montagnard.png',
                  ];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          'assets/Images/Milieu/${biomeImages[index]}',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Message d’intro
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Le voyage ne fait que commencer...\nFaites défiler pour découvrir la suite des habitats.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  fontFamily: 'Quicksand',
                ),
              ),
            ),
            const Spacer(),
            // Navigation bar
            const _CustomBottomNavBar(),
          ],
        ),
      ),
    );
  }
}

class _CustomBottomNavBar extends StatelessWidget {
  const _CustomBottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _NavBarItem(icon: Icons.menu_book_rounded, label: 'Quiz', selected: false),
          _NavBarItem(icon: Icons.weekend_rounded, label: 'Accueil', selected: true),
          _NavBarItem(icon: Icons.person_rounded, label: 'Profil', selected: false),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 28,
          color: selected ? AppColors.accent : AppColors.textDark,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Quicksand',
            color: selected ? AppColors.accent : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
