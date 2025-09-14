import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/boutons/bouton_universel.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnulationMotifPage extends StatefulWidget {
  const AnnulationMotifPage({super.key});

  @override
  State<AnnulationMotifPage> createState() => _AnnulationMotifPageState();
}

class _AnnulationMotifPageState extends State<AnnulationMotifPage> {
  static const double _baseW = 375;
  static const double _baseH = 812;

  final List<String> _motifs = const [
    ' Je voulais essayer mindBird Envol de façon temporaire',
    " Je n'utilise plus mindBird",
    ' Les fonctionnalités mindBird Envol ne me sont pas utiles',
    ' MindBird Envol est trop cher pour moi',
    ' Je rencontre des problèmes techniques avec MindBird Envol',
  ];
  String? _selected;
  bool _saving = false;

  @override
  void dispose() {
    super.dispose();
  }

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
                    child: _Canvas(
                      onSelect: (s) => setState(() => _selected = s),
                      selected: _selected,
                      onContinue: _onContinue,
                    ),
                  ),
                ),
                if (_saving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de sélectionner un motif.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final String uid = user?.uid ?? 'anonymous';
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(uid)
          .collection('feedback_annulation')
          .add({
        'motif': _selected,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
    } catch (_) {}
    setState(() => _saving = false);

    final url = Uri.parse('https://play.google.com/store/account/subscriptions');
    // ignore: use_build_context_synchronously
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir Google Play")),
      );
    }
  }

  double _computeScale(double w, double h) {
    if (w <= 0 || h <= 0) return 1.0;
    final sx = w / _baseW;
    final sy = h / _baseH;
    return sx < sy ? sx : sy;
  }
}

class _Canvas extends StatelessWidget {
  final void Function(String) onSelect;
  final String? selected;
  final VoidCallback onContinue;
  const _Canvas({required this.onSelect, required this.selected, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: Stack(
        children: [
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
          const Positioned(
            left: 29,
            top: 170,
            child: SizedBox(
              width: 317,
              child: Text(
                ' Pourquoi souhaites tu annuler ton abonnement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          // Bande de séparation (épaisse) sous le titre
          Positioned(
            left: 26,
            right: 26,
            top: 238,
            child: SizedBox(
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB3858585),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Carte des choix
          Positioned(
            left: 26,
            top: 264,
            child: SizedBox(
              width: 318,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFE),
                  borderRadius: BorderRadius.circular(12),
                  // Pas de bordure externe pour permettre au contour vert
                  // de la case sélectionnée de prendre tout le bord
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChoiceTile(
                      text: ' Je voulais essayer mindBird Envol de façon temporaire',
                      selected: selected == ' Je voulais essayer mindBird Envol de façon temporaire',
                      onTap: () => onSelect(' Je voulais essayer mindBird Envol de façon temporaire'),
                      topRounded: true,
                    ),
                    Container(
                      height: 3,
                      color: (selected == ' Je voulais essayer mindBird Envol de façon temporaire' || selected == " Je n'utilise plus mindBird")
                          ? Colors.transparent
                          : const Color(0xFFDADADA),
                    ),
                    _ChoiceTile(
                      text: " Je n'utilise plus mindBird",
                      selected: selected == " Je n'utilise plus mindBird",
                      onTap: () => onSelect(" Je n'utilise plus mindBird"),
                    ),
                    Container(
                      height: 3,
                      color: (selected == " Je n'utilise plus mindBird" || selected == ' Les fonctionnalités mindBird Envol ne me sont pas utiles')
                          ? Colors.transparent
                          : const Color(0xFFDADADA),
                    ),
                    _ChoiceTile(
                      text: ' Les fonctionnalités mindBird Envol ne me sont pas utiles',
                      selected: selected == ' Les fonctionnalités mindBird Envol ne me sont pas utiles',
                      onTap: () => onSelect(' Les fonctionnalités mindBird Envol ne me sont pas utiles'),
                    ),
                    Container(
                      height: 3,
                      color: (selected == ' Les fonctionnalités mindBird Envol ne me sont pas utiles' || selected == ' MindBird Envol est trop cher\npour moi')
                          ? Colors.transparent
                          : const Color(0xFFDADADA),
                    ),
                    _ChoiceTile(
                      text: ' MindBird Envol est trop cher\npour moi',
                      selected: selected == ' MindBird Envol est trop cher\npour moi',
                      onTap: () => onSelect(' MindBird Envol est trop cher\npour moi'),
                    ),
                    Container(
                      height: 3,
                      color: (selected == ' MindBird Envol est trop cher\npour moi' || selected == ' Je rencontre des problèmes techniques avec MindBird Envol')
                          ? Colors.transparent
                          : const Color(0xFFDADADA),
                    ),
                    _ChoiceTile(
                      text: ' Je rencontre des problèmes techniques avec MindBird Envol',
                      selected: selected == ' Je rencontre des problèmes techniques avec MindBird Envol',
                      onTap: () => onSelect(' Je rencontre des problèmes techniques avec MindBird Envol'),
                      bottomRounded: true,
                    ),
                  ],
                ),
              ),
            ),
          ),


          // Bouton Continuer
          Positioned(
            left: 35.82,
            top: 668.60,
            child: SizedBox(
              width: 303.14,
              height: 44.92,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: (selected == null) ? const Color(0xFFDADADA) : const Color(0xFFEF5350),
                      width: (selected == null) ? 2 : 3,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: BoutonUniversel(
                    onPressed: selected == null ? null : onContinue,
                    disabled: selected == null,
                    size: BoutonUniverselTaille.small,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    backgroundColor: const Color(0xFFFCFCFE),
                    hoverBackgroundColor: const Color(0xFFEDEDED),
                    borderColor: selected == null ? null : const Color(0xFFEF5350),
                    hoverBorderColor: selected == null ? null : const Color(0xFFEF5350),
                    shadowColor: selected == null ? null : const Color(0x40EF5350),
                    child: Center(
                      child: Text(
                        'Résilier mon abonnement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected == null ? const Color(0xFF9CA3AF) : const Color(0xFFE53935),
                          fontSize: 20,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final bool topRounded;
  final bool bottomRounded;
  const _ChoiceTile({
    required this.text,
    required this.selected,
    required this.onTap,
    this.topRounded = false,
    this.bottomRounded = false,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius baseRadius = BorderRadius.only(
      topLeft: Radius.circular(topRounded ? 12 : 0),
      topRight: Radius.circular(topRounded ? 12 : 0),
      bottomLeft: Radius.circular(bottomRounded ? 12 : 0),
      bottomRight: Radius.circular(bottomRounded ? 12 : 0),
    );
    final BorderRadius effectiveRadius = selected ? BorderRadius.circular(12) : baseRadius;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 318,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedScale(
              scale: selected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                constraints: const BoxConstraints(minHeight: 54),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFF2F7EC) : const Color(0xFFFCFCFE),
                  borderRadius: effectiveRadius,
                ),
                child: Center(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Color(0xFF334355),
                      fontSize: 19,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: 1.05,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: effectiveRadius,
                        border: Border.all(color: const Color(0xFFABC270), width: 4),
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


