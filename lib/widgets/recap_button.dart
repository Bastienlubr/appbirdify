import 'package:flutter/material.dart';

enum RecapButtonSize { small, medium, large }

class RecapButton extends StatefulWidget {
  final String? text;
  final VoidCallback? onPressed;
  final bool disabled;
  final RecapButtonSize size;
  final double? fontSize;
  final String? fontFamily;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final Color? shadowColor;
  final double? visualScale; // Permet d'agrandir le texte sans changer la taille du bouton
  final double? lineHeight; // Permet de réduire l'interligne pour le texte multi-ligne

  const RecapButton({
    super.key,
    this.text = "Récapitulatif",
    this.onPressed,
    this.disabled = false,
    this.size = RecapButtonSize.medium,
    this.fontSize,
    this.fontFamily,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.textColor,
    this.borderColor,
    this.hoverBorderColor,
    this.shadowColor,
    this.visualScale,
    this.lineHeight,
  });

  @override
  State<RecapButton> createState() => _RecapButtonState();
}

class _RecapButtonState extends State<RecapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  bool _isPressed = false;

  // Couleurs par défaut
  static const Color _normalColor = Color(0xFFD2DBB2);
  static const Color _hoverColor = Color(0xFFC8D1A8);
  static const Color _textColor = Color(0xFFF2F5F8);
  static const Color _shadowColor = Color(0xFFABC270);
  static const Color _borderColor = Color(0xFFABC270);
  static const Color _hoverBorderColor = Color(0xFF9FB866);
  
  // Couleurs pour l'état disabled
  static const Color _disabledColor = Color(0xFFE5E5E5);
  static const Color _disabledTextColor = Color(0xFF9CA3AF);
  static const Color _disabledShadowColor = Color(0xFFCCCCCC);
  static const Color _disabledBorderColor = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _shadowAnimation = Tween<double>(
      begin: 4.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Padding résolu (override ou selon taille)
  EdgeInsets get _resolvedPadding => widget.padding ?? (() {
        switch (widget.size) {
          case RecapButtonSize.small:
            return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
          case RecapButtonSize.medium:
            return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
          case RecapButtonSize.large:
            return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
        }
      })();

  double get _fontSize {
    if (widget.fontSize != null) {
      final v = widget.fontSize!;
      return v < 8.0 ? 8.0 : (v > 64.0 ? 64.0 : v);
    }
    switch (widget.size) {
      case RecapButtonSize.small:
        return 14;
      case RecapButtonSize.medium:
        return 16;
      case RecapButtonSize.large:
        return 18;
    }
  }

  double get _resolvedBorderRadius => widget.borderRadius ?? (() {
        switch (widget.size) {
          case RecapButtonSize.small:
            return 12.0;
          case RecapButtonSize.medium:
            return 16.0;
          case RecapButtonSize.large:
            return 20.0;
        }
      })();

  // Couleurs résolues (avec overrides possibles)
  Color get _bgColor => widget.disabled
      ? _disabledColor
      : (_isPressed
          ? (widget.hoverBackgroundColor ?? _hoverColor)
          : (widget.backgroundColor ?? _normalColor));

  Color get _txColor => widget.disabled
      ? _disabledTextColor
      : (widget.textColor ?? _textColor);

  Color get _bdColor => widget.disabled
      ? _disabledBorderColor
      : (_isPressed
          ? (widget.hoverBorderColor ?? _hoverBorderColor)
          : (widget.borderColor ?? _borderColor));

  Color get _shColor => widget.disabled
      ? _disabledShadowColor
      : (widget.shadowColor ?? _shadowColor);

  void _handleTapDown(TapDownDetails details) {
    if (!widget.disabled) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.disabled) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.disabled) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTap() {
    if (!widget.disabled && widget.onPressed != null) {
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: _resolvedPadding,
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(_resolvedBorderRadius),
                border: Border.all(
                  color: _bdColor,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _shColor.withValues(alpha: 0.8),
                    offset: Offset(0, _shadowAnimation.value + 2),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: _ScaledText(
                text: widget.text!,
                color: _txColor,
                fontSize: _fontSize,
                fontFamily: widget.fontFamily,
                visualScale: widget.visualScale ?? 1.0,
                lineHeight: widget.lineHeight,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScaledText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final String? fontFamily;
  final double visualScale;
  final double? lineHeight;

  const _ScaledText({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.visualScale,
    this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        fontFamily: fontFamily,
        decoration: TextDecoration.none,
        height: lineHeight,
      ),
      textAlign: TextAlign.center,
    );

    if (visualScale == 1.0) return label;
    return Transform.scale(
      scale: visualScale,
      alignment: Alignment.center,
      child: label,
    );
  }
}

// (Exemples supprimés pour garder le widget minimal et réutilisable)