import 'package:flutter/material.dart';

class HomeSideNav extends StatelessWidget {
  final int currentIndex; // 0: Quiz, 1: Accueil, 2: Perchoir, 3: Profil
  final ValueChanged<int> onTabSelected;
  const HomeSideNav({super.key, required this.currentIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF6A994E),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _SideItem(index: 1, icon: Icons.home, label: 'Accueil', isSelected: currentIndex == 1, onTap: onTabSelected),
              _SideItem(index: 0, icon: Icons.quiz, label: 'Quiz', isSelected: currentIndex == 0, onTap: onTabSelected),
              _SideItem(index: 3, icon: Icons.library_books, label: 'Perchoir', isSelected: currentIndex == 3, onTap: onTabSelected),
              _SideItem(index: 2, icon: Icons.person, label: 'Profil', isSelected: currentIndex == 2, onTap: onTabSelected),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final ValueChanged<int> onTap;
  const _SideItem({required this.index, required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color selectedColor = Color(0xFFFEC868);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0x1AFEC868),
                borderRadius: BorderRadius.circular(14),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, color: isSelected ? selectedColor : Colors.white, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: isSelected ? 16 : 15,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? selectedColor : Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
