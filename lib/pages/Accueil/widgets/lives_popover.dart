import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
// Removed flutter_svg import; using PNG heart asset for performance/consistency
import '../../../services/Users/life_service.dart';
import '../../../services/ads/ad_service.dart';
import '../../../services/Users/user_orchestra_service.dart';
import '../../../widgets/boutons/bouton_universel.dart';
import '../../../ui/animations/transitions.dart';

class LivesPopover extends StatefulWidget {
  final int currentLives;
  final Offset anchor;
  final VoidCallback onClose;
  final void Function(int newLives)? onLivesChanged;
  // Mode préchauffage: rendu invisible, sans animation ni interaction, pour charger les ressources/layout
  final bool prewarm;

  const LivesPopover({
    super.key,
    required this.currentLives,
    required this.anchor,
    required this.onClose,
    this.onLivesChanged,
    this.prewarm = false,
  });

  // Précharge les assets utilisés par le popover afin d'éviter les janks au premier affichage
  static Future<void> precacheAssets(BuildContext context) async {
    final List<Future<void>> tasks = [
      precacheImage(const AssetImage('assets/Images/Bouton/vie.png'), context),
    ];
    try {
      await Future.wait(tasks);
    } catch (_) {
      // Ignorer silencieusement le préchargement en cas d'échec
    }
  }

  @override
  State<LivesPopover> createState() => LivesPopoverState();
}

