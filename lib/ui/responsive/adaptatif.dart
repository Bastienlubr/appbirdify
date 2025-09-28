import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Nouveau système adaptatif pour trois supports: téléphone, tablette, ordinateur (desktop)
/// Utilisation typique:
/// LayoutBuilder(
///   builder: (context, constraints) {
///     final m = buildAdaptiveMetrics(context, constraints);
///     return ConstrainedBox(
///       constraints: BoxConstraints(maxWidth: m.contentMaxWidth),
///       child: ...
///     );
///   },
/// )

enum AdaptiveDevice { phone, tablet, desktop }

class AdaptiveScreenDimensions {
  final double width;
  final double height;
  final double shortest;
  final double longest;
  const AdaptiveScreenDimensions({
    required this.width,
    required this.height,
  })  : shortest = width < height ? width : height,
        longest = width > height ? width : height;
}

class AdaptiveMetrics {
  final AdaptiveDevice device;
  final Size box;
  final bool isWide; // aspect >= 0.70 approximativement paysage/large

  // Echelles et espacements
  final double typographyScale; // échelle globale de typo
  final double componentScale;  // échelle locale des composants (dp)
  final double spacing;         // espacement de base harmonisé

  // Mise en page
  final double contentMaxWidth; // largeur max du contenu centré
  final int columns;            // colonnes recommandées (grid/layout desktop)

  // Dimensions auxiliaires
  final AdaptiveScreenDimensions screen;

  const AdaptiveMetrics({
    required this.device,
    required this.box,
    required this.isWide,
    required this.typographyScale,
    required this.componentScale,
    required this.spacing,
    required this.contentMaxWidth,
    required this.columns,
    required this.screen,
  });

  bool get isPhone => device == AdaptiveDevice.phone;
  bool get isTablet => device == AdaptiveDevice.tablet;
  bool get isDesktop => device == AdaptiveDevice.desktop;

  double font(double base, {double min = 12, double max = 72, double tabletFactor = 1.06, double desktopFactor = 1.18}) {
    final double factor = isDesktop ? desktopFactor : (isTablet ? tabletFactor : 1.0);
    return (base * typographyScale * factor).clamp(min, max).toDouble();
  }

  double dp(double base, {double min = 0, double max = 10000, double tabletFactor = 1.00, double desktopFactor = 1.06}) {
    final double factor = isDesktop ? (componentScale * desktopFactor) : (isTablet ? (componentScale * tabletFactor) : componentScale);
    return (base * factor).clamp(min, max).toDouble();
  }

  double gapSmall() => (spacing * 0.16).clamp(3.0, 14.0).toDouble();
  double gapMedium() => (spacing * 0.5).clamp(10.0, 32.0).toDouble();
  double gapLarge() => (spacing * 0.7).clamp(14.0, 40.0).toDouble();
}

AdaptiveDevice _classifyDevice(double width, double shortest) {
  // Règles simples et prévisibles
  // - Desktop: largeurs >= 1024 (typiquement écrans ordi). Sur Web, on privilégie la largeur.
  // - Tablet: shortestSide >= 600 et largeur < 1024
  // - Phone: sinon
  if (width >= 1024.0) return AdaptiveDevice.desktop;
  if (shortest >= 600.0) return AdaptiveDevice.tablet;
  return AdaptiveDevice.phone;
}

double _computeTypographyScale(AdaptiveDevice device, AdaptiveScreenDimensions s) {
  // Echelle globale de typo progressive
  switch (device) {
    case AdaptiveDevice.phone:
      return (s.shortest / 600.0).clamp(0.96, 1.18);
    case AdaptiveDevice.tablet:
      return (s.shortest / 800.0).clamp(1.05, 1.30);
    case AdaptiveDevice.desktop:
      return (s.width / 1440.0).clamp(1.10, 1.40);
  }
}

double _computeComponentScale(AdaptiveDevice device, AdaptiveScreenDimensions s) {
  switch (device) {
    case AdaptiveDevice.phone:
      return (s.shortest / 600.0).clamp(0.92, 1.20);
    case AdaptiveDevice.tablet:
      return (s.shortest / 800.0).clamp(0.95, 1.25);
    case AdaptiveDevice.desktop:
      return (s.width / 1440.0).clamp(1.00, 1.30);
  }
}

double _computeBaseSpacing(AdaptiveDevice device, AdaptiveScreenDimensions s) {
  final double base;
  switch (device) {
    case AdaptiveDevice.phone:
      base = 18.0;
      break;
    case AdaptiveDevice.tablet:
      base = 24.0;
      break;
    case AdaptiveDevice.desktop:
      base = 28.0;
      break;
  }
  // Ajustement léger par la composante d'échelle pour garder un rythme spatial homogène
  final double factor = _computeComponentScale(device, s);
  return (base * factor).clamp(12.0, 48.0).toDouble();
}

({double maxWidth, int columns}) _computeLayoutGuides(AdaptiveDevice device, bool isWide) {
  switch (device) {
    case AdaptiveDevice.phone:
      return (maxWidth: 720.0, columns: 2);
    case AdaptiveDevice.tablet:
      return (maxWidth: isWide ? 1100.0 : 1000.0, columns: isWide ? 6 : 5);
    case AdaptiveDevice.desktop:
      return (maxWidth: isWide ? 1320.0 : 1200.0, columns: 12);
  }
}

AdaptiveMetrics buildAdaptiveMetrics(BuildContext context, BoxConstraints constraints, {double? overrideMaxWidth, int? overrideColumns}) {
  final Size box = constraints.biggest;
  final double width = box.width;
  final double height = box.height;
  final AdaptiveScreenDimensions s = AdaptiveScreenDimensions(width: width, height: height);
  final bool isWide = box.aspectRatio >= 0.70;

  // Classification
  AdaptiveDevice device = _classifyDevice(width, s.shortest);

  // Sur Web avec écrans très larges, forcer desktop
  if (kIsWeb && width >= 1024.0) {
    device = AdaptiveDevice.desktop;
  }

  final double typographyScale = _computeTypographyScale(device, s);
  final double componentScale = _computeComponentScale(device, s);
  final double spacing = _computeBaseSpacing(device, s);
  final guides = _computeLayoutGuides(device, isWide);

  final double contentMaxWidth = overrideMaxWidth ?? guides.maxWidth;
  final int columns = overrideColumns ?? guides.columns;

  return AdaptiveMetrics(
    device: device,
    box: box,
    isWide: isWide,
    typographyScale: typographyScale,
    componentScale: componentScale,
    spacing: spacing,
    contentMaxWidth: contentMaxWidth,
    columns: columns,
    screen: s,
  );
}


