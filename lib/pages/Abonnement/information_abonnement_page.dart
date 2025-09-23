import 'package:flutter/material.dart';
import '../../ui/responsive/responsive.dart';
import '../../widgets/boutons/bouton_universel.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'choix_offre_page.dart';
import '../../ui/animations/page_route_universelle.dart';
// import supprimé: premium_service

class InformationAbonnementPage extends StatelessWidget {
  const InformationAbonnementPage({super.key});

  static const double _baseW = 375;
  static const double _baseH = 812;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double scale = _computeScale(constraints.maxWidth, constraints.maxHeight);
          final double dx = (constraints.maxWidth - _baseW * scale) / 2;
          final double dy = (constraints.maxHeight - _baseH * scale) / 2;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0.93, 0.97),
                end: Alignment(0.09, 0.00),
                colors: [Colors.white, Color(0xEDFEB547), Color(0xFFFEC868)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: dx,
                  top: dy,
                  width: _baseW * scale,
                  height: _baseH * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: _FigmaExactLayer(),
                  ),
                ),
                // CTA rendu original à l'intérieur de la couche Figma (comme au départ)
                Positioned(
                  left: dx + 35.82 * scale,
                  top: dy + 688.60 * scale,
                  child: SizedBox(
                    width: 303.14 * scale,
                    height: 44.92 * scale,
                    child: BoutonUniversel(
                      onPressed: () {
                        // Aller choisir l'offre pour démarrer l'essai
                        Navigator.of(context).pushNamed('/abonnement/choix-offre');
                      },
                      size: BoutonUniverselTaille.small,
                      borderRadius: 10 * scale,
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                      backgroundColor: const Color(0xFFFCFCFE),
                      borderColor: const Color(0xB3858585),
                      shadowColor: const Color(0xB3858585),
                      child: Center(
                        child: Text(
                          'Essaye 3 jours gratuits',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF334355),
                            fontSize: 20 * scale,
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Lien direct vers "Gérer mon abonnement" (toujours disponible)
                Positioned(
                  left: dx + 35.82 * scale,
                  top: dy + (688.60 + 56) * scale,
                  child: SizedBox(
                    width: 303.14 * scale,
                    height: 40 * scale,
                    child: BoutonUniversel(
                      onPressed: () => Navigator.of(context).pushNamed('/abonnement/gerer'),
                      size: BoutonUniverselTaille.small,
                      borderRadius: 10 * scale,
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                      backgroundColor: const Color(0xFFFCFCFE),
                      borderColor: const Color(0xFFDADADA),
                      shadowColor: const Color(0x22000000),
                      child: Center(
                        child: Text(
                          'Gérer mon abonnement',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF334355),
                            fontSize: 16 * scale,
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // (Retiré) Bouton de test
              ],
            ),
          );
        },
      ),
    );
  }

  double _computeScale(double w, double h) {
    if (w <= 0 || h <= 0) return 1.0;
    final sx = w / _baseW;
    final sy = h / _baseH;
    return sx < sy ? sx : sy;
  }
}

Route _createLeftToRightRoute() => routePageUniverselle(const ChoixOffrePage(), sens: SensEntree.droite);