class LivesPopoverState extends State<LivesPopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _opening = false; // Bascule vers contenu complet après l'anim
          });
        }
      });
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic, reverseCurve: Curves.easeInOutCubic);

    if (widget.prewarm) {
      _opening = false;
      _controller.value = 1.0; // rendu final directement
    } else {
      // Démarrer immédiatement pour éviter tout effet "pop"
      _controller.value = 0.001;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void dismissWithAnimation({VoidCallback? onCompleted}) {
    // Toujours animer la fermeture depuis la valeur courante pour une symétrie parfaite
    final double start = _controller.value.clamp(0.0, 1.0);
    _controller.reverse(from: start).whenComplete(() {
      onCompleted?.call();
    });
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

    final Widget content = Stack(
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
            builder: (context, _) {
              final double t = _curve.value;
              // Ombre légère au début → pleine à la fin
              final double eased = Curves.easeInOutCubic.transform(t);
              final int shadowAlpha = lerpDouble(12.0, 30.0, eased)!.toInt(); // 12 → 30
              final double shadowBlur = lerpDouble(6.0, 14.0, eased)!;        // 6 → 14

              // Transition totalement unifiée: seul un fondu global est appliqué
              // La bulle (fond/contour/flèche) reste à sa valeur finale pendant le fade
              final double fillOpacity = 1.0;
              final double strokeOpacity = 1.0;
              final double animatedArrowHeight = arrowSize * 1.6;

              return Opacity(
                opacity: eased,
                child: Stack(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: RepaintBoundary(
                        child: _PopoverCard(
                          currentLives: widget.currentLives,
                          arrowCenterX: arrowCenterX,
                          arrowSize: 12.0,
                          onClose: widget.onClose,
                          onNavigateToInfo: () {
                            dismissWithAnimation(onCompleted: () {
                              widget.onClose();
                              Navigator.of(context).pushNamed('/abonnement/information');
                            });
                          },
                          onLivesChanged: widget.onLivesChanged,
                          deferContent: _opening || widget.prewarm,
                          shadowAlphaOverride: shadowAlpha,
                          shadowBlurOverride: shadowBlur,
                          fillOpacityOverride: fillOpacity,
                          strokeOpacityOverride: strokeOpacity,
                          arrowHeightOverride: animatedArrowHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    if (widget.prewarm) {
      // Rendre quasiment invisible mais peindre une fois pour préchauffer les caches
      return IgnorePointer(
        ignoring: true,
        child: Opacity(opacity: 0.01, child: content),
      );
    }
    return content;
  }
}

class _PopoverCard extends StatelessWidget {
  final int currentLives;
  final double arrowCenterX;
  final double arrowSize;
  final VoidCallback onClose;
  final VoidCallback onNavigateToInfo;
  final void Function(int newLives)? onLivesChanged;
  final bool deferContent; // si true: contenu ultra léger pendant l'animation
  final int? shadowAlphaOverride;   // NEW
  final double? shadowBlurOverride; // NEW
  final double? fillOpacityOverride; // NEW
  final double? strokeOpacityOverride; // NEW
  final double? arrowHeightOverride; // NEW

  const _PopoverCard({
    required this.currentLives,
    required this.arrowCenterX,
    required this.arrowSize,
    required this.onClose,
    required this.onNavigateToInfo,
    this.onLivesChanged,
    this.deferContent = false,
    this.shadowAlphaOverride,
    this.shadowBlurOverride,
    this.fillOpacityOverride,
    this.strokeOpacityOverride,
    this.arrowHeightOverride,
  });

  Future<void> _handleRewardedFlow(BuildContext context) async {
    final uid = LifeService.getCurrentUserId();
    if (uid == null) {
      onNavigateToInfo();
      return;
    }
    try {
      final rewarded = await AdService.instance.showRewardedIfAvailable();
      if (rewarded) {
        final tx = await LifeService.addLivesTransactional(uid, 1);
        final before = tx['before'] ?? 0;
        final after = tx['after'] ?? before;
        try { onLivesChanged?.call(after); } catch (_) {}
      }
    } catch (_) {
      // Fallback: ouvrir la page info si pas de pub
      onNavigateToInfo();
    }
  }

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
        arrowHeight: arrowHeightOverride ?? (arrowSize * 1.6),
        topInset: contentPadding.top,
        shadowAlpha: shadowAlphaOverride ?? 30,   // NEW
        shadowBlur: shadowBlurOverride ?? 14.0,   // NEW
        fillOpacity: (fillOpacityOverride ?? 1.0).clamp(0.0, 1.0),
        strokeOpacity: (strokeOpacityOverride ?? 1.0).clamp(0.0, 1.0),
      ),
      child: StreamBuilder<bool>(
        stream: UserOrchestra.isPremiumStream,
        initialData: UserOrchestra.isPremium,
        builder: (context, snap) {
          final bool isPremium = (snap.data == true);
          return Padding(
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
                if (isPremium)
                  Center(
                    child: SvgPicture.asset(
                      'assets/Images/Bouton/infinie.svg',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Color(0xFF473C33), BlendMode.srcIn),
                    ),
                  )
                else
                  _AdaptiveStaticLivesRow(currentLives: currentLives),
                const SizedBox(height: 12),
                if (!isPremium)
                  SizedBox(
                    width: double.infinity,
                    child: BoutonUniversel(
                      onPressed: () => _handleRewardedFlow(context),
                      size: BoutonUniverselTaille.small,
                      decorClipToOuter: true,
                      decorPadding: EdgeInsets.zero,
                      decorElements: const [
                        DecorElement(
                          assetPath: 'assets/PAGE/Homescreen/sablier.svg',
                          position: Offset(0.01, 0.35),
                          scale: 1.05,
                          zIndex: -6,
                          rotationDeg: 20,
                        ),
                        DecorElement(
                          assetPath: 'assets/PAGE/Homescreen/coeur.svg',
                          position: Offset(-0.05, 0.47),
                          scale: 0.75,
                          rotationDeg: -16,
                        ),
                      ],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: 10,
                      backgroundColor: const Color(0xFFABC270),
                      hoverBackgroundColor: const Color(0xFFABC270),
                      backgroundGradient: const LinearGradient(
                        begin: Alignment(0.04, 1.30),
                        end: Alignment(1.00, 0.50),
                        colors: [Color(0xFFABC270), Color(0xFFC2D397)],
                      ),
                      hoverBackgroundGradient: const LinearGradient(
                        begin: Alignment(0.04, 1.30),
                        end: Alignment(1.00, 0.50),
                        colors: [Color(0xFFABC270), Color(0xFFC2D397)],
                      ),
                      borderColor: const Color(0xFF6A994E),
                      hoverBorderColor: const Color(0xFF6A994E),
                      shadowColor: const Color(0xFF6A994E),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            'Regarder une pub\npour +1 vie',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              height: 0.95,
                              letterSpacing: 0.5,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 0.8
                                ..color = const Color(0x22000000),
                            ),
                          ),
                          const Text(
                            'Regarder une pub\npour +1 vie',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              height: 0.95,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 2)),
                                Shadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 4)),
                                Shadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 6)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isPremium) const SizedBox(height: 10),
                if (!isPremium)
                  SizedBox(
                    width: double.infinity,
                    child: BoutonUniversel(
                      onPressed: onNavigateToInfo,
                      size: BoutonUniverselTaille.small,
                      decorClipToOuter: true,
                      decorPadding: EdgeInsets.zero,
                      decorElements: const [
                        DecorElement(
                          assetPath: 'assets/PAGE/Homescreen/cadeau.svg',
                          position: Offset(0.76, -0.00),
                          scale: 1.60,
                          rotationDeg: -15,
                          zIndex: -1,
                        ),
                        DecorElement(
                          assetPath: 'assets/PAGE/Homescreen/Confetti.svg',
                          position: Offset(-0.08, -1.32),
                          scale: 5.20,
                          rotationDeg: 0,
                          zIndex: -2,
                        ),
                      ],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: 10,
                      backgroundColor: const Color(0xFFFEC868),
                      hoverBackgroundColor: const Color(0xFFFEC868),
                      backgroundGradient: const LinearGradient(
                        begin: Alignment(0.02, 2.39),
                        end: Alignment(0.86, -0.76),
                        colors: [Color(0xDBFEC868), Color(0xFFFFA327)],
                      ),
                      hoverBackgroundGradient: const LinearGradient(
                        begin: Alignment(0.02, 2.39),
                        end: Alignment(0.86, -0.76),
                        colors: [Color(0xDBFEC868), Color(0xFFFFA327)],
                      ),
                      borderColor: const Color(0xFFE89E1C),
                      hoverBorderColor: const Color(0xFFE89E1C),
                      shadowColor: const Color(0xFFE89E1C),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            'Avec Premium \nPasse en mode illimité',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              height: 0.95,
                              letterSpacing: 0.5,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 0.8
                                ..color = const Color(0x22000000),
                            ),
                          ),
                          const Text(
                            'Avec Premium \nPasse en mode illimité',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              height: 0.95,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 2)),
                                Shadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 4)),
                                Shadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 6)),
                              ],
                            ),
                          ),
                        ],
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
}

