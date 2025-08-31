import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/Users/life_service.dart';
import '../../../widgets/recap_button.dart';

class LivesPopover extends StatefulWidget {
  final int currentLives;
  final Offset anchor;
  final VoidCallback onClose;

  const LivesPopover({
    super.key,
    required this.currentLives,
    required this.anchor,
    required this.onClose,
  });

  @override
  State<LivesPopover> createState() => LivesPopoverState();
}

class LivesPopoverState extends State<LivesPopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    )..forward();
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void dismissWithAnimation({VoidCallback? onCompleted}) {
    if (!_controller.isAnimating && _controller.status == AnimationStatus.completed) {
      _controller.reverse().then((_) {
        onCompleted?.call();
      });
    } else {
      onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const double margin = 8.0;
    final double popWidth = size.width - margin * 2;
    final double left = margin;
    final double arrowSize = 12.0;
    final double topOffset = -10.0; // popover plus haut

    // Centre de la flèche (x) relatif au bord gauche du popover
    final double arrowCenterX = (widget.anchor.dx - left).clamp(24.0, popWidth - 24.0);

    return Stack(
      children: [
        // Dim backdrop touch-to-dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => dismissWithAnimation(onCompleted: widget.onClose),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Popover card + arrow (animated)
        Positioned(
          top: widget.anchor.dy + arrowSize + topOffset,
          left: left,
          width: popWidth,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              final double t = _curve.value;
              final double dy = (1.0 - t) * -4.0; // léger slide depuis le widget
              final double scale = 0.96 + 0.04 * t; // zoom subtil

              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                    child: child!,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: _PopoverCard(
                currentLives: widget.currentLives,
                arrowCenterX: arrowCenterX,
                arrowSize: 12.0,
                onClose: widget.onClose,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopoverCard extends StatelessWidget {
  final int currentLives;
  final double arrowCenterX;
  final double arrowSize;
  final VoidCallback onClose;

  const _PopoverCard({
    required this.currentLives,
    required this.arrowCenterX,
    required this.arrowSize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const EdgeInsets contentPadding = EdgeInsets.fromLTRB(16, 16, 16, 20);
    return CustomPaint(
      painter: _IntegratedBubblePainter(
        fillColor: const Color(0xFFD2DBB2),
        strokeColor: const Color(0xFF473C33),
        borderWidth: 3.0,
        cornerRadius: 16,
        arrowCenterX: arrowCenterX,
        arrowWidth: arrowSize * 2.6,
        arrowHeight: arrowSize * 1.6,
        topInset: contentPadding.top,
      ),
      child: Padding(
        padding: contentPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Vies restantes',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF344356),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _FirestoreLivesRow(fallbackCurrent: currentLives),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: RecapButton(
                text: 'Regarder une pub\npour +1 vie',
                onPressed: onClose,
                size: RecapButtonSize.small,
                fontSize: 16,
                visualScale: 1.5,
                lineHeight: 0.95,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: 10,
                fontFamily: 'Fredoka',
                backgroundColor: const Color(0xFFABC270),
                hoverBackgroundColor: const Color(0xFFABC270),
                textColor: Colors.white,
                borderColor: const Color(0xFF6A994E),
                hoverBorderColor: const Color(0xFF6A994E),
                shadowColor: const Color(0xFF6A994E),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: RecapButton(
                text: 'Avec Premium \nPasse en mode illimité',
                onPressed: onClose,
                size: RecapButtonSize.small,
                fontSize: 16,
                visualScale: 1.5,
                lineHeight: 0.95,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: 10,
                fontFamily: 'Fredoka',
                backgroundColor: const Color(0xFFFEC868),
                hoverBackgroundColor: const Color(0xFFFEC868),
                textColor: Colors.white,
                borderColor: const Color(0xFFE89E1C),
                hoverBorderColor: const Color(0xFFE89E1C),
                shadowColor: const Color(0xFFE89E1C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ArrowPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth = 1.5;
  _ArrowPainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = (w < h ? w : h) * 0.18; // rayon pour arrondir la pointe

    // Remplissage (triangle avec pointe arrondie)
    final Path fillPath = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.5 - r, r)
      ..quadraticBezierTo(w * 0.5, 0, w * 0.5 + r, r)
      ..lineTo(w, h)
      ..close();

    // Shadow
    canvas.drawShadow(fillPath, Colors.black.withAlpha(40), 8, true);

    // Border
    final Paint stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Tracer uniquement les côtés, pas la base
    final Path leftSide = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.5 - r, r);
    final Path rightSide = Path()
      ..moveTo(w, h)
      ..lineTo(w * 0.5 + r, r);
    canvas.drawPath(leftSide, stroke);
    canvas.drawPath(rightSide, stroke);

    // Fill
    final Paint fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fill);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor || oldDelegate.strokeWidth != strokeWidth;
}

class _IntegratedBubblePainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double borderWidth;
  final double cornerRadius;
  final double arrowCenterX;
  final double arrowWidth;
  final double arrowHeight;
  final double topInset;

  _IntegratedBubblePainter({
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
    // Triangle isocèle à pointe arrondie, intégré au rectangle
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

    // Ombre
    canvas.drawShadow(path, Colors.black.withAlpha(30), 14, true);

    // Remplir
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
  bool shouldRepaint(covariant _IntegratedBubblePainter old) {
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

class _LivesRow extends StatelessWidget {
  final int currentLives;
  const _LivesRow({required this.currentLives});

  @override
  Widget build(BuildContext context) {
    const int maxLives = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLives, (index) {
        final bool filled = index < currentLives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Opacity(
            opacity: filled ? 1.0 : 0.35,
            child: Image.asset(
              'assets/Images/Bouton/vie.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
        );
      }),
    );
  }
}

class _FirestoreLivesRow extends StatelessWidget {
  final int fallbackCurrent;
  const _FirestoreLivesRow({required this.fallbackCurrent});

  @override
  Widget build(BuildContext context) {
    final String? uid = LifeService.getCurrentUserId();
    if (uid == null) {
      return _LivesRow(currentLives: fallbackCurrent);
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('utilisateurs').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LivesRow(currentLives: fallbackCurrent);
        }
        if (!snapshot.hasData) {
          return _LivesRow(currentLives: fallbackCurrent);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final Map<String, dynamic>? vie = data?['vie'] is Map<String, dynamic>
            ? (data?['vie'] as Map<String, dynamic>)
            : null;
        final int maxLives = (vie?['vieMaximum'] as int? ?? 5).clamp(1, 50);
        final int displayCap = 10;
        final int rawCurrent = (vie?['vieRestante'] as int? ?? fallbackCurrent).clamp(0, 9999);
        final int current = rawCurrent.clamp(0, maxLives);

        // Autoscaling multi-lignes (max 2 lignes). Calcule une taille d'icône qui rentre.
        return LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            const double baseSize = 56.0;
            const double minSize = 22.0;
            const double maxSize = 56.0;
            const double minGap = 3.0;

            // Cap d'affichage: maximum 10 coeurs visibles
            final int displayCount = maxLives >= displayCap ? displayCap : maxLives;
            // Agrégateur: afficher le nombre de vies AU-DELA de 10 (selon les vies ACTUELLES non clampées à 10)
            final bool showAggregator = rawCurrent > displayCap && displayCount == displayCap;
            final int overflowCount = showAggregator ? (rawCurrent - displayCap) : 0;

            int rows = 1;
            double iconSize = maxSize;
            double gap = minGap;

            double computeSizeFor(int columns) {
              final double totalGaps = (columns - 1) * minGap;
              return ((availableWidth - totalGaps) / columns).clamp(minSize, maxSize);
            }

            // Essayer sur 1 ligne, puis 2 lignes si nécessaire
            int columns = displayCount;
            iconSize = computeSizeFor(columns);
            if (iconSize < minSize || displayCount > 7) {
              rows = 2;
              columns = (displayCount / rows).ceil();
              iconSize = computeSizeFor(columns);
            }
            gap = (iconSize / baseSize * 4.0).clamp(2.0, 8.0);

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: List.generate(displayCount, (index) {
                final bool isAggregator = showAggregator && index == displayCount - 1;
                final bool filled = index < (current.clamp(0, displayCount));

                if (isAggregator) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: filled ? 1.0 : 0.28,
                        child: Image.asset(
                          'assets/Images/Bouton/vie.png',
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Compteur des coeurs supplémentaires
                      Text(
                        overflowCount.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w700,
                          fontSize: (iconSize * 0.42).clamp(10.0, 28.0),
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Opacity(
                  opacity: filled ? 1.0 : 0.28,
                  child: Image.asset(
                    'assets/Images/Bouton/vie.png',
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

// ignore: unused_element
class _LayeredButton extends StatelessWidget {
  final Color outerColor;
  final Color innerColor;
  final String text;
  final Color textColor;
  final double height;
  final VoidCallback onTap;

  const _LayeredButton({
    required this.outerColor,
    required this.innerColor,
    required this.text,
    required this.textColor,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        children: [
          Container(
            decoration: ShapeDecoration(
              color: outerColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              shadows: const [
                BoxShadow(
                  color: Color(0x153C7FD0),
                  blurRadius: 19,
                  offset: Offset(0, 12),
                )
              ],
            ),
          ),
          Positioned(
            left: 2.4,
            top: 1.8,
            right: 2.4,
            bottom: 2.2,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: innerColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                shadows: const [
                  BoxShadow(
                    color: Color(0x153C7FD0),
                    blurRadius: 19,
                    offset: Offset(0, 12),
                  )
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                    height: 0.95,
                    letterSpacing: 1,
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