class _FigmaExactLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: Stack(
        children: [
          // Back arrow inside the page canvas
          Positioned(
            left: 26,
            top: 52,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: SvgPicture.asset(
                'assets/Images/Bouton/flechegauchecercle.svg',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          // Logo Premium (opposé au bouton retour)
          Positioned(
            right: 26,
            top: 52,
            child: SvgPicture.asset(
              'assets/Images/Bouton/logopremiumenvol.svg',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 268,
            top: 238,
            child: Container(
              width: 72,
              height: 337,
              decoration: BoxDecoration(
                color: const Color(0xBFABC270),
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x668BC34A),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Color(0x338BC34A),
                    blurRadius: 36,
                    spreadRadius: 8,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
          const _Separators(),
          const _Heading(),
          const _FeatureLabels(),
          const _FeatureMarkers(),
          const _PlanBadges(),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final double height;
  const _Line({
    // ignore: unused_element_parameter
    this.height = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xB3858585),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

// ignore: unused_element
class _Separators extends StatelessWidget {
  const _Separators();
  // Positions horizontales comme dans Figma: bloc de 303 px de large à partir de x=36
  static const double _left = 36;
  static const double _width = 303;
  static const double _gapBelow = 12;

  @override
  Widget build(BuildContext context) {
    final rows = _featureRows();
    final visibleRows = rows.take(rows.length - 1).toList();
    return Stack(
      children: visibleRows.map((r) {
        final size = _measureTextSize(r.text, _labelStyle(r.multiline));
        final double y = r.top + size.height + _gapBelow;
        return Positioned(left: _left, top: y, child: SizedBox(width: _width, child: const _Line()));
      }).toList(),
    );
  }
}

// ignore: unused_element
class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 121,
      top: 799,
      child: Opacity(
        opacity: 0.20,
        child: Container(
          width: 134,
          height: 5,
          decoration: ShapeDecoration(
            color: const Color(0xFF334355),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2.50),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 29,
      top: 128,
      child: SizedBox(
        width: 317,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            // Ligne 1 (toujours sur une ligne, se réduit si besoin)
            _FitOneLine(
              text: 'PRENDS TON ENVOL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                height: 1.11,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 8),
            // Ligne 2 (toujours sur une ligne, se réduit si besoin)
            _FitOneLine(
              text: 'LE MODE PREMIUM DE MINBIRD !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                height: 1.40,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FitOneLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _FitOneLine({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        overflow: TextOverflow.visible,
        style: style,
      ),
    );
  }
}

class _PlanBadges extends StatelessWidget {
  const _PlanBadges();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(
          left: 197,
          top: 244,
          child: Text(
            'GRATUIT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Positioned(
          left: 281,
          top: 244,
          child: Text(
            'ENVOL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow {
  final String text;
  final double top;
  final bool multiline;
  const _FeatureRow(this.text, this.top, this.multiline);
}

List<_FeatureRow> _featureRows() => const [
      _FeatureRow('MISSIONS & QUIZ', 274, false),
      _FeatureRow('VIES ILLIMITÉES', 318, false),
      _FeatureRow('QUIZ PERSONNALISÉS', 365, false),
      _FeatureRow('ACCÈS À TOUS\nLES HABITATS', 413, true),
      _FeatureRow('STATISTIQUES\nAVANCÉES', 480, true),
      _FeatureRow('PAS DE PUBS', 543, false),
    ];

TextStyle _labelStyle(bool multiline) => TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontFamily: 'Fredoka',
      fontWeight: FontWeight.w600,
      height: multiline ? 1.21 : 1.2,
    );

Size _measureTextSize(String text, TextStyle style, {double maxWidth = 280}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(minWidth: 0, maxWidth: maxWidth);
  return tp.size;
}

class _FeatureLabels extends StatelessWidget {
  const _FeatureLabels();
  @override
  Widget build(BuildContext context) {
    final rows = _featureRows();
    return Stack(
      children: rows
          .map((r) => Positioned(left: 36, top: r.top, child: Text(r.text, style: _labelStyle(r.multiline))))
          .toList(),
    );
  }
}

class _FeatureMarkers extends StatelessWidget {
  const _FeatureMarkers();
  // Positions de départ des libellés colonnes
  static const double _labelLeftGratuit = 197;
  // ignore: unused_field
  static const double _labelLeftEnvol = 281;

  // Y centraux des lignes de texte (alignés avec _FeatureLabels)
  // ignore: unused_field
  static const List<double> _ys = [
    274, // Missions & Quiz (1 ligne)
    318, // Vies illimitées (1 ligne)
    365, // Quiz personnalisés (1 ligne)
    413, // Accès à tous les habitats (2 lignes)
    480, // Statistiques avancées (2 lignes)
    543, // Pas de pubs (1 ligne)
  ];

  // Indices des libellés sur 2 lignes pour ajuster le centrage vertical du marqueur
  // ignore: unused_field
  static const Set<int> _multiline = {3, 4};

  double _measureTextWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.size.width;
  }

  Size _measureTextSize(String text, TextStyle style, {double maxWidth = 280}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    return tp.size;
  }

  @override
  Widget build(BuildContext context) {
    // Style des badges colonnes (doit matcher _PlanBadges)
    const TextStyle badgeStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontFamily: 'Fredoka',
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );
    final double gratuitCenterX = _labelLeftGratuit + _measureTextWidth('GRATUIT', badgeStyle) / 2;
    // Centre de la zone verte (colonne ENVOL) : rectangle à left=268, width=72 → centre = 304
    const double greenLeft = 268;
    const double greenWidth = 72;
    // final double greenCenterX = greenLeft + greenWidth / 2; // centre théorique, non nécessaire ici

    const double checkSize = 20;
    const double pillWidth = 22; // entre-deux
    const double pillHeight = 4;
    const double greenYOffset = -2; // remontée optique légère
    const double greenXOffset = 1.0; // micro-ajustement horizontal

    final rows = _featureRows();
    return Stack(
      children: [
        // ENVOL: centré verticalement sur le texte (1 ou 2 lignes)
        for (final r in rows)
          () {
            final size = _measureTextSize(r.text, _labelStyle(r.multiline));
            final double centerY = r.top + size.height / 2;
            final double topY = (centerY - checkSize / 2 + greenYOffset).roundToDouble();
            return Positioned(
              left: greenLeft,
              top: topY,
              width: greenWidth,
              child: SizedBox(
                height: checkSize,
                child: Transform.translate(
                  offset: Offset(greenXOffset, 0),
                  child: const Center(child: _Check(size: checkSize)),
                ),
              ),
            );
          }(),
        // GRATUIT: check sur la 1re ligne, pilules pour les autres
        () {
          final r0 = rows.first;
          final size0 = _measureTextSize(r0.text, _labelStyle(r0.multiline));
          final centerY0 = r0.top + size0.height / 2;
          return Positioned(
            left: gratuitCenterX - checkSize / 2,
            top: centerY0 - checkSize / 2,
            child: const _Check(size: checkSize),
          );
        }(),
        for (final r in rows.skip(1))
          () {
            final size = _measureTextSize(r.text, _labelStyle(r.multiline));
            final centerY = r.top + size.height / 2;
            return Positioned(
              left: gratuitCenterX - pillWidth / 2,
              top: centerY - pillHeight / 2,
              child: const _PillLine(width: pillWidth, height: pillHeight),
            );
          }(),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final double size;
  const _Check({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/Images/Bouton/check.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _PillLine extends StatelessWidget {
  final double width;
  final double height;
  const _PillLine({this.width = 21, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

// ignore: unused_element
class _HeaderTitle extends StatelessWidget {
  final ResponsiveMetrics m;
  const _HeaderTitle({required this.m});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'PRENDS TON ENVOL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Fredoka',
            fontSize: m.font(28),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            height: 1.11,
          ),
        ),
        SizedBox(height: m.gapSmall()),
        Text(
          'LE MODE PREMIUM DE MINBIRD !',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Fredoka',
            fontSize: m.font(20),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _PlansToggle extends StatelessWidget {
  final ResponsiveMetrics m;
  const _PlansToggle({required this.m});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pill(text: 'GRATUIT', m: m),
        SizedBox(width: m.dp(12)),
        _Pill(text: 'ENVOL', m: m, selected: true),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final ResponsiveMetrics m;
  final bool selected;
  const _Pill({required this.text, required this.m, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final Color border = Colors.white;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: border, width: 2),
        ),
        color: selected ? const Color(0x22FFFFFF) : Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: m.dp(14), vertical: m.dp(8)),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w700,
            fontSize: m.font(13),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _BenefitsList extends StatelessWidget {
  final ResponsiveMetrics m;
  const _BenefitsList({required this.m});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'MISSIONS & QUIZ',
      'VIES ILLIMITÉES',
      'QUIZ PERSONNALISÉS',
      'ACCÈS À TOUS\nLES HABITATS',
      'STATISTIQUES\nAVANCÉES',
      'PAS DE PUBS',
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: m.dp(10)),
      child: Column(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: m.dp(8)),
              child: Opacity(
                opacity: 0.65,
                child: Divider(
                  color: const Color(0xE5858585),
                  thickness: 2,
                ),
              ),
            );
          }
          final label = items[i ~/ 2];
          return Padding(
            padding: EdgeInsets.symmetric(vertical: m.dp(4)),
            child: Text(
              label,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                fontSize: m.font(14),
                height: label.contains('\\n') ? 1.21 : 1.2,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// (Supprimé) Ancien badge d'essai redondant