// Habillage dédié supprimé au profit des presets partagés (voir HabillageBouton)

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

    // Shadow (allégée)
    canvas.drawShadow(fillPath, Colors.black.withAlpha(28), 6, true);

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

  // NEW: contrôle d'ombre dynamique
  final int shadowAlpha;
  final double shadowBlur;
  final double fillOpacity;
  final double strokeOpacity;

  _IntegratedBubblePainter({
    required this.fillColor,
    required this.strokeColor,
    required this.borderWidth,
    required this.cornerRadius,
    required this.arrowCenterX,
    required this.arrowWidth,
    required this.arrowHeight,
    required this.topInset,
    required this.shadowAlpha,
    required this.shadowBlur,
    this.fillOpacity = 1.0,
    this.strokeOpacity = 1.0,
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

    // Ombre (paramétrable selon l'avancement de l'anim)
    canvas.drawShadow(path, Colors.black.withAlpha(shadowAlpha), shadowBlur, true);

    // Remplir
    final Paint fillPaint = Paint()
      ..color = fillColor.withOpacity(fillOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Contour
    final Paint stroke = Paint()
      ..color = strokeColor.withOpacity(strokeOpacity)
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
        old.topInset != topInset ||
        old.shadowAlpha != shadowAlpha ||
        old.shadowBlur != shadowBlur ||
        old.fillOpacity != fillOpacity ||
        old.strokeOpacity != strokeOpacity;
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

class _AdaptiveStaticLivesRow extends StatelessWidget {
  final int currentLives;
  const _AdaptiveStaticLivesRow({required this.currentLives});

  @override
  Widget build(BuildContext context) {
    const int displayCap = 10;
    final int rawCurrent = currentLives.clamp(0, 9999);
    final int maxLives = rawCurrent.clamp(1, 50);
    final int displayCount = maxLives >= displayCap ? displayCap : maxLives;
    final bool showAggregator = rawCurrent > displayCap && displayCount == displayCap;
    final int overflowCount = showAggregator ? (rawCurrent - displayCap) : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        const double baseSize = 56.0;
        const double minSize = 22.0;
        const double maxSize = 56.0;
        const double minGap = 3.0;

        int rows = 1;
        double iconSize = maxSize;
        double gap = minGap;

        double computeSizeFor(int columns) {
          final double totalGaps = (columns - 1) * minGap;
          return ((availableWidth - totalGaps) / columns).clamp(minSize, maxSize);
        }

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
            final bool filled = index < (rawCurrent.clamp(0, displayCount));
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

// --- Bouton "lite" utilisé uniquement pendant l'animation d'ouverture ---
class _LiteCTAButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _LiteCTAButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFFE7EDE0),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _LiteCTAButtonLabel(),
          ),
        ),
      ),
    );
  }
}

class _LiteCTAButtonLabel extends StatelessWidget {
  const _LiteCTAButtonLabel();

  @override
  Widget build(BuildContext context) {
    // Le texte est passé via DefaultTextStyle.of(context) par le parent
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: Color(0xFF344356),
        height: 1.0,
        letterSpacing: 0.3,
        decoration: TextDecoration.none,
      ),
      child: Builder(
        builder: (ctx) {
          // On récupère le texte via un ancestor; si absent, on affiche un placeholder
          // Pour simplifier le call-site, on encapsule plutôt le texte directement ici :
          // => on laisse le parent appeler _LiteCTAButton(text: "...", onTap: ...)
          return const SizedBox.shrink();
        },
      ),
    );
  }
}