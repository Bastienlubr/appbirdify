import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/boutons/bouton_universel.dart';

class GererMonAbonnementPage extends StatelessWidget {
  const GererMonAbonnementPage({
    super.key,
    this.headerLeftMargin = 26,
    this.headerIconSize = 36,
    this.headerRightSpacer = 62,
    this.titleHorizontalOffset = 4,
    this.headerTop = 52,
  });

  final double headerLeftMargin; // marge gauche avant la flèche
  final double headerIconSize; // taille de l'icône/flèche
  final double headerRightSpacer; // espace à droite pour centrage optique
  final double titleHorizontalOffset; // micro-ajustement horizontal du texte
  final double headerTop; // position verticale du header

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
              color: Color(0xFFF2F5F8),
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
                    child: _Canvas(
                      headerLeftMargin: headerLeftMargin,
                      headerIconSize: headerIconSize,
                      headerRightSpacer: headerRightSpacer,
                      titleHorizontalOffset: titleHorizontalOffset,
                      headerTop: headerTop,
                    ),
                  ),
                ),
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

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.headerLeftMargin,
    required this.headerIconSize,
    required this.headerRightSpacer,
    required this.titleHorizontalOffset,
    required this.headerTop,
  });

  final double headerLeftMargin;
  final double headerIconSize;
  final double headerRightSpacer;
  final double titleHorizontalOffset;
  final double headerTop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: Stack(
        children: [
          // En-tête: flèche gauche + titre centré optiquement (placeholder symétrique à droite)
          Positioned(
            left: 0,
            top: headerTop,
            child: SizedBox(
              width: 375,
              height: 36,
              child: Row(
                children: [
                  SizedBox(width: headerLeftMargin),
                  SizedBox(
                    width: headerIconSize,
                    height: headerIconSize,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(
                        'assets/Images/Bouton/flechegauchecercle.svg',
                        width: headerIconSize,
                        height: headerIconSize,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(Color(0xFF334355), BlendMode.srcIn),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(titleHorizontalOffset, 0),
                        child: const Text(
                          'Gérer mon abonnement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF334355),
                            fontSize: 20,
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: headerRightSpacer),
                ],
              ),
            ),
          ),

          // Statut
          const Positioned(
            left: 81,
            top: 151,
            child: Text(
              ' Abonnement en cours...',
              style: TextStyle(
                color: Color(0xFF334355),
                fontSize: 20,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Carte d'information (fond)
          Positioned(
            left: 36,
            top: 192,
            child: Container(
              width: 303,
              height: 101,
              decoration: ShapeDecoration(
                color: const Color(0xFFFCFCFE),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 3, color: Color(0xFFDADADA)),
                  borderRadius: BorderRadius.circular(10),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x153C7FD0),
                    blurRadius: 19,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),

          // Détails d'essai et de facturation
          const Positioned(
            left: 48,
            top: 206,
            child: Text(
              'Essai gratuit (2 jours restants)',
              style: TextStyle(
                color: Color(0xFF334355),
                fontSize: 15,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Positioned(
            left: 47,
            top: 232,
            child: SizedBox(
              width: 288,
              child: Text(
                'Les paiements mensuels récurrents commenceront le 10 septembre 2025',
                style: TextStyle(
                  color: Color(0x8C334355),
                  fontSize: 15,
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Bouton Résilier l'abonnement (BoutonUniversel)
          Positioned(
            left: 49.09,
            top: 318.45,
            child: SizedBox(
              width: 274.82,
              height: 40.73,
              child: BoutonUniversel(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Action disponible bientôt: résiliation')),
                  );
                },
                size: BoutonUniverselTaille.small,
                borderRadius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                backgroundColor: const Color(0xFFFCFCFE),
                hoverBackgroundColor: const Color(0xFFEDEDED),
                borderColor: const Color(0xFFDADADA),
                hoverBorderColor: const Color(0xFFDADADA),
                shadowColor: const Color(0xFFDADADA),
                child: const Center(
                  child: Text(
                    ' Résilier l’abonnement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF334355),
                      fontSize: 17,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Home indicator
          Positioned(
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
          ),
        ],
      ),
    );
  }
}


