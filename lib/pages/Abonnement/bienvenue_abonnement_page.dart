import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:appbirdify/pages/home_screen.dart';
import 'package:appbirdify/widgets/boutons/bouton_universel.dart';

class EnvolWelcomePage extends StatefulWidget {
  const EnvolWelcomePage({super.key});

  @override
  State<EnvolWelcomePage> createState() => _EnvolWelcomePageState();
}

class _EnvolWelcomePageState extends State<EnvolWelcomePage> with TickerProviderStateMixin {
  AnimationController? _traitsController;
  AnimationController? _necklaceController;
  AnimationController? _upperArcController;
  List<double>? _upperArcOpacities; // opacités fixes pour les perles du demi‑cercle

  List<double> _getUpperArcOpacities(int count) {
    if (_upperArcOpacities != null && _upperArcOpacities!.length == count) {
      return _upperArcOpacities!;
    }
    final math.Random seeded = math.Random(1337);
    // Variation douce entre 0.5 et 1.0
    final List<double> ops = List<double>.generate(
      count,
      (_) => (0.5 + seeded.nextDouble() * 0.5).clamp(0.5, 1.0),
    );
    _upperArcOpacities = ops;
    return ops;
  }

  @override
  void initState() {
    super.initState();
    _traitsController = AnimationController(vsync: this);
    _necklaceController = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _upperArcController = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
  }

  @override
  void dispose() {
    _traitsController?.dispose();
    _necklaceController?.dispose();
    _upperArcController?.dispose();
    super.dispose();
  }

