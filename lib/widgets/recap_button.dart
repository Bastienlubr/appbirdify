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
  final String? leadingAsset; // Icône/asset à gauche du texte (optionnel)
  final double? leadingSize;  // Taille de l'asset (carré)
  final double? leadingGap;   // Espace entre asset et texte

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
    this.leadingAsset,
    this.leadingSize,
    this.leadingGap,
  });

  @override
  State<RecapButton> createState() => _RecapButtonState();
}

class _RecapButtonState extends State<RecapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  // Couleurs par défaut
  static const Color _normalColor = Color(0xFFD2DBB2);
  static const Color _hoverColor = Color(0xFFC8D1A8);
  static const Color _textColor = Color(0xFFF2F5F8);
  // static const Color _shadowColor = Color(0xFFABC270); // Unused
  // static const Color _borderColor = Color(0xFFABC270); // Unused
  // static const Color _hoverBorderColor = Color(0xFF9FB866); // Unused
  
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
      ? (widget.backgroundColor ?? _disabledColor)
      : (_isPressed
          ? (widget.hoverBackgroundColor ?? _hoverColor)
          : (widget.backgroundColor ?? _normalColor));

  Color get _txColor => widget.disabled
      ? (widget.textColor ?? _disabledTextColor)
      : (widget.textColor ?? _textColor);

  // Helpers to enforce contrast: middle lighter than border
  Color _darken(Color color, [double amount = 0.14]) {
    final hsl = HSLColor.fromColor(color);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
  Color _lighten(Color color, [double amount = 0.06]) {
    final hsl = HSLColor.fromColor(color);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  // Compute base (non-state) bg/border/hover colors with contrast if custom bg used
  Color get _baseBgEnabled => widget.backgroundColor ?? _normalColor;
  Color get _baseBorderEnabled {
    if (widget.borderColor != null) return widget.borderColor!;
    // Derive: border darker than bg
    return _darken(_baseBgEnabled, 0.16);
  }
  Color get _baseHoverBgEnabled {
    if (widget.hoverBackgroundColor != null) return widget.hoverBackgroundColor!;
    // Slightly closer to border, but still lighter than it
    final candidate = _darken(_baseBgEnabled, 0.05);
    final border = _baseBorderEnabled;
    // Ensure hoverBg is still lighter than border
    final hb = HSLColor.fromColor(candidate).lightness;
    final bb = HSLColor.fromColor(border).lightness;
    if (hb <= bb) {
      return _lighten(border, 0.06);
    }
    return candidate;
  }
  Color get _baseHoverBorderEnabled => widget.hoverBorderColor ?? _darken(_baseBorderEnabled, 0.06);

  Color get _bdColor => widget.disabled
      ? (widget.borderColor ?? _disabledBorderColor)
      : (_isPressed
          ? _baseHoverBorderEnabled
          : _baseBorderEnabled);

  Color get _shColor => widget.disabled
      ? (widget.shadowColor ?? _disabledShadowColor)
      : (widget.shadowColor ?? _baseBorderEnabled);

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
    // Cibles Duolingo-like
    final double targetTranslateY = widget.disabled
        ? 0.0
        : (_isPressed
            ? 2.0 // enfoncement
            : (_isHovered ? -1.0 : 0.0)); // anticipation (hover)
    final double targetShadow = widget.disabled
        ? 4.0
        : (_isPressed
            ? 1.0
            : (_isHovered ? 3.0 : 4.0));

    final Duration d = const Duration(milliseconds: 150);
    const Curve c = Curves.easeInOut;

    Widget buttonCore = AnimatedContainer(
      duration: d,
      curve: c,
      padding: _resolvedPadding,
      decoration: BoxDecoration(
        color: widget.disabled ? _bgColor : (_isPressed ? _baseHoverBgEnabled : (_isHovered ? _baseHoverBgEnabled : _baseBgEnabled)),
        borderRadius: BorderRadius.circular(_resolvedBorderRadius),
        border: Border.all(
          color: _bdColor,
          width: 2.0,
        ),
        boxShadow: () {
          // Proportions: côtés/haut fins (~1px), bas plus marqué (1..4px)
          final double thin = widget.disabled ? 1.0 : (targetShadow * 0.25).clamp(1.0, 2.0);
          final Color base = _shColor;
          return [
            // Bas (principal)
            BoxShadow(
              color: base.withValues(alpha: 0.8),
              offset: Offset(0, targetShadow),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            // Haut
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              offset: Offset(0, -thin),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            // Gauche
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              offset: Offset(-thin, 0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            // Droite
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              offset: Offset(thin, 0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ];
        }(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.leadingAsset != null) ...[
            Image.asset(
              widget.leadingAsset!,
              width: widget.leadingSize ?? 18,
              height: widget.leadingSize ?? 18,
              filterQuality: FilterQuality.high,
            ),
            SizedBox(width: widget.leadingGap ?? 8),
          ],
          _ScaledText(
            text: widget.text!,
            color: _txColor,
            fontSize: _fontSize,
            fontFamily: widget.fontFamily,
            visualScale: widget.visualScale ?? 1.0,
            lineHeight: widget.lineHeight,
          ),
        ],
      ),
    );

    buttonCore = TweenAnimationBuilder<double>(
      duration: d,
      curve: c,
      tween: Tween<double>(begin: 0.0, end: targetTranslateY),
      builder: (context, ty, child) => Transform.translate(
        offset: Offset(0, ty),
        child: child,
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => Transform.scale(
          scale: widget.disabled ? 1.0 : _scaleAnimation.value,
          child: child,
        ),
        child: buttonCore,
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!widget.disabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!widget.disabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: buttonCore,
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