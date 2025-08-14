import 'package:flutter/material.dart';
import 'breakpoints.dart';

class ScreenSize {
  final double width;
  ScreenSize(this.width);

  bool get isXS => width < AppBreakpoints.xs;
  bool get isSM => width >= AppBreakpoints.xs && width < AppBreakpoints.sm;
  bool get isMD => width >= AppBreakpoints.sm && width < AppBreakpoints.md;
  bool get isLG => width >= AppBreakpoints.md && width < AppBreakpoints.lg;
  bool get isXL => width >= AppBreakpoints.lg;

  double spacing() {
    if (isXS) return 14;  // +2
    if (isSM) return 18;  // +2
    if (isMD) return 24;
    if (isLG) return 28;
    return 32;
  }

  double textScale() {
    if (isXS) return 1.12; // petit smartphone
    if (isSM) return 1.18; // grand smartphone
    if (isMD) return 1.20; // petite tablette / portrait
    if (isLG) return 1.30; // tablette paysage / laptop
    return 1.40;           // très grands écrans
  }

  // Contrôle l’overlap (en px) entre le bouton et l’anneau pour qu’ils se touchent visuellement.
  // Ajuste une seule fois ici pour impacter toutes les pages qui l’utilisent.
  double buttonOverlapPx() {
    if (isXS) return 1.5;
    if (isSM) return 2.5;
    if (isMD) return 3.0;
    if (isLG) return 3.5;
    return 4.0;
  }
}

ScreenSize useScreenSize(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return ScreenSize(width);
}

/// Métriques standardisées pour faciliter les écrans responsive sans wrapper dédié
class ResponsiveMetrics {
  final ScreenSize screen;
  final Size box;
  final double shortest;
  final bool isWide;
  final bool isTablet;
  final double scale;       // échelle globale de texte (breakpoints)
  final double localScale;  // échelle locale selon la taille de l'écran courant
  final double spacing;     // espacement de base harmonisé
  final double maxWidth;    // largeur max du contenu centré

  ResponsiveMetrics({
    required this.screen,
    required this.box,
    required this.shortest,
    required this.isWide,
    required this.isTablet,
    required this.scale,
    required this.localScale,
    required this.spacing,
    required this.maxWidth,
  });

  double font(double base, {double tabletFactor = 1.05, double min = 12, double max = 72}) {
    final factor = isTablet ? tabletFactor : 1.0;
    return (base * scale * factor).clamp(min, max).toDouble();
  }

  double dp(double base, {double tabletFactor = 1.0, double min = 0, double max = 10000}) {
    final factor = isTablet ? (localScale * tabletFactor) : 1.0;
    return (base * factor).clamp(min, max).toDouble();
  }

  double gapSmall() => (spacing * 0.16).clamp(3.0, 12.0).toDouble();
  double gapMedium() => (spacing * 0.5).clamp(10.0, 28.0).toDouble();
  double gapLarge() => (spacing * 0.7).clamp(14.0, 36.0).toDouble();
}

/// Helper pour construire rapidement des métriques à l'intérieur d'un LayoutBuilder
ResponsiveMetrics buildResponsiveMetrics(BuildContext context, BoxConstraints constraints, {double? overrideMaxWidth}) {
  final s = useScreenSize(context);
  final Size box = constraints.biggest;
  final double shortest = box.shortestSide;
  final bool isWide = box.aspectRatio >= 0.70;
  final bool isTablet = shortest >= 600;
  final double scale = s.textScale();
  final double localScale = isTablet
      ? (shortest / 800.0).clamp(0.85, 1.2)
      : (shortest / 600.0).clamp(0.92, 1.45);
  final double spacing = isTablet
      ? (s.spacing() * localScale * 1.05).clamp(12.0, 40.0).toDouble()
      : s.spacing();
  final double maxWidth = overrideMaxWidth ?? (isTablet ? (isWide ? 1000.0 : 900.0) : 720.0);

  return ResponsiveMetrics(
    screen: s,
    box: box,
    shortest: shortest,
    isWide: isWide,
    isTablet: isTablet,
    scale: scale,
    localScale: localScale,
    spacing: spacing,
    maxWidth: maxWidth,
  );
}