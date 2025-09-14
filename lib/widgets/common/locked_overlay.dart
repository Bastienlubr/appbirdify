import 'dart:ui';
import 'package:flutter/material.dart';

class LockedOverlay extends StatelessWidget {
  final String label;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;

  const LockedOverlay({
    super.key,
    this.label = 'Prochainement disponible',
    this.blurSigma = 6.0,
    this.opacity = 0.75,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = borderRadius ?? BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: br,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(color: Colors.transparent),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: br,
              border: Border.all(color: const Color(0xFF473C33), width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: Color(0xFF473C33)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF473C33),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


