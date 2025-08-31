import 'package:flutter/material.dart';

class LivesPopup extends StatelessWidget {
  final int currentLives;

  const LivesPopup({super.key, required this.currentLives});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double dialogWidth = (size.width * 0.88).clamp(300.0, 420.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Vies restantes',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF344356),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LivesRow(currentLives: currentLives),
                    const SizedBox(height: 18),

                    // Bouton vert: Regarder une pub pour +1 vie
                    _LayeredButton(
                      outerColor: const Color(0xFF6A994E),
                      innerColor: const Color(0xFFABC270),
                      text: 'Regarder une pub\npour +1 vie',
                      textColor: Colors.white,
                      width: dialogWidth * 0.96,
                      height: 48,
                      onTap: () {
                        Navigator.of(context).pop();
                        // Fonctionnalité à implémenter ultérieurement
                      },
                    ),
                    const SizedBox(height: 12),

                    // Bouton orange: Premium illimité
                    _LayeredButton(
                      outerColor: const Color(0xFFE89E1C),
                      innerColor: const Color(0xFFFEC868),
                      text: 'Avec Premium \nPasse en mode illimité',
                      textColor: Colors.white,
                      width: dialogWidth * 0.88,
                      height: 48,
                      onTap: () {
                        Navigator.of(context).pop();
                        // Fonctionnalité à implémenter ultérieurement
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Bouton fermer (croix)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Color(0xFF344356)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivesRow extends StatelessWidget {
  final int currentLives;
  const _LivesRow({required this.currentLives});

  @override
  Widget build(BuildContext context) {
    // Affichage de 5 icônes de vie (remplies jusqu'à currentLives)
    const int maxLives = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLives, (index) {
        final bool filled = index < currentLives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Opacity(
            opacity: filled ? 1.0 : 0.35,
            child: Image.asset(
              'assets/Images/Bouton/vie.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        );
      }),
    );
  }
}

class _LayeredButton extends StatelessWidget {
  final Color outerColor;
  final Color innerColor;
  final String text;
  final Color textColor;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _LayeredButton({
    required this.outerColor,
    required this.innerColor,
    required this.text,
    required this.textColor,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Outer layer
          Container(
            width: width,
            height: height,
            decoration: ShapeDecoration(
              color: outerColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
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
          // Inner layer (slightly inset)
          Positioned(
            left: 2.4,
            top: 1.8,
            right: 2.4,
            bottom: 2.2,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: innerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
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
          // Tap + Label
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                    height: 0.95,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}


