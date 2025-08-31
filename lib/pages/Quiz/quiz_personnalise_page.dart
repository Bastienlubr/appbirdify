import 'package:flutter/material.dart';
import '../../ui/responsive/responsive.dart';

class QuizPersonnalisePage extends StatefulWidget {
  const QuizPersonnalisePage({super.key});

  @override
  State<QuizPersonnalisePage> createState() => _QuizPersonnalisePageState();
}

class _QuizPersonnalisePageState extends State<QuizPersonnalisePage> {
  int? _selectedIndex;

  double pointerAlignForIndex(int idx) {
    // Aligne la tétine au centre de la carte: gauche = -0.5, droite = +0.5
    return (idx % 2 == 0) ? -0.5 : 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final bg = const Color(0xFFF2F5F8);

        // Données des cartes (titres, images, descriptions)
        final List<String> titles = [
          'Les plus\ncommuns de france',
          'Les 15 plus belles voix',
          'Les \ninsomniaques',
          'Les DJ de la nature',
        ];
        final List<String> images = [
          'https://placehold.co/139x78',
          'https://placehold.co/131x73',
          'https://placehold.co/136x76',
          'https://placehold.co/130x73',
        ];
        final List<String> descriptions = [
          'Ce quiz réunit les oiseaux que tu croises tous les jours, en ville ou en balade. Le but : mettre un nom sur ces voix familières qu’on entend partout… mais qu’on reconnaît rarement.',
          'Une sélection de 15 chants remarquables, mélodieux ou emblématiques, pour entraîner ton oreille.',
          'Ces oiseaux aiment chanter tôt le matin ou tard le soir. Parfait pour les couche-tard et l’aube !',
          'Rythmes, imitations et surprises : des chanteurs créatifs qui maîtrisent le sampling à la perfection.',
        ];

        // Tailles agrandies des cartes
        final double horizontalPadding = m.dp(24);
        final double gutter = m.dp(16);
        final double innerWidth = constraints.maxWidth - horizontalPadding * 2;
        final double cardWidth = (innerWidth - gutter) / 2;
        final double cardHeight = cardWidth * 0.96;
        final double topImageHeight = cardHeight * 0.52;

        return Container(
          color: bg,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: m.dp(24), vertical: m.dp(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TabLabel(
                        label: 'QUIZ',
                        selected: true,
                      ),
                      SizedBox(width: m.dp(24)),
                      _TabLabel(
                        label: 'PLAYLIST',
                        selected: false,
                      ),
                    ],
                  ),
                  SizedBox(height: m.dp(16)),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _SmallQuizCard(
                              width: cardWidth,
                              height: cardHeight,
                              topImageHeight: topImageHeight,
                              title: titles[0],
                              imageUrl: images[0],
                              selected: _selectedIndex == 0,
                              onTap: () => setState(() => _selectedIndex = 0),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: m.dp(16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _SmallQuizCard(
                              width: cardWidth,
                              height: cardHeight,
                              topImageHeight: topImageHeight,
                              title: titles[1],
                              imageUrl: images[1],
                              selected: _selectedIndex == 1,
                              onTap: () => setState(() => _selectedIndex = 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: (_selectedIndex == 0 || _selectedIndex == 1)
                        ? Padding(
                            padding: EdgeInsets.only(top: m.dp(0), bottom: m.dp(16)),
                            child: Transform.translate(
                              offset: Offset(0, -m.dp(22)),
                              child: _WideDescriptionPanel(
                                corner: m.dp(14),
                                title: titles[_selectedIndex!].replaceAll('\n', ' '),
                                description: descriptions[_selectedIndex!],
                                pointerXAlign: pointerAlignForIndex(_selectedIndex!),
                                onContinuer: () {},
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  SizedBox(height: m.dp(16)),

                  // Seconde rangée
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _SmallQuizCard(
                              width: cardWidth,
                              height: cardHeight,
                              topImageHeight: topImageHeight,
                              title: titles[2],
                              imageUrl: images[2],
                              selected: _selectedIndex == 2,
                              onTap: () => setState(() => _selectedIndex = 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: m.dp(16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _SmallQuizCard(
                              width: cardWidth,
                              height: cardHeight,
                              topImageHeight: topImageHeight,
                              title: titles[3],
                              imageUrl: images[3],
                              selected: _selectedIndex == 3,
                              onTap: () => setState(() => _selectedIndex = 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: (_selectedIndex == 2 || _selectedIndex == 3)
                        ? Padding(
                            padding: EdgeInsets.only(top: m.dp(0), bottom: m.dp(16)),
                            child: Transform.translate(
                              offset: Offset(0, -m.dp(22)),
                              child: _WideDescriptionPanel(
                                corner: m.dp(14),
                                title: titles[_selectedIndex!].replaceAll('\n', ' '),
                                description: descriptions[_selectedIndex!],
                                pointerXAlign: pointerAlignForIndex(_selectedIndex!),
                                onContinuer: () {},
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  SizedBox(height: m.dp(40)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _TabLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Text(
      ' $label',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFF334355),
        fontSize: 14,
        fontFamily: 'Quicksand',
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        letterSpacing: 1,
      ),
    );
  }
}

class _SmallQuizCard extends StatelessWidget {
  final double width;
  final double height;
  final double topImageHeight;
  final String title;
  final String imageUrl;
  final bool selected;
  final VoidCallback? onTap;

  const _SmallQuizCard({
    required this.width,
    required this.height,
    required this.topImageHeight,
    required this.title,
    required this.imageUrl,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(15);
    return InkWell(
      borderRadius: BorderRadius.circular(radius.x),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: selected ? const Color(0xFF473C33) : Colors.transparent,
                      width: selected ? 3 : 0,
                    ),
                    borderRadius: BorderRadius.circular(radius.x),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: width,
              height: topImageHeight,
              child: Container(
                decoration: ShapeDecoration(
                  color: const Color(0xFFD0D5DD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: width,
              height: topImageHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: topImageHeight,
              width: width,
              height: height - topImageHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF334355),
                      fontSize: 16,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionPanel extends StatelessWidget {
  final double width;
  final double corner;
  final String title;
  final String description;
  final VoidCallback onContinuer;

  const _DescriptionPanel({
    required this.width,
    required this.corner,
    required this.title,
    required this.description,
    required this.onContinuer,
  });

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF6A994E);
    return Container(
      width: width,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(23, 16, 23, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF334355),
                  fontSize: 18,
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF334355),
                fontSize: 16,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: onContinuer,
                child: Container(
                  width: 140,
                  height: 32,
                  decoration: ShapeDecoration(
                    color: green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x4C5468FF),
                        blurRadius: 25,
                        offset: Offset(0, 10),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 14,
                        top: 9,
                        child: Container(
                          width: 12.5,
                          height: 12.5,
                          decoration: const ShapeDecoration(
                            color: Colors.white,
                            shape: OvalBorder(),
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          ' Continuer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideDescriptionPanel extends StatelessWidget {
  final double corner;
  final String title;
  final String description;
  final double pointerXAlign; // -1.0 .. 1.0 (position horizontale de la tétine)
  final VoidCallback onContinuer;

  const _WideDescriptionPanel({
    required this.corner,
    required this.title,
    required this.description,
    required this.pointerXAlign,
    required this.onContinuer,
  });

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF6A994E);
    // Couleurs et styles inspirés du popover vies, adaptés au panneau blanc
    const Color fillColor = Colors.white;
    const Color strokeColor = Color(0xFF473C33);
    const double borderWidth = 3.0;
    final double cornerRadius = corner;
    const EdgeInsets contentPadding = EdgeInsets.fromLTRB(23, 52, 23, 16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Convertit l’alignement (-1..1) en position X en pixels, avec marges de sécurité
        final double rawCenter = (pointerXAlign + 1) * 0.5 * width;
        final double arrowCenterX = rawCenter.clamp(24.0, width - 24.0);
        const double arrowWidth = 24.0; // proportion similaire au popover
        const double arrowHeight = 18.0;

        return CustomPaint(
          painter: _IntegratedBubblePainterQuiz(
            fillColor: fillColor,
            strokeColor: strokeColor,
            borderWidth: borderWidth,
            cornerRadius: cornerRadius,
            arrowCenterX: arrowCenterX,
            arrowWidth: arrowWidth,
            arrowHeight: arrowHeight,
            topInset: contentPadding.top,
          ),
          child: Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF334355),
                      fontSize: 18,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF334355),
                    fontSize: 16,
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: onContinuer,
                    child: Container(
                      width: 140,
                      height: 32,
                      decoration: ShapeDecoration(
                        color: green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x4C5468FF),
                            blurRadius: 25,
                            offset: Offset(0, 10),
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          ' Continuer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntegratedBubblePainterQuiz extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double borderWidth;
  final double cornerRadius;
  final double arrowCenterX;
  final double arrowWidth;
  final double arrowHeight;
  final double topInset;

  _IntegratedBubblePainterQuiz({
    required this.fillColor,
    required this.strokeColor,
    required this.borderWidth,
    required this.cornerRadius,
    required this.arrowCenterX,
    required this.arrowWidth,
    required this.arrowHeight,
    required this.topInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = borderWidth / 2;
    final double right = size.width - borderWidth / 2;
    final double bottom = size.height - borderWidth / 2;
    final double top = topInset;

    final double baseLeft = (arrowCenterX - arrowWidth / 2).clamp(left + cornerRadius, right - cornerRadius);
    final double baseRight = (arrowCenterX + arrowWidth / 2).clamp(left + cornerRadius, right - cornerRadius);
    final double tipY = top - arrowHeight;

    final Path path = Path();
    path.moveTo(left + cornerRadius, top);
    path.lineTo(baseLeft, top);
    // Triangle intégré avec pointe arrondie
    final double half = arrowWidth * 0.5;
    path.lineTo(arrowCenterX - half, top);
    path.quadraticBezierTo(arrowCenterX, tipY, arrowCenterX + half, top);
    path.lineTo(baseRight, top);
    path.lineTo(right - cornerRadius, top);
    path.arcToPoint(Offset(right, top + cornerRadius), radius: Radius.circular(cornerRadius));
    path.lineTo(right, bottom - cornerRadius);
    path.arcToPoint(Offset(right - cornerRadius, bottom), radius: Radius.circular(cornerRadius));
    path.lineTo(left + cornerRadius, bottom);
    path.arcToPoint(Offset(left, bottom - cornerRadius), radius: Radius.circular(cornerRadius));
    path.lineTo(left, top + cornerRadius);
    path.arcToPoint(Offset(left + cornerRadius, top), radius: Radius.circular(cornerRadius));

    // Ombre douce
    canvas.drawShadow(path, Colors.black.withAlpha(30), 14, true);

    // Remplissage
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Contour
    final Paint stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _IntegratedBubblePainterQuiz old) {
    return old.fillColor != fillColor ||
        old.strokeColor != strokeColor ||
        old.borderWidth != borderWidth ||
        old.cornerRadius != cornerRadius ||
        old.arrowCenterX != arrowCenterX ||
        old.arrowWidth != arrowWidth ||
        old.arrowHeight != arrowHeight ||
        old.topInset != topInset;
  }
}


