import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum BoutonUniverselTaille { small, medium, large }

class DecorElement {
  final String assetPath;
  final Offset position; // 0..1
  final double scale; // relatif à la hauteur
  final double rotationDeg;
  final double opacity;
  final int? zIndex;

  const DecorElement({
    required this.assetPath,
    required this.position,
    required this.scale,
    this.rotationDeg = 0,
    this.opacity = 1.0,
    this.zIndex,
  });
}

enum DecorScaleBasis { height, width, max, min }

class BoutonUniversel extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool disabled;

  final Widget? leading;
  final Widget? child;
  final Widget? trailing;
  final Widget? background;
  final Widget? overlay;
  // Diffère le rendu des décors (SVG) au frame suivant pour éviter tout jank lors des ouvertures rapides
  final bool deferDecorsOneFrame;

  // Styles (ex-preset)
  final List<DecorElement>? decorElements;
  // Marge interne pour clipper les décors à l'intérieur du rectangle du milieu
  final EdgeInsets? decorPadding;
  // Si true, on clippe sur le rayon EXTERNE (au bord), pour élargir au maximum
  final bool decorClipToOuter;
  // Multiplicateur global appliqué à tous les décors
  final double decorGlobalScale;
  // Base de calcul pour la taille des décors (par défaut: hauteur)
  final DecorScaleBasis decorScaleBasis;
  // Mode réglage interactif des décors (tap pour sélectionner, slider pour rotation)
  final bool enableDecorTuning;

  final BoutonUniverselTaille size;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Gradient? backgroundGradient;
  final Gradient? hoverBackgroundGradient;
  final Color? textColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final Color? shadowColor;

  final String? label;
  final String? fontFamily;
  final double? fontSize;
  final double? visualScale;
  final double? lineHeight;

  const BoutonUniversel({
    super.key,
    this.onPressed,
    this.disabled = false,
    this.leading,
    this.child,
    this.trailing,
    this.background,
    this.overlay,
    this.decorElements,
    this.size = BoutonUniverselTaille.medium,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.backgroundGradient,
    this.hoverBackgroundGradient,
    this.textColor,
    this.borderColor,
    this.hoverBorderColor,
    this.shadowColor,
    this.label,
    this.fontFamily,
    this.fontSize,
    this.visualScale,
    this.lineHeight,
    this.decorPadding,
    this.decorClipToOuter = false,
    this.decorGlobalScale = 1.0,
    this.decorScaleBasis = DecorScaleBasis.height,
    this.enableDecorTuning = false,
    this.deferDecorsOneFrame = false,
  });

  factory BoutonUniversel.texte({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool disabled = false,
    BoutonUniverselTaille size = BoutonUniverselTaille.medium,
    EdgeInsets? padding,
    EdgeInsets? decorPadding,
    double? decorGlobalScale,
    DecorScaleBasis decorScaleBasis = DecorScaleBasis.height,
    double? borderRadius,
    Color? backgroundColor,
    Color? hoverBackgroundColor,
    Gradient? backgroundGradient,
    Gradient? hoverBackgroundGradient,
    Color? textColor,
    Color? borderColor,
    Color? hoverBorderColor,
    Color? shadowColor,
    String? fontFamily,
    double? fontSize,
    double? visualScale,
    double? lineHeight,
  }) {
    return BoutonUniversel(
      key: key,
      onPressed: onPressed,
      disabled: disabled,
      decorElements: const [],
      size: size,
      padding: padding,
      decorPadding: decorPadding,
      decorGlobalScale: decorGlobalScale ?? 1.0,
      decorScaleBasis: decorScaleBasis,
      borderRadius: borderRadius,
      decorClipToOuter: false,
      backgroundColor: backgroundColor,
      hoverBackgroundColor: hoverBackgroundColor,
      backgroundGradient: backgroundGradient,
      hoverBackgroundGradient: hoverBackgroundGradient,
      textColor: textColor,
      borderColor: borderColor,
      hoverBorderColor: hoverBorderColor,
      shadowColor: shadowColor,
      label: label,
      fontFamily: fontFamily,
      fontSize: fontSize,
      visualScale: visualScale,
      lineHeight: lineHeight,
    );
  }

  @override
  State<BoutonUniversel> createState() => _BoutonUniverselState();
}

