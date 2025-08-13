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
