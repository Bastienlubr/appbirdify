import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/Users/recompenses_utiles_service.dart';
import '../../ui/responsive/responsive.dart';
import '../../ui/scaffold/adaptive_scaffold.dart';
import '../home_screen.dart';
import '../../ui/animations/page_route_universelle.dart';
import 'recompenses_utiles_secondaire_page.dart';

/// Layout calculé pour la page des récompenses utiles
/// Similaire au système de la page Score final
class _RewardLayout {
  final double ringSize;
  final double stroke;
  final double scale;
  final double localScale;
  final double spacing;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonTop;
  final double ringStackHeight;
  final double animationTop;
  final double animationSizeFactor;

  const _RewardLayout({
    required this.ringSize,
    required this.stroke,
    required this.scale,
    required this.localScale,
    required this.spacing,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.buttonTop,
    required this.ringStackHeight,
    required this.animationTop,
    required this.animationSizeFactor,
  });
}

/// Page des récompenses utiles reproduisant le design Figma fourni
/// Centrée sur le système d'étoiles avec félicitations
class RecompensesUtilesPage extends StatefulWidget {
  final TypeEtoile? forcedType; // Permet de forcer l'animation/texte selon l'étoile gagnée
  const RecompensesUtilesPage({super.key, this.forcedType});

  @override
  State<RecompensesUtilesPage> createState() => _RecompensesUtilesPageState();
}