class _BoutonUniverselState extends State<BoutonUniversel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;
  int? _selectedDecorIndex;
  List<double>? _rotationOverrides;
  bool _decorsDeferred = false;

  static const Color _normalColor = Color(0xFFD2DBB2);
  static const Color _textColor = Color(0xFFF2F5F8);
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.deferDecorsOneFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _decorsDeferred = true);
        }
      });
    } else {
      _decorsDeferred = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  EdgeInsets get _resolvedPadding => widget.padding ?? (() {
        switch (widget.size) {
          case BoutonUniverselTaille.small:
            return const EdgeInsets.symmetric(horizontal: 16, vertical: 5);
          case BoutonUniverselTaille.medium:
            return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
          case BoutonUniverselTaille.large:
            return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
        }
      })();

  double get _fontSize {
    if (widget.fontSize != null) {
      final v = widget.fontSize!;
      return v < 8.0 ? 8.0 : (v > 64.0 ? 64.0 : v);
    }
    switch (widget.size) {
      case BoutonUniverselTaille.small:
        return 14;
      case BoutonUniverselTaille.medium:
        return 16;
      case BoutonUniverselTaille.large:
        return 18;
    }
  }

  double get _resolvedBorderRadius => widget.borderRadius ?? (() {
        switch (widget.size) {
          case BoutonUniverselTaille.small:
            return 12.0;
          case BoutonUniverselTaille.medium:
            return 16.0;
          case BoutonUniverselTaille.large:
            return 20.0;
        }
      })();

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

  Color get _baseBgEnabled => widget.backgroundColor ?? _normalColor;
  Color get _baseBorderEnabled => widget.borderColor ?? _darken(_baseBgEnabled, 0.16);
  Color get _baseHoverBgEnabled {
    if (widget.hoverBackgroundColor != null) return widget.hoverBackgroundColor!;
    final candidate = _darken(_baseBgEnabled, 0.05);
    final border = _baseBorderEnabled;
    final hb = HSLColor.fromColor(candidate).lightness;
    final bb = HSLColor.fromColor(border).lightness;
    if (hb <= bb) {
      return _lighten(border, 0.06);
    }
    return candidate;
  }
  Color get _baseHoverBorderEnabled => widget.hoverBorderColor ?? _darken(_baseBorderEnabled, 0.06);

  Color get _bgColor => widget.disabled
      ? (widget.backgroundColor ?? _disabledColor)
      : (_isPressed ? _baseHoverBgEnabled : (_isHovered ? _baseHoverBgEnabled : _baseBgEnabled));
  Color get _txColor => widget.disabled ? (widget.textColor ?? _disabledTextColor) : (widget.textColor ?? _textColor);
  Color get _bdColor => widget.disabled ? (widget.borderColor ?? _disabledBorderColor) : (_isPressed ? _baseHoverBorderEnabled : _baseBorderEnabled);
  Color get _shColor => widget.disabled ? (widget.shadowColor ?? _disabledShadowColor) : (widget.shadowColor ?? _baseBorderEnabled);

  Gradient? get _bgGradient {
    final Gradient? base = widget.backgroundGradient;
    final Gradient? hover = widget.hoverBackgroundGradient;
    if (widget.disabled) return base;
    final bool active = _isPressed || _isHovered;
    return active ? (hover ?? base) : base;
  }

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
    // Définition du clip interne: rayon réduit de l'épaisseur de bordure
    const double borderStrokeWidth = 1.0;
    final bool useOuter = widget.decorClipToOuter;
    final double innerClipRadius = useOuter
        ? _resolvedBorderRadius
        : (_resolvedBorderRadius > borderStrokeWidth ? (_resolvedBorderRadius - borderStrokeWidth) : 0.0);
    final EdgeInsets innerDecorPadding = widget.decorPadding ?? (useOuter ? EdgeInsets.zero : const EdgeInsets.all(borderStrokeWidth));

    final double targetTranslateY = widget.disabled
        ? 0.0
        : (_isPressed
            ? 2.0
            : (_isHovered ? -1.0 : 0.0));
    final double targetShadow = widget.disabled
        ? 4.0
        : (_isPressed
            ? 1.0
            : (_isHovered ? 3.0 : 4.0));

    const Duration d = Duration(milliseconds: 150);
    const Curve c = Curves.easeInOut;

    Widget contentRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: _buildChildTextAware(),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 8),
          widget.trailing!,
        ],
      ],
    );

    Widget buttonCore = AnimatedContainer(
      duration: d,
      curve: c,
      decoration: BoxDecoration(
        color: _bgColor,
        gradient: _bgGradient,
        borderRadius: BorderRadius.circular(_resolvedBorderRadius),
        border: Border.all(color: _bdColor, width: 2.0),
        boxShadow: () {
          final double thin = widget.disabled ? 1.0 : (targetShadow * 0.25).clamp(1.0, 2.0);
          final Color base = _shColor;
          return [
            BoxShadow(
              color: base.withValues(alpha: 0.8),
              offset: Offset(0, targetShadow),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              offset: Offset(0, -thin),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              offset: Offset(-thin, 0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              offset: Offset(thin, 0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ];
        }(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_resolvedBorderRadius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_decorsDeferred && ((widget.background != null) || ((widget.decorElements?.isNotEmpty ?? false))))
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !widget.enableDecorTuning,
                  child: Padding(
                    padding: innerDecorPadding,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(innerClipRadius),
                      child: _DecorStack(
                        key: ValueKey(
                          (widget.decorElements ?? const [])
                              .map((e) =>
                                  '${e.assetPath}|${e.position.dx},${e.position.dy}|${e.scale}|${e.rotationDeg}|${e.opacity}|${e.zIndex ?? 0}')
                              .join('\n'),
                        ),
                        elements: widget.decorElements ?? const [],
                        globalScale: widget.decorGlobalScale,
                        scaleBasis: widget.decorScaleBasis,
                        background: widget.background,
                        tuning: widget.enableDecorTuning,
                        rotationOverrides: _rotationOverrides,
                        onSelect: (index) {
                          if (!widget.enableDecorTuning) return;
                          setState(() {
                            _selectedDecorIndex = index;
                            _rotationOverrides ??= List<double>.generate(
                              widget.decorElements?.length ?? 0,
                              (i) => widget.decorElements![i].rotationDeg,
                            );
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: _resolvedPadding,
              child: contentRow,
            ),
            if (widget.overlay != null) widget.overlay!,
          ],
        ),
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

    final Widget core = MouseRegion(
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

    if (!widget.enableDecorTuning || _selectedDecorIndex == null) {
      return core;
    }

    return Stack(
      children: [
        core,
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Text('Rotation', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      min: -180,
                      max: 180,
                      value: (_rotationOverrides?[_selectedDecorIndex!] ??
                              (widget.decorElements?[_selectedDecorIndex!].rotationDeg ?? 0))
                          .toDouble(),
                      onChanged: (v) {
                        setState(() {
                          _rotationOverrides ??= List<double>.generate(
                            widget.decorElements?.length ?? 0,
                            (i) => widget.decorElements![i].rotationDeg,
                          );
                          _rotationOverrides![_selectedDecorIndex!] = v;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildTextAware() {
    if (widget.child != null) {
      if (widget.child is Text && widget.label == null) {
        final Text t = widget.child as Text;
        return _ScaledText(
          text: t.data ?? '',
          color: t.style?.color ?? _txColor,
          fontSize: t.style?.fontSize ?? _fontSize,
          fontFamily: t.style?.fontFamily ?? widget.fontFamily,
          visualScale: widget.visualScale ?? 1.0,
          lineHeight: t.style?.height ?? widget.lineHeight,
          fontWeight: t.style?.fontWeight ?? FontWeight.bold,
          letterSpacing: t.style?.letterSpacing ?? 0.5,
        );
      }
      return widget.child!;
    }

    final String label = widget.label ?? '';
    return _ScaledText(
      text: label,
      color: widget.textColor ?? _txColor,
      fontSize: _fontSize,
      fontFamily: widget.fontFamily,
      visualScale: widget.visualScale ?? 1.0,
      lineHeight: widget.lineHeight,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
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
  final FontWeight fontWeight;
  final double? letterSpacing;

  const _ScaledText({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.visualScale,
    this.lineHeight,
    this.fontWeight = FontWeight.bold,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing ?? 0.5,
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

// ignore: unused_element
class _DecorElementWidget extends StatelessWidget {
  final DecorElement element;
  const _DecorElementWidget({required this.element});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double size = (h * element.scale).clamp(4.0, 2000.0);
        return Positioned(
          left: element.position.dx * w,
          top: element.position.dy * h,
          width: size,
          height: size,
          child: Opacity(
            opacity: element.opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: element.rotationDeg * 3.1415926535897932 / 180.0,
              child: Image.asset(
                element.assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DecorStack extends StatelessWidget {
  final List<DecorElement> elements;
  final Widget? background;
  final double globalScale;
  final DecorScaleBasis scaleBasis;
  final bool tuning;
  final List<double>? rotationOverrides;
  final void Function(int index)? onSelect;
  const _DecorStack({super.key, required this.elements, this.background, this.globalScale = 1.0, this.scaleBasis = DecorScaleBasis.height, this.tuning = false, this.rotationOverrides, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final List<DecorElement> ordered = [...elements]
      ..sort((a, b) => (a.zIndex ?? 0).compareTo(b.zIndex ?? 0));
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < ordered.length; i++) ...[
              () {
                final e = ordered[i];
                double base;
                switch (scaleBasis) {
                  case DecorScaleBasis.width:
                    base = w;
                    break;
                  case DecorScaleBasis.max:
                    base = math.max(w, h);
                    break;
                  case DecorScaleBasis.min:
                    base = math.min(w, h);
                    break;
                  case DecorScaleBasis.height:
                    base = h;
                }
                final double size = (base * e.scale * globalScale).clamp(4.0, 4000.0);
                final double rot = rotationOverrides != null && rotationOverrides!.length == ordered.length
                    ? rotationOverrides![i]
                    : e.rotationDeg;
                return Positioned(
                  left: e.position.dx * w,
                  top: e.position.dy * h,
                  width: size,
                  height: size,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: tuning && onSelect != null ? () => onSelect!(i) : null,
                    child: Opacity(
                      opacity: e.opacity.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: rot * 3.1415926535897932 / 180.0,
                        child: SvgPicture.asset(
                          e.assetPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              }(),
            ],
            if (background != null) background!,
          ],
        );
      },
    );
  }
}

// ignore: unused_element
class _DecorElementSvg extends StatelessWidget {
  final DecorElement element;
  const _DecorElementSvg({required this.element});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double size = (h * element.scale).clamp(4.0, 2000.0);
        return Positioned(
          left: element.position.dx * w,
          top: element.position.dy * h,
          width: size,
          height: size,
          child: Opacity(
            opacity: element.opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: element.rotationDeg * 3.1415926535897932 / 180.0,
              child: SvgPicture.asset(
                element.assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}


