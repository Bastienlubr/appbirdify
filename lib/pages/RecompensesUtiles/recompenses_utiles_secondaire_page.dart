import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../services/Users/recompenses_utiles_service.dart';
import '../../ui/responsive/responsive.dart';
import '../../ui/scaffold/adaptive_scaffold.dart';
import '../home_screen.dart';
import 'recompenses_utiles_page.dart' show SunburstPainter; // réutilise le même décor
import '../../ui/animations/page_route_universelle.dart';

class RecompensesUtilesSecondairePage extends StatefulWidget {
  final TypeRecompenseSecondaire? forcedType;
  const RecompensesUtilesSecondairePage({super.key, this.forcedType});

  @override
  State<RecompensesUtilesSecondairePage> createState() => _RecompensesUtilesSecondairePageState();
}

class _RecompensesUtilesSecondairePageState extends State<RecompensesUtilesSecondairePage>
    with TickerProviderStateMixin {
  final RecompensesUtilesService _service = RecompensesUtilesService();
  late final AnimationController _sunburstController;
  // (supprimé) Variables de simulation non utilisées

  @override
  void initState() {
    super.initState();
    _sunburstController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _sunburstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = useScreenSize(context);
    final Size screen = MediaQuery.of(context).size;
    final bool isTablet = screen.shortestSide >= 600;
    final bool isWide = screen.aspectRatio >= 0.70;
    final double baseFactor = isTablet ? (isWide ? 0.54 : 0.61) : (s.isMD || s.isLG || s.isXL ? 0.65 : 0.69);
    double ringSize = (screen.shortestSide * baseFactor).clamp(180.0, isTablet ? 520.0 : 460.0);
    final double spacing = (s.spacing() * (isTablet ? 1.15 : 1.0)).clamp(14.0, isTablet ? 46.0 : 40.0).toDouble();
    final double buttonHeight = (56.0 * s.textScale() * (isTablet ? 1.30 : 1.10)).clamp(56.0, 104.0).toDouble();
    final double ringStackHeight = (ringSize + buttonHeight * (isTablet ? 0.74 : 0.60)).toDouble();
    final double animationTop = (ringSize * -0.12) * (isTablet ? 1.5 : 0.6);

    final TypeRecompenseSecondaire? type = widget.forcedType ?? _service.derniereRecompenseSecondaireType;
    final String animationPath = _service.getAnimationPourSecondaire(type ?? TypeRecompenseSecondaire.coeur);

    return AdaptiveScaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFFF2F5F8))),
          // Le "Rising Fire" (Sunburst) est maintenant rendu sous l'animation dans le bloc principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: isTablet ? spacing * 0.5 : 0, left: spacing, right: spacing, bottom: spacing),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isTablet ? (isWide ? 900.0 : 800.0) : 720.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildHeader(s),
                      SizedBox(height: spacing),
                      _buildMainBlock(animationPath, ringSize, ringStackHeight, animationTop),
                      SizedBox(height: 0),
                      _buildMessageBlock(s, type, ringSize),
                      SizedBox(height: spacing * 0.8),
                      if (!isTablet) SizedBox(height: spacing * 0.3),
                      _buildContinueButton(s),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ScreenSize s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(s.spacing(), s.spacing() * 0.1, s.spacing(), s.spacing()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700),
            child: Text(
              'Félicitations !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (40 * s.textScale()).clamp(26.0, 50.0).toDouble(),
                color: const Color(0xFF334355),
                letterSpacing: 0.06,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBlock(String animationPath, double ringSize, double ringStackHeight, double animationTop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ringSize,
            height: ringStackHeight,
            child: Transform.translate(
              offset: Offset(0, -ringSize * 0.18),
              child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Sunburst derrière
                AnimatedBuilder(
                  animation: _sunburstController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _sunburstController.value * 2 * 3.14159,
                      child: Transform.scale(
                        scale: 1.9,
                        child: SizedBox(
                          width: ringSize * 2.2,
                          height: ringSize * 2.2,
                          child: CustomPaint(
                            painter: SunburstPainter(),
                            size: Size(ringSize * 2.2, ringSize * 2.2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Animation coeur centrée par-dessus le sunburst (agrandie x2 et remontée)
                Transform.translate(
                  offset: const Offset(0, 0),
                  child: Transform.scale(
                    scale: 1.5,
                    child: SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Lottie.asset(
                        animationPath,
                        fit: BoxFit.contain,
                        repeat: true,
                        animate: true,
                        onLoaded: (composition) {
                          if (kDebugMode) {
                            debugPrint('✅ Animation secondaire chargée: $animationPath');
                          }
                        },
                        errorBuilder: (context, error, stackTrace) {
                          if (kDebugMode) {
                            debugPrint('❌ Animation secondaire introuvable: $animationPath');
                            debugPrint('❌ Détail: $error');
                          }
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.favorite, color: Colors.redAccent, size: 64),
                                SizedBox(height: 8),
                                Text(
                                  'Animation indisponible',
                                  style: TextStyle(color: Color(0xFF334356)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildMessageBlock(ScreenSize s, TypeRecompenseSecondaire? type, double ringSize) {
    final int livesGained = _service.recompensesActuelles['secondaire_vies'] as int? ?? 0;
    final String headline = (livesGained >= 3)
        ? 'Extraordinaire !\nTu as gagné 3 vies.'
        : (livesGained == 2)
            ? 'Génial ! tu gagnes 2 vies !'
            : (livesGained == 1)
                ? 'Super, Tu gagnes une vie !'
            : 'Bravo ! Tu as obtenu une récompense utile.';
    final String sub = (livesGained >= 3)
        ? 'Ta maîtrise est totale. Profite de ces 3 vies pour explorer encore plus d’habitat.'
        : (livesGained == 2)
            ? 'Deux vies pour pousser encore plus loin ta progression.'
            : (livesGained == 1)
                ? 'Cette vie supplémentaire te permet de poursuivre ta progression sans t’arrêter.'
            : 'Continue sur cette lancée : la prochaine récompense est toute proche !';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: s.spacing() * 0.8, right: s.spacing() * 0.8, top: 0),
      child: Opacity(
        opacity: 0.80,
        child: Transform.translate(
          offset: Offset(0, -ringSize * 0.20),
          child: Column(
            children: [
              Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF334356),
                fontSize: (24 * s.textScale()).clamp(22.0, 36.0).toDouble(),
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                height: 1.26,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
              maxLines: null,
            ),
            SizedBox(height: s.spacing() * 0.52),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF334356),
                fontSize: (18 * s.textScale()).clamp(16.0, 28.0).toDouble(),
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
              maxLines: null,
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(ScreenSize s) {
    return Center(
      child: SizedBox(
        width: 300,
        height: (56.0 * s.textScale() * 1.10).clamp(52.0, 96.0).toDouble(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Consommer l'état secondaire et revenir à la Home
                    _service.consommerRecompenseSecondaire();
                    Navigator.of(context).pushAndRemoveUntil(
                      routePageUniverselle(const HomeScreen(), sens: SensEntree.droite),
                      (route) => false,
                    );
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
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Continuer',
                          style: TextStyle(
                            fontSize: 20,
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
            const Positioned(
              right: 16,
              top: 12,
              bottom: 12,
              child: SizedBox(
                width: 28,
                height: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward, color: Color(0xFF6A994E), size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