class _RecompensesUtilesPageState extends State<RecompensesUtilesPage> 
    with TickerProviderStateMixin {
  
  final RecompensesUtilesService _recompensesService = RecompensesUtilesService();
  late StreamSubscription _recompensesSubscription;
  
  // État des récompenses
  Map<String, dynamic> _recompenses = {};
  
  // Controller pour la rotation du Sunburst
  late AnimationController _sunburstController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialiser le controller de rotation du Sunburst
    _sunburstController = AnimationController(
      duration: const Duration(seconds: 8), // Rotation lente
      vsync: this,
    )..repeat(); // Rotation continue
    
    // Écouter les changements de récompenses
    _recompensesSubscription = _recompensesService.recompensesStream.listen(
      (recompenses) {
        if (mounted) {
          setState(() {
            _recompenses = recompenses;
          });
          
          // Animations d'arrivée supprimées
        }
      },
    );
    
    // Initialiser le service
    _initialiserRecompenses();
  }
  
  Future<void> _initialiserRecompenses() async {
    await _recompensesService.initialiserRecompenses();
    setState(() {
      _recompenses = _recompensesService.recompensesActuelles;
    });
    
    // Animations initiales supprimées
  }
  
  @override
  void dispose() {
    _recompensesSubscription.cancel();
    _sunburstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = useScreenSize(context);
    return AdaptiveScaffold(
      body: Stack(
        children: [
          // Couleur de fond exacte du Figma
          Positioned.fill(
            child: Container(color: const Color(0xFFF2F5F8)),
          ),
          
          // Contenu principal
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // === Ratios et dimensions HARMONISÉS pour tous les écrans ===
                final Size box = constraints.biggest;
                final double shortest = box.shortestSide;
                final bool isWide = box.aspectRatio >= 0.70; // tablette paysage / desktop
                final bool isLarge = s.isMD || s.isLG || s.isXL;
                final bool isTablet = shortest >= 600; // Supporte téléphone + tablette

                _RewardLayout calculateLayout() {
                  // 1) Animation size (remplace l'anneau)
                  final double baseFactor = isTablet
                      ? (isWide ? 0.54 : 0.61)
                      : (isLarge ? 0.65 : 0.69);
                  double ringSize = (shortest * baseFactor);
                  if (isTablet) {
                    ringSize *= isWide ? 0.88 : 0.96;
                  } else if (!isWide && !isLarge) {
                    ringSize *= 0.98;
                  }
                  ringSize = ringSize.clamp(180.0, isTablet ? 520.0 : 460.0);

                  // 2) Stroke (pour cohérence, même si pas d'anneau)
                  final double stroke = (ringSize * 0.082).clamp(10.0, 22.0);

                  // 3) Scales
                  final double scale = s.textScale();
                  final double localScale = isTablet
                      ? (shortest / 800.0).clamp(0.85, 1.2)
                      : (shortest / 600.0).clamp(0.92, 1.45);

                  // 4) Spacing
                  final double spacing = (s.spacing() * localScale * (isTablet ? 1.15 : 1.0))
                      .clamp(14.0, isTablet ? 46.0 : 40.0)
                      .toDouble();

                  // 5) Button size/pos
                  final double buttonWidth = (ringSize * (isTablet ? 0.98 : 1.00)).clamp(180.0, ringSize).toDouble();
                  final double buttonHeight = (56.0 * scale * localScale * (isTablet ? 1.30 : 1.10))
                      .clamp(56.0, 104.0)
                      .toDouble();
                  final double buttonStrokeFactor = isTablet ? (isWide ? 1.38 : 2.4) : 1.50;
                  double buttonTop = (ringSize - (buttonStrokeFactor * stroke) + s.buttonOverlapPx())
                      .clamp(0.0, ringSize);
                  if (isWide) {
                    final double extraLift = stroke * 1.20; // alignement similaire Score Final
                    buttonTop = (buttonTop - extraLift).clamp(0.0, ringSize);
                  }
                  final double ringStackHeight = (ringSize + buttonHeight * (isTablet ? 0.74 : 0.60)).toDouble();

                  // 6) Animation position et taille
                  final double animationTop = (stroke * (isTablet ? (isWide ? -0.58 : -1.50) : -0.50));
                  final double animationSizeFactor = isTablet ? 0.96 : 0.52;

                  return _RewardLayout(
                    ringSize: ringSize,
                    stroke: stroke,
                    scale: scale,
                    localScale: localScale,
                    spacing: spacing,
                    buttonWidth: buttonWidth,
                    buttonHeight: buttonHeight,
                    buttonTop: buttonTop,
                    ringStackHeight: ringStackHeight,
                    animationTop: animationTop,
                    animationSizeFactor: animationSizeFactor,
                  );
                }

                final layout = calculateLayout();
                final Size screen = MediaQuery.of(context).size;
                final bool isDesktopLike = (kIsWeb && screen.width >= 1024) || (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux));

                if (!isDesktopLike) {
                  return Stack(
                    children: [
                      Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            top: isTablet ? layout.spacing * 0.5 : 0,
                            left: layout.spacing,
                            right: layout.spacing,
                            bottom: layout.spacing,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? (isWide ? 900.0 : 800.0) : 720.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildHeaderBlock(layout),
                                SizedBox(height: layout.spacing),
                                _buildMainBlock(layout),
                                SizedBox(height: isTablet ? layout.spacing * 0.2 : layout.spacing * 0.4),
                                _buildMessageBlock(layout),
                                SizedBox(height: layout.spacing * 0.8),
                                if (!isTablet) SizedBox(height: layout.spacing * 0.3),
                                _buildContinueButton(layout),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    // Contenu principal (inclut le sunburst imbriqué)
                    Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: isTablet ? layout.spacing * 0.5 : 0,
                            left: layout.spacing,
                            right: layout.spacing,
                            bottom: layout.spacing,
                          ),
                  child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? (isWide ? 900.0 : 800.0) : 720.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, layout.spacing * 2.00),
                                  child: _buildHeaderBlock(layout),
                                ),
                                SizedBox(height: isWide ? layout.spacing * 0.06 : (isTablet ? layout.spacing * 0.10 : layout.spacing * 0.18)),
                                Transform.translate(
                                  offset: Offset(0, layout.spacing * 2.60),
                                  child: _buildMainBlock(layout),
                                ),
                                SizedBox(height: isTablet ? layout.spacing * 0.10 : layout.spacing * 0.18),
                                Transform.translate(
                                  offset: Offset(0, -layout.spacing * 0.45),
                                  child: _buildMessageBlock(layout),
                                ),
                                SizedBox(height: _dynamicMessageSpacing(layout.spacing, isTablet, isWide)),
                                if (!isTablet) SizedBox(height: layout.spacing * 0.2),
                                Transform.translate(
                                  offset: Offset(0, -layout.spacing * 0.34),
                                  child: _buildContinueButton(layout),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Éléments décoratifs supprimés sur demande utilisateur
        ],
      ),
    );
  }

  TypeEtoile _currentRewardType() {
    return widget.forcedType ?? (_recompenses['derniere_recompense_type'] ?? TypeEtoile.uneEtoile);
  }

  /// Bloc 1: Header "Félicitations !!"
  Widget _buildHeaderBlock(_RewardLayout layout) {
    final derniereRecompense = _currentRewardType();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(layout.spacing, layout.spacing * 0.1, layout.spacing, layout.spacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
            ),
            child: Text(
              'Félicitations !!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (40 * layout.scale).clamp(26.0, 50.0).toDouble(),
                color: const Color(0xFF334355),
                letterSpacing: 0.06,
              ),
            ),
          ),
          SizedBox(height: layout.spacing / 2),
          Text(
            _getSousTitrePourEtoiles(derniereRecompense),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w500,
              fontSize: (18 * layout.scale).clamp(16.0, 24.0).toDouble(),
              color: const Color(0xFF6A7280),
            ),
          ),
        ],
      ),
    );
  }

  /// Génère le sous-titre selon le type d'étoiles obtenues
  String _getSousTitrePourEtoiles(TypeEtoile type) {
    switch (type) {
      case TypeEtoile.uneEtoile:
        return 'Tu as gagné une étoile !';
      case TypeEtoile.deuxEtoiles:
        return 'Tu as gagné deux étoiles !';
      case TypeEtoile.troisEtoiles:
        return 'Tu as gagné trois étoiles !';
    }
  }

  /// Bloc 2: Zone principale avec animation centrale
  Widget _buildMainBlock(_RewardLayout layout) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.spacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: layout.ringSize,
            height: layout.ringStackHeight,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Sunburst + Animation imbriqués et centrés
                Transform.translate(
                  offset: Offset(0, -layout.ringSize * 0.18),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Sunburst derrière (mêmes proportions que secondaire)
                      AnimatedBuilder(
                        animation: _sunburstController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -layout.ringSize * 0.27), // remonte davantage le Sunburst
                            child: Transform.rotate(
                              angle: _sunburstController.value * 2 * 3.14159,
                              child: Transform.scale(
                                scale: 2.05, // agrandit légèrement
                                child: SizedBox(
                                  width: layout.ringSize * 2.35,
                                  height: layout.ringSize * 2.35,
                                  child: CustomPaint(
                                    painter: SunburstPainter(),
                                    size: Size(layout.ringSize * 2.35, layout.ringSize * 2.35),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Animation étoiles au-dessus (agrandie)
                      Transform.scale(
                        scale: 1.5,
                        child: _buildAnimationWidget(layout),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

    /// Bloc 3: Textes de félicitations
  Widget _buildMessageBlock(_RewardLayout layout) {
    final derniereRecompense = _currentRewardType();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.spacing * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Texte adaptatif selon le nombre d'étoiles
          SizedBox(
            width: double.infinity,
            child: Opacity(
              opacity: 0.80,
              child: Text(
                _getMessagePourEtoiles(derniereRecompense, _recompenses['etoiles_totales'] ?? 1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF334356),
                  fontSize: (20 * layout.scale * layout.localScale).clamp(18.0, 32.0).toDouble(),
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w500,
                  height: 1.40,
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
                maxLines: null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Génère le message selon le type d'étoiles obtenues
  String _getMessagePourEtoiles(TypeEtoile type, int nombreTotal) {
    switch (type) {
      case TypeEtoile.uneEtoile:
        return 'Bravo, première étoile gagnée !\nUne de plus et tu débloques la prochaine épreuve.';
      case TypeEtoile.deuxEtoiles:
        return 'Excellent ! Deux étoiles obtenues !\nEncore une et tu maîtrises parfaitement cette épreuve.';
      case TypeEtoile.troisEtoiles:
        return 'Incroyable ! Trois étoiles !\nTu es maintenant un expert de cette épreuve !';
    }
  }

  /// Bloc 4: Bouton continuer
  Widget _buildContinueButton(_RewardLayout layout) {
    return SizedBox(
      width: layout.buttonWidth,
      height: (layout.buttonHeight * 1.05).clamp(52.0, 96.0).toDouble(),
      child: Stack(
        children: [
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (_recompensesService.secondaireDisponible) {
                    Navigator.of(context).push(
                      routePageUniverselle(const RecompensesUtilesSecondairePage(), sens: SensEntree.droite),
                    );
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      routePageUniverselle(const HomeScreen(), sens: SensEntree.droite),
                      (route) => false,
                    );
                  }
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A994E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Continuer',
                        style: TextStyle(
                          fontSize: (20 * layout.scale).clamp(18.0, 28.0).toDouble(),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Quicksand',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
          Positioned(
            right: 16,
            top: 12,
            bottom: 12,
            child: SizedBox(
              width: 28,
              height: 28,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(1.0, 0.0),
                    child: SvgPicture.asset(
                      'assets/Images/Bouton/bouton droite.svg',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Color(0xFF6A994E), BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _dynamicMessageSpacing(double spacing, bool isTablet, bool isWide) {
    double base = spacing * (isTablet ? 0.10 : 0.18);
    if (isWide) base *= 0.78; // harmonisé avec Score Final
    return base;
  }

  /// Construit le widget d'animation
  Widget _buildAnimationWidget(_RewardLayout layout) {
    final animations = _recompenses['animations_disponibles'] as List? ?? [];
    final derniereRecompense = _currentRewardType();
    if (kDebugMode) {
      debugPrint('🎬 Animations disponibles: $animations');
      debugPrint('🌟 Dernière récompense: $derniereRecompense');
    }
    final animationPath = _recompensesService.getAnimationPourEtoiles(derniereRecompense);
    if (kDebugMode) {
      debugPrint('🎬 Chargement direct de l\'animation: $animationPath');
    }
    return SizedBox(
      width: layout.ringSize,
      height: layout.ringSize,
      child: Lottie.asset(
        animationPath,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
        onLoaded: (composition) {
          if (kDebugMode) {
            debugPrint('✅ Animation Lottie chargée: $animationPath, dur=${composition.duration}');
          }
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ Erreur chargement animation: $animationPath');
            debugPrint('❌ Détail erreur: $error');
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: layout.ringSize * 0.15, color: Colors.red),
                SizedBox(height: 8),
                Text('Animation\nindisponible', textAlign: TextAlign.center, style: TextStyle(fontSize: layout.ringSize * 0.05, color: Colors.red)),
              ],
            ),
          );
        },
      ),
    );
  }

  // Méthode supprimée : plus d'animation fallback avec étoiles
  // L'animation Lottie est chargée directement depuis le service

  // Méthode _buildStarsLayout supprimée - plus utilisée avec les animations Lottie

  /// Construire l'effet Sunburst rotatif
  Widget _buildSunburstEffect(_RewardLayout layout) {
    return AnimatedBuilder(
      animation: _sunburstController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _sunburstController.value * 2 * 3.14159, // Rotation complète
          child: Transform.scale(
            scale: 1.5, // Agrandissement modéré - juste milieu parfait !
            child: SizedBox(
              width: layout.ringSize * 1.8,
              height: layout.ringSize * 1.8,
              child: CustomPaint(
                painter: SunburstPainter(),
                size: Size(layout.ringSize * 1.8, layout.ringSize * 1.8),
              ),
            ),
          ),
        );
      },
    );
  }

  // Méthodes _getMessagePourEtoiles et _getSousTitrePourEtoiles déjà définies plus haut dans le fichier
}

/// CustomPainter pour dessiner l'effet Sunburst lumineux et discret
class SunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // 1. Dégradé radial central (jaune vif → blanc)
    _drawRadialGlow(canvas, center, radius);
    
    // 2. Halo ondulé jaune clair autour
    _drawUndulatingHalo(canvas, center, radius);
    
    // 3. Rayons triangulaires isocèles (fins au centre, épais au bout)
    _drawSunRays(canvas, center, radius);
  }
  
  /// Dessiner le dégradé radial central lumineux
  void _drawRadialGlow(Canvas canvas, Offset center, double radius) {
    final glowRadius = radius * 0.3; // Taille de base (Transform.scale s'occupe de l'agrandissement)
    
    final radialGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xFFFFEB3B).withValues(alpha: 0.25),
        const Color(0xFFFFF176).withValues(alpha: 0.15),
        const Color(0xFFFFFFFF).withValues(alpha: 0.08),
        Colors.transparent, // Transparent à l'extérieur
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );
    
    final glowPaint = Paint()
      ..shader = radialGradient.createShader(Rect.fromCircle(
        center: center,
        radius: glowRadius,
      ));
    
    canvas.drawCircle(center, glowRadius, glowPaint);
  }
  
  /// Dessiner le halo ondulé autour
  void _drawUndulatingHalo(Canvas canvas, Offset center, double radius) {
    const int waveCount = 54;
    final haloRadius = radius * 0.95; // Taille de base
    final waveAmplitude = radius * 0.58; // Taille de base
    
    final path = Path();
    bool firstPoint = true;
    
    for (int i = 0; i <= waveCount; i++) {
      final angle = (i * 2 * math.pi) / waveCount;
      final waveOffset = math.sin(angle * 3) * waveAmplitude; // Ondulation
      final currentRadius = haloRadius + waveOffset;
      
      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);
      
      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    // Dégradé radial pour un estompage progressif ultra-fluide
    final haloGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xFFFFEB3B).withValues(alpha: 0.08),
        const Color(0xFFFFEB3B).withValues(alpha: 0.04),
        const Color(0xFFFFEB3B).withValues(alpha: 0.02),
        Colors.transparent, // Transparent aux extrémités
      ],
      stops: const [0.0, 0.6, 0.85, 1.0],
    );
    
    final haloPaint = Paint()
      ..shader = haloGradient.createShader(Rect.fromCircle(
        center: center,
        radius: haloRadius,
      ))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, haloPaint);
  }
  
  /// Dessiner les rayons triangulaires isocèles avec estompage progressif
  void _drawSunRays(Canvas canvas, Offset center, double radius) {
    const int rayCount = 16;
    
    for (int i = 0; i < rayCount; i++) {
      final baseAngle = (i * 2 * math.pi) / rayCount;
      
      // Rayons alternés longs et courts
      final isLongRay = i % 2 == 0;
      final rayLength = isLongRay ? radius * 0.9 : radius * 0.65; // Taille de base
      
      // Largeur du rayon : fin au centre, plus épais au bout (AUGMENTÉ)
      final centerWidth = radius * 0.02; // Légèrement plus épais au centre
      final tipWidth = isLongRay ? radius * 0.12 : radius * 0.08; // RAYONS PLUS LARGES
      
      // Créer le triangle isocèle
      final path = Path();
      
      // Point central (base du triangle)
      final centerStart = Offset(
        center.dx + (radius * 0.25) * math.cos(baseAngle),
        center.dy + (radius * 0.25) * math.sin(baseAngle),
      );
      
      // Points de base (largeur au centre)
      final leftBase = Offset(
        centerStart.dx + centerWidth * math.cos(baseAngle + math.pi / 2),
        centerStart.dy + centerWidth * math.sin(baseAngle + math.pi / 2),
      );
      final rightBase = Offset(
        centerStart.dx + centerWidth * math.cos(baseAngle - math.pi / 2),
        centerStart.dy + centerWidth * math.sin(baseAngle - math.pi / 2),
      );
      
      // Points d'extrémité (largeur au bout)
      final tipCenter = Offset(
        center.dx + rayLength * math.cos(baseAngle),
        center.dy + rayLength * math.sin(baseAngle),
      );
      final leftTip = Offset(
        tipCenter.dx + tipWidth * math.cos(baseAngle + math.pi / 2),
        tipCenter.dy + tipWidth * math.sin(baseAngle + math.pi / 2),
      );
      final rightTip = Offset(
        tipCenter.dx + tipWidth * math.cos(baseAngle - math.pi / 2),
        tipCenter.dy + tipWidth * math.sin(baseAngle - math.pi / 2),
      );
      
      // Construire le polygone du rayon
      path.moveTo(leftBase.dx, leftBase.dy);
      path.lineTo(rightBase.dx, rightBase.dy);
      path.lineTo(rightTip.dx, rightTip.dy);
      path.lineTo(leftTip.dx, leftTip.dy);
      path.close();
      
      // ESTOMPAGE PROGRESSIF : opacité réduite selon la distance du centre de l'étoile
      final distanceFromCenter = rayLength / radius; // Ratio 0.0 -> 1.0
      final fadeOpacity = math.max(0.05, 0.35 * (1.0 - distanceFromCenter * 0.8)); // Plus on s'éloigne, plus ça s'estompe
      
      // Dégradé avec effet diffus sur les côtés pour les rayons longs
      late Paint rayPaint;
      
      if (isLongRay) {
        // RAYONS LONGS : Effet diffus avec dégradé radial depuis le centre du rayon
        final rayCenter = Offset(
          (centerStart.dx + tipCenter.dx) / 2,
          (centerStart.dy + tipCenter.dy) / 2,
        );
        
        final rayRadialGradient = RadialGradient(
          center: Alignment.center,
          radius: 1.2, // Élargi pour effet diffus sur les côtés
          colors: [
            const Color(0xFFFFEB3B).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 1.4),
            const Color(0xFFFFC107).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 1.0),
            const Color(0xFFFFEB3B).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 0.6),
            const Color(0xFFFFEB3B).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 0.2),
            Colors.transparent, // Extrémités transparentes pour effet fondu
          ],
          stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
        );
        
        rayPaint = Paint()
          ..shader = rayRadialGradient.createShader(Rect.fromPoints(
            Offset(rayCenter.dx - tipWidth * 1.5, rayCenter.dy - rayLength * 0.6),
            Offset(rayCenter.dx + tipWidth * 1.5, rayCenter.dy + rayLength * 0.6),
          ));
      } else {
        // RAYONS COURTS : Dégradé linéaire classique
        final rayLinearGradient = LinearGradient(
          begin: Alignment.center,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFFFEB3B).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 1.2),
            const Color(0xFFFFC107).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 0.8),
            const Color(0xFFFFEB3B).withValues(alpha: 0.0).withValues(alpha: fadeOpacity * 0.3),
          ],
          stops: const [0.0, 0.7, 1.0],
        );
        
        rayPaint = Paint()
          ..shader = rayLinearGradient.createShader(Rect.fromPoints(centerStart, tipCenter));
      }
      
      canvas.drawPath(path, rayPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
