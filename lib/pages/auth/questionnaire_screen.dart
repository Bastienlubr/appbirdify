import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;
// import '../../ui/responsive/responsive.dart'; // Unused
import '../../services/Users/onboarding_service.dart';
import '../home_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  String? _heardFrom; // Où as-tu découvert Birdify ?
  String? _level; // Ton niveau d'ornithologie
  String? _commitment; // Temps/semaine

  bool _showIntro = true;
  // Barre de progression: 4 segments au total, cette page est 1/4
  final int _totalSteps = 4;
  int _currentStep = 1;
  double _progressFrom = 0.0;
  double _progressTo = 0.25;

  void _goNextSegment() {
    if (_showIntro) {
      setState(() {
        _showIntro = false;
        _progressFrom = _progressTo;
        _currentStep = 2; // Étape 2: heardFrom
        _progressTo = _currentStep / _totalSteps;
      });
    }
  }

  void _goToLevelStep() {
    setState(() {
      _progressFrom = _progressTo;
      _currentStep = 3; // Étape 3: level
      _progressTo = _currentStep / _totalSteps;
    });
  }

  void _goToCommitmentStep() {
    setState(() {
      _progressFrom = _progressTo;
      _currentStep = 4; // Étape 4: engagement
      _progressTo = _currentStep / _totalSteps;
    });
  }

  Future<void> _submit() async {
    if (_heardFrom == null || _level == null || _commitment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci de répondre à toutes les questions.')));
      return;
    }
    try {
      await QuestionnaireService.saveOnboarding(
        heardFrom: _heardFrom!,
        level: _level!,
        weeklyCommitment: _commitment!,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } finally {
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final size = MediaQuery.of(context).size;
                      final shortest = size.shortestSide;
                      final bool isTablet = shortest >= 600;
                      final double ui = isTablet ? 1.2 : 1.0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_showIntro) {
                                Navigator.of(context).maybePop();
                                return;
                              }
                              if (_currentStep > 2) {
                                setState(() {
                                  _progressFrom = _progressTo;
                                  _currentStep = _currentStep - 1;
                                  _progressTo = _currentStep / _totalSteps;
                                });
                              } else {
                                setState(() {
                                  _showIntro = true;
                                  _progressFrom = _progressTo;
                                  _currentStep = 1;
                                  _progressTo = _currentStep / _totalSteps;
                                });
                              }
                            },
                            child: _SafeSvgAsset(
                              assetPath: 'assets/Images/Bouton/flechegauchecercle.svg',
                              width: 32 * ui,
                              height: 32 * ui,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuizStyleProgressBar(
                              from: _progressFrom,
                              to: _progressTo,
                              height: 14 * ui,
                              ui: ui,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  if (_showIntro)
                    Expanded(
                      child: _IntroBlock(
                        onContinue: _goNextSegment,
                        viewportHeight: null,
                      ),
                    )
                  else
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (_currentStep == 2) {
                            return _QuestionStepHeardFrom(
                              value: _heardFrom,
                              onChanged: (v) => setState(() => _heardFrom = v),
                              onContinue: (_heardFrom != null) ? _goToLevelStep : null,
                            );
                          } else {
                            if (_currentStep == 3) {
                              return _QuestionStepLevel(
                                value: _level,
                                onChanged: (v) => setState(() => _level = v),
                                onContinue: (_level != null) ? _goToCommitmentStep : null,
                              );
                            } else {
                              return _QuestionStepCommitment(
                                value: _commitment,
                                onChanged: (v) => setState(() => _commitment = v),
                                onContinue: (_commitment != null) ? _submit : null,
                              );
                            }
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Ancien conteneur supprimé car l’onboarding est en une seule page

// (supprimé) _Choices non utilisé

class _IntroBlock extends StatelessWidget {
  final VoidCallback onContinue;
  final double? viewportHeight;
  const _IntroBlock({required this.onContinue, this.viewportHeight});

  @override
  Widget build(BuildContext context) {
    final double vh = viewportHeight ?? MediaQuery.of(context).size.height;
    // Décalage vers le bas (légèrement réduit pour remonter le bloc)
    final double topGap = (vh * 0.24).clamp(80.0, 300.0);

    return Column(
      children: [
        SizedBox(height: topGap),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(60, 128, 209, 0.085),
                    blurRadius: 19,
                    offset: Offset(0, 12),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: const [
                  SizedBox(height: 8),
                  Text(
                    'Prêt·e à partir à l’aventure ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF344356),
                      fontSize: 23,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'D’abord, dis-nous un peu qui tu es pour qu’on adapte ton parcours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xCC344356),
                      fontSize: 20,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Avant de débloquer ta première mission, réponds à 3 questions rapides',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF344356),
                      fontSize: 16,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: -70,
              child: Image.asset(
                'assets/Images/Bouton/mascotte livre.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 315,
          height: 58,
          child: Stack(
            children: [
              Positioned.fill(
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A994E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'CONTINUER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Center(
                    child: _SafeSvgAsset(
                      assetPath: 'assets/Images/Bouton/bouton droite.svg',
                      width: 16,
                      height: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _QuizStyleProgressBar extends StatefulWidget {
  final double from;
  final double to;
  final double height;
  final double ui;
  const _QuizStyleProgressBar({required this.from, required this.to, this.height = 14, this.ui = 1.0});

  @override
  State<_QuizStyleProgressBar> createState() => _QuizStyleProgressBarState();
}

class _QuizStyleProgressBarState extends State<_QuizStyleProgressBar> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  AnimationController? _burstController;
  final List<_QSDroplet> _droplets = [];

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _anim = Tween<double>(begin: widget.from, end: widget.to).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _prepareDroplets();
        if (mounted) {
          _burstController?.forward(from: 0.0);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _QuizStyleProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.to != widget.to || oldWidget.from != widget.from) {
      _controller.reset();
      _anim = Tween<double>(begin: widget.from, end: widget.to).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _burstController?.dispose();
    super.dispose();
  }

  void _prepareDroplets() {
    _droplets.clear();
    final int count = 2 + (DateTime.now().microsecondsSinceEpoch % 2); // 2..3
    final randomSeed = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < count; i++) {
      final List<double> baseAnglesDeg = [-8, 8, 22];
      final baseDeg = baseAnglesDeg[i % baseAnglesDeg.length];
      final jitter = ((randomSeed >> (i % 8)) & 3) - 1.5; // -1.5..+1.5
      final angle = ((baseDeg + jitter) / 180.0) * math.pi;
      final speed = 32.0 + ((randomSeed >> (i % 6)) & 5) * 2.0; // ~32..42
      final yOffsets = [-6.0, 0.0, 6.0];
      final originOffsetY = yOffsets[(i + (randomSeed % 3)) % yOffsets.length];
      final baseRadius = 1.6 + ((randomSeed >> (i % 5)) & 2) * 0.4; // ~1.6..2.4
      _droplets.add(_QSDroplet(
        angle: angle,
        speed: speed,
        color: const Color(0xFFABC270),
        originOffsetY: originOffsetY,
        baseRadius: baseRadius,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final fill = width * _anim.value;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    width: width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: const Color(0xFF473C33),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(
                    width: fill,
                    height: widget.height,
                    child: Stack(
                      children: [
                        Container(color: const Color(0xFFABC270)),
                        Positioned(
                          left: 4,
                          right: 4,
                          top: 3.5 * widget.ui,
                          child: Container(
                            height: 3.5 * widget.ui,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC2D78D),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Gouttelettes en overlay (hors clip du remplissage)
                  Positioned(
                    left: 0,
                    top: -18 * widget.ui,
                    width: width,
                    height: 50 * widget.ui,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _QDropletPainter(
                          droplets: _droplets,
                          t: _burstController?.value ?? 0.0,
                          originX: fill,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QSDroplet {
  final double angle;
  final double speed;
  final Color color;
  final double originOffsetY;
  final double baseRadius;
  _QSDroplet({
    required this.angle,
    required this.speed,
    required this.color,
    required this.originOffsetY,
    required this.baseRadius,
  });
}

class _QDropletPainter extends CustomPainter {
  final List<_QSDroplet> droplets;
  final double t; // 0..1 animation progress
  final double originX; // pixel position of bar end
  _QDropletPainter({required this.droplets, required this.t, required this.originX});

  @override
  void paint(Canvas canvas, Size size) {
    if (droplets.isEmpty || t <= 0) return;
    final origin = Offset(originX, size.height / 2);
    for (final d in droplets) {
      final double life = t.clamp(0.0, 1.0);
      final double dist = d.speed * life * 0.22;
      final dx = math.cos(d.angle) * dist;
      final dy = math.sin(d.angle) * dist * 0.7;
      final pos = origin + Offset(dx, dy + d.originOffsetY);
      final double baseAlpha = (1.0 - life).clamp(0.0, 1.0);
      final double sideFactor = dx < 0 ? 0.7 : 1.0;
      final paint = Paint()
        ..color = d.color.withValues(alpha: (baseAlpha * sideFactor).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      final double r = d.baseRadius + (d.baseRadius * 0.7) * (1.0 - life);
      final double ovalFactor = 1.0 + 0.18 * life;
      final double rx = r * ovalFactor;
      final double ry = r * (2.0 - ovalFactor);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(d.angle);
      final Rect ovalRect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
      canvas.drawOval(ovalRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _QDropletPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.droplets != droplets || oldDelegate.originX != originX;
  }
}


class _SafeSvgAsset extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  const _SafeSvgAsset({required this.assetPath, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError || snapshot.data == null) {
          return SizedBox(width: width, height: height);
        }
        return SvgPicture.string(snapshot.data!, width: width, height: height);
      },
    );
  }
}

class _QuestionStepHeardFrom extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onContinue;
  const _QuestionStepHeardFrom({required this.value, required this.onChanged, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double base = 375.0; // maquette Figma
        final double scale = (width / base).clamp(0.85, 1.25);

        final options = const [
          'RÉSEAUX SOCIAUX',
          'AMIS OU BOUCHE-À-OREILLE',
          'RECHERCHE GOOGLE OU APP STORE',
          'ARTICLE, VIDÉO OU PODCAST',
          'EN SORTIE NATURE / ASSOCIATION',
          'AUTRE (PRÉCISE)',
        ];

        String baseNameFor(String label) {
          switch (label) {
            case 'RÉSEAUX SOCIAUX':
              return 'Réseaux sociaux';
            case 'AMIS OU BOUCHE-À-OREILLE':
              return 'bouche à bouche';
            case 'RECHERCHE GOOGLE OU APP STORE':
              return 'recherche google';
            case 'ARTICLE, VIDÉO OU PODCAST':
              return 'article,podcast';
            case 'EN SORTIE NATURE / ASSOCIATION':
              return 'association';
            case 'AUTRE (PRÉCISE)':
              return 'autre';
            default:
              return 'autre';
          }
        }

        final double cardWidth = (width * 0.94).clamp(300.0, width);
        final double iconSize = (68 * scale).clamp(56.0, 92.0);
        final double rowVPad = (14 * scale).clamp(10.0, 22.0);
        final double labelFont = (18 * scale).clamp(15.0, 22.0);
        final double titleFont = (30 * scale).clamp(24.0, 36.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 6 * scale),
            Center(
              child: SizedBox(
                width: (width * 0.96).clamp(300.0, width),
                child: Text(
                  "Où as-tu entendu parler de l’application ?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF344356),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: titleFont,
                    height: 1.08,
                  ),
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
            ),
            SizedBox(height: 8 * scale),
            Center(
              child: Container(
                width: cardWidth,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17 * scale),
                ),
                child: Column(
                  children: [
                    ...List.generate(options.length, (i) {
                      final label = options[i];
                      final selected = value == label;
                      final baseName = baseNameFor(label);
                      return InkWell(
                        onTap: () => onChanged(label),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: rowVPad, horizontal: 16 * scale),
                          decoration: i == 0
                              ? null
                              : BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.black.withValues(alpha: 0.20),
                                      width: (2 * scale).clamp(1.5, 3.0),
                                    ),
                                  ),
                                ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: iconSize,
                                height: iconSize,
                                child: _AuthIcon(baseName: baseName, size: iconSize, highlight: selected),
                              ),
                              SizedBox(width: 14 * scale),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: selected ? const Color(0xFFABC270) : const Color(0xFF344356),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    height: 1.1,
                                    fontSize: labelFont,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
            Center(
              child: SizedBox(
                width: cardWidth,
                height: (58 * scale).clamp(52.0, 72.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A994E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)),
                        ),
                        child: Text(
                          'CONTINUER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (18 * scale).clamp(16.0, 22.0),
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14 * scale,
                      top: 14 * scale,
                      child: Container(
                        width: (30 * scale).clamp(26.0, 38.0),
                        height: (30 * scale).clamp(26.0, 38.0),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Center(
                          child: _SafeSvgAsset(
                            assetPath: 'assets/Images/Bouton/bouton droite.svg',
                            width: (16 * scale).clamp(14.0, 22.0),
                            height: (16 * scale).clamp(14.0, 22.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10 * scale),
          ],
        );
      },
    );
  }
}

class _QuestionStepLevel extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onContinue;
  const _QuestionStepLevel({required this.value, required this.onChanged, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double base = 375.0;
        final double scale = (width / base).clamp(0.85, 1.25);

        final entries = const [
          ['DÉBUTANT CURIEUX', 'je reconnais à peine le chant du coq'],
          ['INTERMÉDIAIRE', 'je capte quelques espèces mais pas toujours sûr'],
          ['AVANCÉ', 'je distingue déjà pas mal de chants'],
          ['PASSIONNÉ CONFIRMÉ', 'je reconnais un oiseau avant même de le voir'],
        ];

        // Agrandir la carte et la typo
        final double cardWidth = (width * 0.98).clamp(300.0, width);
        final double rowVPad = (12 * scale).clamp(10.0, 20.0);
        final double titleFont = (30 * scale).clamp(24.0, 34.0);
        final double labelFont = (20 * scale).clamp(17.0, 24.0);
        final double subFont = (18 * scale).clamp(13.0, 20.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 6 * scale),
            Center(
              child: SizedBox(
                width: (width * 0.96).clamp(300.0, width),
                child: Text(
                  'Ton oreille est déjà bien entraînée, ou tu débutes ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF344356),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: titleFont,
                    height: 1.08,
                  ),
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
            ),
            SizedBox(height: 8 * scale),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: cardWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17 * scale),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...(){
                            final List<Widget> rows = [];
                            final int selectedIndex = entries.indexWhere((e) => e[0] == value);
                            final double sepThickness = (2 * scale).clamp(1.2, 2.5);
                            for (int i = 0; i < entries.length; i++) {
                              final label = entries[i][0];
                              final sub = entries[i][1];
                              final selected = i == selectedIndex;
                              // Séparateur avant la ligne (si ni la courante ni la précédente ne sont sélectionnées)
                              if (i > 0) {
                                final prevSelected = (i - 1) == selectedIndex;
                                rows.add(
                                  Container(
                                    height: (!prevSelected && !selected) ? sepThickness : 0,
                                    color: (!prevSelected && !selected)
                                        ? Colors.black.withValues(alpha: 0.20)
                                        : Colors.transparent,
                                    width: double.infinity,
                                  ),
                                );
                              }
                              // Border radius aligné aux bords de la carte si sélectionné et en extrémité
                              BorderRadius? br;
                              if (selected) {
                                if (i == 0) {
                                  br = BorderRadius.only(
                                    topLeft: Radius.circular(17 * scale),
                                    topRight: Radius.circular(17 * scale),
                                  );
                                } else if (i == entries.length - 1) {
                                  br = BorderRadius.only(
                                    bottomLeft: Radius.circular(17 * scale),
                                    bottomRight: Radius.circular(17 * scale),
                                  );
                                } else {
                                  br = BorderRadius.zero;
                                }
                              }
                              rows.add(
                                InkWell(
                                  onTap: () => onChanged(label),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: rowVPad),
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFF6A994E).withValues(alpha: 0.10) : Colors.transparent,
                                      border: selected
                                          ? Border.all(
                                              color: const Color(0xFFABC270),
                                              width: (2 * scale).clamp(1.2, 2.4),
                                            )
                                          : null,
                                      borderRadius: br,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              color: selected ? const Color(0xFFABC270) : const Color(0xFF344356),
                                              fontFamily: 'Fredoka',
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.7,
                                              fontSize: labelFont,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: 1 * scale),
                                          Text(
                                            sub,
                                            style: TextStyle(
                                              color: const Color(0x99344356),
                                              fontFamily: 'Fredoka',
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: 0.5,
                                              fontSize: subFont,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return rows;
                          }(),
                        ],
                      ),
                    ),
                    SizedBox(height: 24 * scale),
                    SizedBox(
                      width: cardWidth,
                      height: (58 * scale).clamp(52.0, 72.0),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ElevatedButton(
                              onPressed: onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A994E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)),
                              ),
                              child: Text(
                                'CONTINUER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (18 * scale).clamp(16.0, 22.0),
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14 * scale,
                            top: 14 * scale,
                            child: Container(
                              width: (30 * scale).clamp(26.0, 38.0),
                              height: (30 * scale).clamp(26.0, 38.0),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Center(
                                child: _SafeSvgAsset(
                                  assetPath: 'assets/Images/Bouton/bouton droite.svg',
                                  width: (16 * scale).clamp(14.0, 22.0),
                                  height: (16 * scale).clamp(14.0, 22.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10 * scale),
          ],
        );
      },
    );
  }
}

class _QuestionStepCommitment extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onContinue;
  const _QuestionStepCommitment({required this.value, required this.onChanged, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double base = 375.0;
        final double scale = (width / base).clamp(0.85, 1.25);

        final entries = const [
          ['QUELQUES MINUTES PAR JOUR', 'un petit rituel quotidien'],
          ['2-3 FOIS PAR SEMAINE', 'quand j’ai un moment'],
          ['DE TEMPS EN TEMPS', 'À la cool, sans pression'],
          ['INTENSIF', 'j’y vais à fond, je veux progresser vite'],
        ];

        final double cardWidth = (width * 0.98).clamp(300.0, width);
        final double rowVPad = (12 * scale).clamp(10.0, 20.0);
        final double titleFont = (30 * scale).clamp(24.0, 34.0);
        final double labelFont = (20 * scale).clamp(17.0, 24.0);
        final double subFont = (18 * scale).clamp(13.0, 20.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 6 * scale),
            Center(
              child: SizedBox(
                width: (width * 0.96).clamp(300.0, width),
                child: Text(
                  'Combien de temps tu es prêt à passer dessus ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF344356),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: titleFont,
                    height: 1.08,
                  ),
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
            ),
            SizedBox(height: 8 * scale),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: cardWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17 * scale),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...(){
                            final List<Widget> rows = [];
                            final int selectedIndex = entries.indexWhere((e) => e[0] == value);
                            final double sepThickness = (2 * scale).clamp(1.2, 2.5);
                            for (int i = 0; i < entries.length; i++) {
                              final label = entries[i][0];
                              final sub = entries[i][1];
                              final selected = i == selectedIndex;
                              if (i > 0) {
                                final prevSelected = (i - 1) == selectedIndex;
                                rows.add(
                                  Container(
                                    height: (!prevSelected && !selected) ? sepThickness : 0,
                                    color: (!prevSelected && !selected)
                                        ? Colors.black.withValues(alpha: 0.20)
                                        : Colors.transparent,
                                    width: double.infinity,
                                  ),
                                );
                              }
                              BorderRadius? br;
                              if (selected) {
                                if (i == 0) {
                                  br = BorderRadius.only(
                                    topLeft: Radius.circular(17 * scale),
                                    topRight: Radius.circular(17 * scale),
                                  );
                                } else if (i == entries.length - 1) {
                                  br = BorderRadius.only(
                                    bottomLeft: Radius.circular(17 * scale),
                                    bottomRight: Radius.circular(17 * scale),
                                  );
                                } else {
                                  br = BorderRadius.zero;
                                }
                              }
                              rows.add(
                                InkWell(
                                  onTap: () => onChanged(label),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: rowVPad),
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFFABC270).withValues(alpha: 0.10) : Colors.transparent,
                                      border: selected
                                          ? Border.all(
                                              color: const Color(0xFFABC270),
                                              width: (2 * scale).clamp(1.2, 2.4),
                                            )
                                          : null,
                                      borderRadius: br,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              color: selected ? const Color(0xFFABC270) : const Color(0xFF344356),
                                              fontFamily: 'Fredoka',
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.7,
                                              fontSize: labelFont,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: 1 * scale),
                                          Text(
                                            sub,
                                            style: TextStyle(
                                              color: const Color(0x99344356),
                                              fontFamily: 'Fredoka',
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: 0.5,
                                              fontSize: subFont,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return rows;
                          }(),
                        ],
                      ),
                    ),
                    SizedBox(height: 30 * scale),
                    SizedBox(
                      width: cardWidth,
                      height: (58 * scale).clamp(52.0, 72.0),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ElevatedButton(
                              onPressed: onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A994E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)),
                              ),
                              child: Text(
                                'CONTINUER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (18 * scale).clamp(16.0, 22.0),
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14 * scale,
                            top: 14 * scale,
                            child: Container(
                              width: (30 * scale).clamp(26.0, 38.0),
                              height: (30 * scale).clamp(26.0, 38.0),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Center(
                                child: _SafeSvgAsset(
                                  assetPath: 'assets/Images/Bouton/bouton droite.svg',
                                  width: (16 * scale).clamp(14.0, 22.0),
                                  height: (16 * scale).clamp(14.0, 22.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10 * scale),
          ],
        );
      },
    );
  }
}

class _AuthIcon extends StatelessWidget {
  final String baseName; // sans extension
  final double size;
  final bool highlight;
  const _AuthIcon({required this.baseName, required this.size, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final String svgPath = 'assets/PAGE/Authentification/$baseName.svg';
    final String pngPath = 'assets/PAGE/Authentification/$baseName.png';

    return FutureBuilder<String>(
      future: rootBundle.loadString(svgPath),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError && snap.data != null) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlight ? const Color(0xFFABC270) : Colors.transparent,
                width: highlight ? 2 : 0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SvgPicture.string(snap.data!, width: size, height: size),
            ),
          );
        }
        // Fallback PNG
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight ? const Color(0xFFABC270) : Colors.transparent,
              width: highlight ? 2 : 0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              pngPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) {
                return Container(
                  color: const Color(0xFFF3F5F9),
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                );
              },
            ),
          ),
        );
      },
    );
  }
}


