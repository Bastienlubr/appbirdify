import 'package:flutter/material.dart';
import '../ui/responsive/responsive.dart';

class HomeBottomNavBar extends StatelessWidget {
  final int currentIndex; // 0: Quiz, 1: Accueil, 2: Profil, 3: Perchoir
  final ValueChanged<int> onTabSelected;

  const HomeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);

        // Tailles de base (A54 inchangé) puis scaling doux sur plus grands écrans
        final double iconSize = m.isTablet ? 28.0 : 24.0;
        final double labelSize = m.isTablet ? 13.0 : 12.0;
        final double horizontalPadding = m.dp(20);
        final double verticalPadding = m.dp(10, tabletFactor: 1.25);
        final double radius = m.dp(20, tabletFactor: 1.1);
        final double bottomLift = m.dp(-1, tabletFactor: 1.0);

        return Container( 
          margin: EdgeInsets.only(bottom: bottomLift),
          decoration: BoxDecoration(
            color: const Color(0xFF6A994E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: m.dp(12, tabletFactor: 1.2),
                offset: Offset(0, m.dp(4)),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _NavItem(
                    index: 0,
                    isSelected: currentIndex == 0,
                    icon: Icons.quiz,
                    label: 'Quiz',
                    iconSize: iconSize,
                    labelSize: labelSize,
                    onTap: onTabSelected,
                  ),
                  ),
                  Expanded(
                    child: _NavItem(
                    index: 1,
                    isSelected: currentIndex == 1,
                    icon: Icons.home,
                    label: 'Accueil',
                    iconSize: iconSize,
                    labelSize: labelSize,
                    onTap: onTabSelected,
                  ),
                  ),
                  Expanded(
                    child: _NavItem(
                    index: 2,
                    isSelected: currentIndex == 2,
                    icon: Icons.person,
                    label: 'Profil',
                    iconSize: iconSize,
                    labelSize: labelSize,
                    onTap: onTabSelected,
                  ),
                  ),
                  Expanded(
                    child: _NavItem(
                    index: 3,
                    isSelected: currentIndex == 3,
                    icon: Icons.library_books,
                    label: 'Perchoir',
                    iconSize: iconSize,
                    labelSize: labelSize,
                    onTap: onTabSelected,
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

class _NavItem extends StatelessWidget {
  final int index;
  final bool isSelected;
  final IconData icon;
  final String label;
  final double iconSize;
  final double labelSize;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.labelSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color selectedColor = Color(0xFFFEC868);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(index),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? selectedColor : Colors.white,
                size: iconSize,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? selectedColor : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


