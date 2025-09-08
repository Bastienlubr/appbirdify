import 'package:flutter/material.dart';

/// Animation de transition universelle pour les pages (slide + fade + micro-scale).
///
/// Exemple d'usage:
/// Navigator.of(context).push(
///   routePageUniverselle(const MaPage(), sens: SensEntree.droite),
/// );
enum SensEntree { droite, gauche, haut, bas }

Offset _offsetDepart(SensEntree sens) {
  switch (sens) {
    case SensEntree.droite:
      return const Offset(1.0, 0.0);
    case SensEntree.gauche:
      return const Offset(-1.0, 0.0);
    case SensEntree.haut:
      return const Offset(0.0, -1.0);
    case SensEntree.bas:
      return const Offset(0.0, 1.0);
  }
}

Route routePageUniverselle(
  Widget page, {
  SensEntree sens = SensEntree.droite,
  Duration duree = const Duration(milliseconds: 280),
  Curve courbe = Curves.easeOutCubic,
  Curve courbeInverse = Curves.easeInCubic,
  double echelleDepart = 0.985,
  double debutFondu = 0.0,
  double finFondu = 0.8,
}) {
  return PageRouteBuilder(
    transitionDuration: duree,
    reverseTransitionDuration: duree,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: courbe,
        reverseCurve: courbeInverse,
      );

      final slide = Tween<Offset>(begin: _offsetDepart(sens), end: Offset.zero).animate(curved);
      final fade = CurvedAnimation(
        parent: animation,
        curve: Interval(debutFondu, finFondu, curve: Curves.easeOut),
        reverseCurve: Interval(debutFondu, finFondu, curve: Curves.easeIn),
      );
      final scale = Tween<double>(begin: echelleDepart, end: 1.0).animate(curved);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}