  // Construit le collier (anneau + ronds) avec positions équidistantes
  Widget _buildNecklace(double currentAngle) {
    const double groupSize = 270;
    const double strokeW = 4;
    const double cx = groupSize / 2;
    const double cy = groupSize / 2;
    final double orbitR = (groupSize - strokeW) / 2; // centre du trait du grand anneau

    final List<Map<String, Object>> items = [
      {
        'asset': 'assets/Missionhome/Images/U02.png',
        'ring': 90.0,
        'icon': 72.0,
        'rot': 0.003,
      },
      {
        'asset': 'assets/Missionhome/Images/A01.png',
        'ring': 102.0,
        'icon': 83.0,
        'rot': -0.08,
      },
      {
        'asset': 'assets/Missionhome/Images/L01.png',
        'ring': 84.0,
        'icon': 78.0,
        'rot': 0.04,
      },
      {
        'asset': 'assets/Missionhome/Images/H01.png',
        'ring': 80.0,
        'icon': 70.0,
        'rot': 0.03,
      },
      {
        'asset': 'assets/Missionhome/Images/A03.png',
        'ring': 88.0,
        'icon': 64.0,
        'rot': -0.06,
      },
    ];
    final int n = items.length;
    const double start = -math.pi / 2; // démarrer en haut

    // 1) Calcul des angles occupés par chaque perle (arc tangent au fil)
    final List<double> ringR = items.map((e) => (e['ring'] as double) / 2.6).toList();
    final double margin = strokeW * 0.8; // légère marge pour tangence visuelle
    final List<double> widthAngles = ringR
        .map((rr) => 2 * math.asin(((rr + margin) / orbitR).clamp(0.0, 1.0)))
        .toList();

    // 2) Répartition du reste en gaps égaux
    final double remaining = (2 * math.pi) - widthAngles.fold(0.0, (a, b) => a + b);
    final double gapAngle = remaining / n;

    // 3) Cursor angulaire et centres
    double cursor = start;
    final List<_Hole> holes = <_Hole>[];
    final List<Offset> centers = <Offset>[];
    for (int i = 0; i < n; i++) {
      final double centerAngle = cursor + widthAngles[i] / 2;
      final double x = cx + orbitR * math.cos(centerAngle);
      final double y = cy + orbitR * math.sin(centerAngle);
      centers.add(Offset(x, y));
      final double r = ringR[i] - 1; // retrait très faible
      holes.add(_Hole(offset: Offset(x, y), radius: r, inflate: 3.5));
      cursor += widthAngles[i] + gapAngle;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: const Size(groupSize, groupSize),
          painter: _RingWithHolesPainter(
            strokeColor: const Color(0xFFFCFCFE),
            strokeWidth: strokeW,
            holes: holes,
          ),
        ),
        // Ronds équidistants avec contre-rotation pour rester droits
        ...List.generate(n, (i) {
          final double ring = items[i]['ring'] as double;
          final double icon = items[i]['icon'] as double;
          final double x = centers[i].dx - ring / 2;
          final double y = centers[i].dy - ring / 2;
          final String asset = items[i]['asset'] as String;
          final double localRot = (items[i]['rot'] as double);
          return Positioned(
            left: x,
            top: y,
            child: Transform.rotate(
              angle: -currentAngle + localRot,
              child: _DecorIconBare(
                ringSize: ring,
                iconSize: icon,
                assetPath: asset,
                rotationTurns: 0,
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            // aligné sur x1=350.5,y1=788 vers x2=32,y2=0 du SVG (diagonale BR -> TL)
            begin: Alignment(0.93, 0.94),
            end: Alignment(-0.85, -1.00),
            colors: [
              Colors.white,
              Color(0xEDFFB648), // 93% opacity
              Color(0xFFFEC868),
            ],
            stops: [0.0337, 0.8751, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
              spreadRadius: 0,
            )
          ],
        ),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double baseW = 375;
                final double baseH = 812;
                final double scale = (constraints.maxWidth / baseW).clamp(0.5, 1.2);
                // Décalage vertical pour le groupe demi-anneau externe (ajustable)
                final double outerArcYOffset = 76;
                final double continueBtnWidth = 180;
                final double continueBtnLeft = (baseW - continueBtnWidth) / 2;
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: baseW,
                    height: baseH,
                    child: Stack(
                      children: [
                        // fond gradient reproduisant le SVG - déjà appliqué via BoxDecoration
                        // Logo premium ENVOL (SVG) en haut à droite, derrière les bulles
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

                        // Groupe "collier" (anneau + ronds) avec rotation lente
                        Positioned(
                          left: 53,
                          top: 192,
                          child: SizedBox(
                            width: 270,
                            height: 270,
                            child: _necklaceController == null
                                ? _buildNecklace(0)
                                : AnimatedBuilder(
                                    animation: _necklaceController!,
                                    builder: (context, _) {
                                      final double a = _necklaceController!.value * 6.283185307179586;
                                      return Transform.rotate(
                                        angle: a,
                                        child: _buildNecklace(a),
                                      );
                                    },
                                  ),
                          ),
                        ),

                        // Anneau interne plus opaque autour de la clé
                        Positioned(
                          left: 125,
                          top: 261,
                          child: Container(
                            width: 126,
                            height: 126,
                            decoration: ShapeDecoration(
                              color: const Color(0x54C9C9C9),
                              shape: OvalBorder(
                                side: BorderSide(
                                  width: 4,
                                  color: const Color(0xFFFCFCFE),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Demi-anneau EXTERNE fixe + perles H03/M04 en rotation (effet d'optique)
                        Positioned(
                          left: -42,
                          top: 25 + outerArcYOffset,
                          child: SizedBox(
                            width: 466,
                            height: 431,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // perles tournantes (H03, M04) et perçage dynamique du trait sous les perles
                                _upperArcController == null
                                    ? _UpperArcStatic()
                                    : AnimatedBuilder(
                                        animation: _upperArcController!,
                                        builder: (context, _) {
                                          // Animation de défilement sur le demi‑cercle (haut)
                                          const double w = 466;
                                          const double h = 431;
                                          const double cx = w / 2;
                                          const double cy = h / 2;
                                          const double r = (466 - 4) / 2;
                                          const double start = -math.pi; // à gauche
                                          const double end = 0.0; // à droite
                                          const double span = end - start; // = pi

                                          // Perles source (boucle)
                                          final upperItems = [
                                            {'asset': 'assets/Missionhome/Images/U04.png', 'ring': 95.0, 'icon': 77.0},
                                            {'asset': 'assets/Missionhome/Images/H04.png', 'ring': 77.0, 'icon': 64.0},
                                            {'asset': 'assets/Missionhome/Images/H03.png', 'ring': 95.0, 'icon': 77.0},
                                            {'asset': 'assets/Missionhome/Images/M04.png', 'ring': 77.0, 'icon': 64.0},
                                          ];
                                          final int n = upperItems.length;
                                          final double t = _upperArcController!.value; // 0..1
                                          // Décalage angulaire animé (boucle infinie)
                                          // Inverser le sens: phase décroissante
                                          final double phase = (span - (t * span)) % span;
                                          // Pas angulaire égal pour un intervalle constant
                                          final double delta = span / n;

                                          final List<Offset> centers = [];
                                          final List<_Hole> movingHoles = [];
                                          // Toujours exactement n perles réparties sans coupure
                                          for (int i = 0; i < n; i++) {
                                            final double wrapped = (i * delta + phase) % span; // 0..span
                                            final double theta = start + wrapped; // dans [start, end)
                                            final double x = cx + r * math.cos(theta);
                                            final double y = cy + r * math.sin(theta);
                                            centers.add(Offset(x, y));
                                            final double ringSize = (upperItems[i]['ring'] as double);
                                            // Trous exactement tangents aux perles (pas de marge visuelle)
                                            movingHoles.add(_Hole(offset: Offset(x, y), radius: ringSize / 2, inflate: 0.0));
                                          }

                                          final ops = _getUpperArcOpacities(n);
                                          return Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              // arc fixe + perçage dynamique sous les perles visibles
                                              CustomPaint(
                                                size: const Size(466, 431),
                                                painter: _HalfRingPainter(
                                                  strokeColor: const Color(0xFFFCFCFE),
                                                  strokeWidth: 4,
                                                  holes: movingHoles,
                                                ),
                                              ),
                                              // perles au-dessus dans le même ordre (n éléments)
                                              ...List.generate(n, (i) {
                                                final ring = (upperItems[i]['ring'] as double);
                                                final icon = (upperItems[i]['icon'] as double);
                                                final asset = (upperItems[i]['asset'] as String);
                                                return Positioned(
                                                  left: centers[i].dx - ring / 2,
                                                  top: centers[i].dy - ring / 2,
                                                  child: _DecorIconBare(
                                                    ringSize: ring,
                                                    iconSize: icon,
                                                    assetPath: asset,
                                                    contentOpacity: ops[i],
                                                  ),
                                                );
                                              }),
                                            ],
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ),

                        // Lottie clé au centre
                        // Lottie base (clé et éléments statiques), traits masqués
                        Positioned(
                          left: 129,
                          top: 268,
                          child: SizedBox(
                            width: 118,
                            height: 112,
                            child: Lottie.asset(
                              'assets/PAGE/Paywall/clé.json',
                              fit: BoxFit.contain,
                              repeat: true,
                              delegates: LottieDelegates(values: [
                                ValueDelegate.opacity(['Shape Layer 7', '**'], value: 0),
                                ValueDelegate.opacity(['Shape Layer 8', '**'], value: 0),
                              ]),
                            ),
                          ),
                        ),
                        // Lottie traits uniquement, animés plus lentement
                        Positioned(
                          left: 129,
                          top: 268,
                          child: SizedBox(
                            width: 118,
                            height: 112,
                            child: Lottie.asset(
                              'assets/PAGE/Paywall/clé.json',
                              fit: BoxFit.contain,
                              controller: _traitsController,
                              delegates: LottieDelegates(values: [
                                // Masquer toutes les autres couches connues
                                ValueDelegate.opacity(['Path 8', '**'], value: 0),
                                ValueDelegate.opacity(['Path 7', '**'], value: 0),
                                ValueDelegate.opacity(['Path 6', '**'], value: 0),
                                ValueDelegate.opacity(['Path 5', '**'], value: 0),
                                ValueDelegate.opacity(['Group 2', '**'], value: 0),
                                ValueDelegate.opacity(['Boolean 3', '**'], value: 0),
                                ValueDelegate.opacity(['Boolean 2', '**'], value: 0),
                                ValueDelegate.opacity(['Boolean 1', '**'], value: 0),
                                ValueDelegate.opacity(['Boolean', '**'], value: 0),
                                ValueDelegate.opacity(['Path 2', '**'], value: 0),
                                ValueDelegate.opacity(['Path 1', '**'], value: 0),
                                ValueDelegate.opacity(['Path', '**'], value: 0),
                                // Conserver uniquement ces deux calques (traits)
                                ValueDelegate.opacity(['Shape Layer 7', '**'], value: 100),
                                ValueDelegate.opacity(['Shape Layer 8', '**'], value: 100),
                              ]),
                              onLoaded: (composition) {
                                // Ralentir nettement les traits (~2x)
                                final slowedUs = (composition.duration.inMicroseconds * 2.0).round();
                                final slowed = Duration(microseconds: slowedUs);
                                _traitsController ??= AnimationController(vsync: this);
                                _traitsController!
                                  ..reset()
                                  ..repeat(period: slowed);
                              },
                            ),
                          ),
                        ),

                        // Icônes décoratives autour: gérées dans le groupe tournant ci-dessus

                        // Titre
                        const Positioned(
                          left: 23,
                          top: 513,
                          child: SizedBox(
                            width: 338,
                            child: Text(
                              ' Bienvenue dans Envol\nLe mode premium de MindBird',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF334355),
                                fontSize: 24,
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w600,
                                height: 1.29,
                              ),
                            ),
                          ),
                        ),

                        // Sous-titre
                        const Positioned(
                          left: 22,
                          top: 588,
                          child: SizedBox(
                            width: 338,
                            child: Text(
                              'Passe en mode illimité: vies infinies, quiz sans limite, tous les habitats.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF334355),
                                fontSize: 20,
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w400,
                                height: 1.30,
                              ),
                            ),
                          ),
                        ),

                        // Bouton Continuer (centré) avec BoutonUniversel
                        Positioned(
                          left: continueBtnLeft,
                          top: 685,
                          child: SizedBox(
                            width: continueBtnWidth,
                            height: 48,
                            child: BoutonUniversel(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                                );
                              },
                              size: BoutonUniverselTaille.small,
                              borderRadius: 10,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              backgroundColor: const Color(0xFFFCFCFE),
                              hoverBackgroundColor: const Color(0xFFF1F3F6),
                              borderColor: const Color(0xB3858585),
                              hoverBorderColor: const Color(0xFF9AA0A6),
                              shadowColor: const Color(0xB3858585),
                              child: const Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Continuer',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF334355),
                                      fontSize: 20,
                                      fontFamily: 'Fredoka',
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      height: 1.1,
                                    ),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorIcon extends StatelessWidget {
  final double left;
  final double top;
  final double ringSize;
  final double iconSize;
  final String assetPath;
  final double rotationTurns;

  const _DecorIcon({
    required this.left,
    required this.top,
    required this.ringSize,
    required this.iconSize,
    required this.assetPath,
    this.rotationTurns = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Stack(
        children: [
          Container(
            width: ringSize,
            height: ringSize,
            decoration: ShapeDecoration(
              color: const Color(0x33FCFCFE),
              shape: OvalBorder(
                side: BorderSide(
                  width: 4,
                  color: const Color(0xFFFCFCFE),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: rotationTurns,
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: ClipOval(
                  child: _buildAsset(assetPath, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          // Voile radial pour opacifier le centre et masquer toute ligne traversante
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.65,
                    colors: [
                      const Color(0xFFFCFCFE).withOpacity(0.40),
                      const Color(0xFFFCFCFE).withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsset(String path, {BoxFit fit = BoxFit.contain}) {
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(path, fit: fit);
    }
    return Image.asset(path, fit: fit);
  }
}

// Variante sans Positioned interne pour pouvoir l'imbriquer dans un autre Positioned
class _DecorIconBare extends StatelessWidget {
  final double ringSize;
  final double iconSize;
  final String assetPath;
  final double rotationTurns;
  final double contentOpacity;

  const _DecorIconBare({
    required this.ringSize,
    required this.iconSize,
    required this.assetPath,
    this.rotationTurns = 0,
    this.contentOpacity = 1.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Contenu + contenant (fond et image) avec opacité variable
        Opacity(
          opacity: contentOpacity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fond circulaire (sans contour)
              Container(
                width: ringSize,
                height: ringSize,
                decoration: const ShapeDecoration(
                  color: Color(0x33FCFCFE),
                  shape: OvalBorder(
                    side: BorderSide(width: 0, color: Colors.transparent),
                  ),
                ),
              ),
              // Image intérieure
              Positioned(
                left: (ringSize - iconSize) / 2,
                top: (ringSize - iconSize) / 2,
                child: Transform.rotate(
                  angle: rotationTurns,
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(0),
                        child: _buildAsset(assetPath, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              // Voile radial (fait partie du contenant)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.65,
                        colors: [
                          const Color(0xFFFCFCFE).withOpacity(0.40),
                          const Color(0xFFFCFCFE).withOpacity(0.0),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Contour (anneau) par-dessus à 100% d'opacité
        IgnorePointer(
          child: Container(
            width: ringSize,
            height: ringSize,
            decoration: const ShapeDecoration(
              color: Colors.transparent,
              shape: OvalBorder(
                side: BorderSide(
                  width: 4,
                  color: Color(0xFFFCFCFE),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAsset(String path, {BoxFit fit = BoxFit.contain}) {
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(path, fit: fit);
    }
    return Image.asset(path, fit: fit);
  }
}

// Fallback statique si le controller est nul
class _UpperArcStatic extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const double w = 466;
    const double h = 431;
    const double cx = w / 2;
    const double cy = h / 2;
    const double r = (466 - 4) / 2;
    const double base = -math.pi / 2;
    final Offset c1 = Offset(cx + r * math.cos(base - 0.28), cy + r * math.sin(base - 0.28));
    final Offset c2 = Offset(cx + r * math.cos(base + 0.28), cy + r * math.sin(base + 0.28));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: c1.dx - 95 / 2,
          top: c1.dy - 95 / 2,
          child: _DecorIconBare(
            ringSize: 95,
            iconSize: 77,
            assetPath: 'assets/Missionhome/Images/H03.png',
          ),
        ),
        Positioned(
          left: c2.dx - 77 / 2,
          top: c2.dy - 77 / 2,
          child: _DecorIconBare(
            ringSize: 77,
            iconSize: 64,
            assetPath: 'assets/Missionhome/Images/M04.png',
          ),
        ),
      ],
    );
  }
}

class _Hole {
  final Offset offset; // centre relatif dans le canvas du painter
  final double radius;
  final double inflate; // marge supplémentaire pour percer plus large
  const _Hole({required this.offset, required this.radius, this.inflate = 0});
}

class _HalfRingPainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final List<_Hole>? holes;

  _HalfRingPainter({required this.strokeColor, required this.strokeWidth, this.holes});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    // Demi-cercle supérieur: angle de 180° à 360° (pi à 2*pi)
    const double startAngle = 3.141592653589793;
    const double sweepAngle = 3.141592653589793;
    // Léger débord pour que les traits se rejoignent parfaitement aux extrémités
    const double epsilon = 0.03; // ~1.15°
    final double radiusAdjust = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      rect.left + radiusAdjust,
      rect.top + radiusAdjust,
      rect.width - strokeWidth,
      rect.height - strokeWidth,
    );
    if (holes == null || holes!.isEmpty) {
      canvas.drawArc(arcRect, startAngle - epsilon, sweepAngle + 2 * epsilon, false, paint);
    } else {
      // Dessiner l'arc puis soustraire les zones des ronds (destination-out) pour percer le trait
      final Rect layerBounds = arcRect.inflate(strokeWidth + 2);
      canvas.saveLayer(layerBounds, Paint());
      canvas.drawArc(arcRect, startAngle - epsilon, sweepAngle + 2 * epsilon, false, paint);
      final Paint punch = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black
        ..isAntiAlias = true
        ..blendMode = BlendMode.dstOut;
      // Suppression du recouvrement pour une tangence exacte avec les perles
      final double overlap = 0.0;
      for (final h in holes!) {
        canvas.drawCircle(h.offset, h.radius + overlap + h.inflate, punch);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HalfRingPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.holes != holes;
  }
}

class _RingWithHolesPainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final List<_Hole> holes;

  _RingWithHolesPainter({required this.strokeColor, required this.strokeWidth, required this.holes});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    final double radiusAdjust = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      rect.left + radiusAdjust,
      rect.top + radiusAdjust,
      rect.width - strokeWidth,
      rect.height - strokeWidth,
    );
    // Cercle complet, puis soustraction des ronds (destination-out)
    final Rect layerBounds = arcRect.inflate(strokeWidth + 2);
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawArc(arcRect, 0, 6.283185307179586, false, ringPaint);
    final Paint punch = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black
      ..isAntiAlias = true
      ..blendMode = BlendMode.dstOut;
    final double overlap = strokeWidth * 1.1 + 2.0; // recouvrement renforcé
    for (final h in holes) {
      canvas.drawCircle(h.offset, h.radius + overlap + h.inflate, punch);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingWithHolesPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.holes != holes;
  }
}

class _CircleWithImage extends StatelessWidget {
  final double size;
  final String imageAsset;
  final double rotation; // en radians (~Z rotation)
  final Color ringColor;
  final Color fillColor;
  final double ringWidth;
  final double? innerPadding;

  const _CircleWithImage({
    required this.size,
    required this.imageAsset,
    required this.rotation,
    required this.ringColor,
    required this.fillColor,
    required this.ringWidth,
    this.innerPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: fillColor,
            shape: OvalBorder(
              side: BorderSide(width: ringWidth, color: ringColor),
            ),
          ),
        ),
        Positioned.fill(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(0.0, 0.0)
              ..rotateZ(rotation),
            child: Padding(
              padding: EdgeInsets.all((innerPadding ?? (ringWidth + 4))),
              child: ClipOval(
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        // Rehausse d'opacité au centre pour masquer tout trait et renforcer le focus
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.65,
                  colors: [
                    fillColor.withOpacity(0.45),
                    fillColor.withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


