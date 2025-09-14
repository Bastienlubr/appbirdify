import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/boutons/bouton_universel.dart';
import '../../services/abonnement/premium_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum OffreType { mois1, mois6, mois12 }

class ChoixOffrePage extends StatefulWidget {
  const ChoixOffrePage({super.key});

  @override
  State<ChoixOffrePage> createState() => _ChoixOffrePageState();
}

class _ChoixOffrePageState extends State<ChoixOffrePage> {
  OffreType _selection = OffreType.mois1; // par défaut comme le design (encadré vert)

  static const double _baseW = 375;
  static const double _baseH = 812;

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
                      selection: _selection,
                      onSelect: (t) => setState(() => _selection = t),
                      onContinue: _onContinue,
                    ),
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
    final premium = PremiumService.instance;
    // Forcer un refresh des produits (utile après ajout d'un nouveau SKU côté Play)
    await premium.refreshProducts();
    bool ok = false;
    switch (_selection) {
      case OffreType.mois1:
        ok = await premium.buyMonthly();
        break;
      case OffreType.mois6:
        // Si un SKU 6 mois existe, utilise-le, sinon fallback annuel
        final has6 = premium.semiAnnualPlan != null;
        ok = has6 ? await premium.buySemiAnnual() : await premium.buyYearly();
        break;
      case OffreType.mois12:
        ok = await premium.buyYearly();
        break;
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit indisponible. Réessaie plus tard.')),
      );
    } else {
      Navigator.of(context).maybePop();
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
  final OffreType selection;
  final ValueChanged<OffreType> onSelect;
  final VoidCallback onContinue;
  const _Canvas({required this.selection, required this.onSelect, required this.onContinue});

  // ignore: unused_element
  TextStyle get _fredoka24 => const TextStyle(
        color: Color(0xFF334355),
        fontSize: 24,
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w600,
      );

  @override
  Widget build(BuildContext context) {
    final premium = PremiumService.instance;
    return SizedBox(
      width: 375,
      height: 812,
      child: Stack(
        children: [
          // Back arrow (top-left)
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
          // Logo Premium (opposé au bouton retour)
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
          

          // Titre
          const Positioned(
            left: 60,
            top: 218,
            child: Text('Choisis un abonnement', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'Fredoka', fontWeight: FontWeight.w700)),
          ),

          // Bande de séparation (plus épaisse)
          Positioned(
            left: 26,
            right: 26,
            top: 258,
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

          // Groupe unique des offres (3 sections + séparateurs gris)
          ValueListenableBuilder<List<ProductDetails>>(
            valueListenable: premium.products,
            builder: (context, products, _) {
              final monthly = premium.monthlyPriceLabel ?? '4,99 € / mois';
              final monthlyRaw = premium.monthlyRawPrice;
              final monthlyCur = premium.monthlyCurrencyCode;
              final semiPerMonth = premium.semiAnnualPerMonthLabel ?? '3,83 € / mois';
              // Si prix mensuel dispo, price barré = 6 * prix mensuel
              final semiStruck = (monthlyRaw != null && monthlyCur != null)
                  ? premium.formatCurrency(monthlyRaw * 6.0, monthlyCur)
                  : null;
              final semiTotal = premium.semiAnnualTotalPriceLabel ?? '29,94 €';
              final yearlyPerMonth = premium.yearlyPerMonthLabel ?? '2,83 € / mois';
              final yearlyTotal = premium.yearlyTotalPriceLabel ?? '39,99 €';
              return _OffersGroup(
                selection: selection,
                onSelect: onSelect,
                monthlyPriceLabel: monthly,
                yearlyPerMonthLabel: yearlyPerMonth,
                yearlyTotalPriceLabel: yearlyTotal,
                semiAnnualPerMonthLabel: semiPerMonth,
                semiAnnualTotalPriceLabel: semiTotal,
                semiAnnualStruckLabel: semiStruck,
              );
            },
          ),

          // CTA: Bouton universel style bandeau clair
          Positioned(
            left: 35.82,
            top: 688.60,
            child: SizedBox(
              width: 303.14,
              height: 44.92,
              child: BoutonUniversel(
                onPressed: onContinue,
                size: BoutonUniverselTaille.small,
                borderRadius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                backgroundColor: const Color(0xFFFCFCFE),
                borderColor: const Color(0xB3858585),
                shadowColor: const Color(0xB3858585),
                child: const Center(
                  child: Text(
                    'Commencer mes 3 jours gratuit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF334355),
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
        ],
      ),
    );
  }
}

// ignore: unused_element
class _HomeIndicator2 extends StatelessWidget {
  const _HomeIndicator2();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 121,
      top: 799,
      child: Opacity(
        opacity: 0.20,
        child: Container(
          width: 134,
          height: 5,
          decoration: ShapeDecoration(
            color: const Color(0xFF334355),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2.50),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _Offer12 extends StatelessWidget {
  final OffreType selection;
  final ValueChanged<OffreType> onSelect;
  const _Offer12({required this.selection, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 35,
      top: 284,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(OffreType.mois12),
        child: SizedBox(
          width: 300,
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Card top (coins supérieurs arrondis)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 300,
                  height: 82,
                  decoration: const ShapeDecoration(
                    color: Color(0xFFFCFCFE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              // Textes
              const Positioned(
                left: 17,
                top: 30,
                child: SizedBox(
                  width: 91,
                  height: 21,
                  child: Text('12 mois', style: TextStyle(color: Color(0xFF334355), fontSize: 26, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.08, letterSpacing: 1)),
                ),
              ),
              const Positioned(
                left: 192,
                top: 30,
                child: SizedBox(
                  width: 103,
                  height: 21,
                  child: Text('2,83 € / mois', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.87, letterSpacing: 1)),
                ),
              ),
              const Positioned(
                left: 17,
                top: 55,
                child: SizedBox(
                  width: 169,
                  height: 21,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '59,', style: TextStyle(color: Color(0x87334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, height: 1.87, letterSpacing: 1)),
                      TextSpan(text: '8', style: TextStyle(color: Color(0x8C334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, height: 1.87, letterSpacing: 1)),
                      TextSpan(text: '8 €', style: TextStyle(color: Color(0x87334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, height: 1.87, letterSpacing: 1)),
                      TextSpan(text: '  39,99 €', style: TextStyle(color: Color(0xFF334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.87, letterSpacing: 1)),
                    ]),
                  ),
                ),
              ),
              // Ruban "Le plus populaire"
              Positioned(
                left: 20,
                top: -7,
                child: Container(
                  width: 162,
                  height: 21,
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(0.01, 0.98),
                      end: Alignment(0.99, 0.14),
                      colors: [Color(0xFF6A994E), Color(0xFFABC270)],
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFFABC270)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 20,
                top: -7,
                child: SizedBox(
                  width: 162,
                  height: 21,
                  child: Text(' Le plus populaire', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFCFCFE), fontSize: 16, fontFamily: 'Fredoka', fontWeight: FontWeight.w500, height: 1.75, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _Offer1 extends StatelessWidget {
  final OffreType selection;
  final ValueChanged<OffreType> onSelect;
  const _Offer1({required this.selection, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 26,
      top: 366,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(OffreType.mois1),
        child: SizedBox(
          width: 318,
          height: 87,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 5,
                top: 0,
                child: Container(
                  width: 309,
                  height: 85,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFCFCFE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 24,
                top: 32,
                child: SizedBox(
                  width: 96.46,
                  height: 21,
                  child: Text('1 mois', style: TextStyle(color: Color(0xFF334355), fontSize: 26, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.08, letterSpacing: 1)),
                ),
              ),
              const Positioned(
                left: 203.52,
                top: 33,
                child: SizedBox(
                  width: 109.18,
                  height: 21,
                  child: Text('4,99 € / mois', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.87, letterSpacing: 1)),
                ),
              ),
              // pastille verte à droite
              // pastille verte fixe comme sur la maquette
              // pastille retirée pour un rendu neutre
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _Offer6 extends StatelessWidget {
  final OffreType selection;
  final ValueChanged<OffreType> onSelect;
  const _Offer6({required this.selection, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 35,
      top: 451,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(OffreType.mois6),
        child: SizedBox(
          width: 300,
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: SizedBox(
                  width: 300,
                  height: 82,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Color(0xFFFCFCFE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 17,
                top: 30,
                child: SizedBox(
                  width: 91,
                  height: 21,
                  child: Text('6 mois', style: TextStyle(color: Color(0xFF334355), fontSize: 26, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.08, letterSpacing: 1)),
                ),
              ),
              const Positioned(
                left: 192,
                top: 30,
                child: SizedBox(
                  width: 103,
                  height: 21,
                  child: Text('3,83 € / mois', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.87, letterSpacing: 1)),
                ),
              ),
              const Positioned(
                left: 17,
                top: 55,
                child: SizedBox(
                  width: 169,
                  height: 21,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '29,94 €', style: TextStyle(color: Color(0x87334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, height: 1.87, letterSpacing: 1)),
                      TextSpan(text: '  ', style: TextStyle(color: Color(0x87334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.87, letterSpacing: 1)),
                      TextSpan(text: '22,99 €', style: TextStyle(color: Color(0xFF334355), fontSize: 15, fontFamily: 'Fredoka', fontWeight: FontWeight.w600, height: 1.87, letterSpacing: 1)),
                    ]),
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


class _OffersGroup extends StatelessWidget {
  final OffreType selection;
  final ValueChanged<OffreType> onSelect;
  final String monthlyPriceLabel;
  final String yearlyPerMonthLabel;
  final String yearlyTotalPriceLabel;
  final String semiAnnualPerMonthLabel;
  final String semiAnnualTotalPriceLabel;
  final String? semiAnnualStruckLabel;
  const _OffersGroup({
    required this.selection,
    required this.onSelect,
    required this.monthlyPriceLabel,
    required this.yearlyPerMonthLabel,
    required this.yearlyTotalPriceLabel,
    required this.semiAnnualPerMonthLabel,
    required this.semiAnnualTotalPriceLabel,
    this.semiAnnualStruckLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 26,
      top: 284,
      child: Container(
        width: 318,
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 12 mois (cliquable)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(OffreType.mois12),
              child: _OfferRowCentered(
                height: 92,
                borderRadius: selection == OffreType.mois12
                    ? BorderRadius.circular(12)
                    : const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                leftTitle: '12 mois',
                rightSubtitle: yearlyPerMonthLabel,
                bottomStruck: '59,88 €',
                bottomValue: '  $yearlyTotalPriceLabel',
                outlinedGreen: selection == OffreType.mois12,
                // centered baseline (no shift)
                shiftY: 0,
                discountOffset: 10,
              ),
            ),
            // Separator between top and middle
            _SeparatorLine(
              thickness: 3,
              color: (selection == OffreType.mois12 || selection == OffreType.mois1)
                  ? Colors.transparent
                  : const Color(0xB3858585),
            ),
            // 1 mois (cliquable)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(OffreType.mois1),
              child: _OfferRow(
                height: 89,
                borderRadius: selection == OffreType.mois1
                    ? BorderRadius.circular(10)
                    : const BorderRadius.all(Radius.circular(0)),
                outlinedGreen: selection == OffreType.mois1,
                leftTitle: '1 mois',
                rightSubtitle: monthlyPriceLabel,
              ),
            ),
            // Separator between middle and bottom
            _SeparatorLine(
              thickness: 3,
              color: (selection == OffreType.mois1 || selection == OffreType.mois6)
                  ? Colors.transparent
                  : const Color(0xB3858585),
            ),
            // 6 mois (cliquable)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(OffreType.mois6),
              child: _OfferRowCentered(
                height: 92,
                borderRadius: selection == OffreType.mois6
                    ? BorderRadius.circular(12)
                    : const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                leftTitle: '6 mois',
                rightSubtitle: semiAnnualPerMonthLabel,
                bottomStruck: semiAnnualStruckLabel,
                bottomValue: '  $semiAnnualTotalPriceLabel',
                outlinedGreen: selection == OffreType.mois6,
                shiftY: -6,
                discountOffset: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeparatorLine extends StatelessWidget {
  final double thickness;
  final Color color;
  const _SeparatorLine({this.thickness = 3, this.color = const Color(0xB3858585)});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  // ignore: unused_element_parameter
  final double size;
  const _SelectionBadge({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(color: Color(0xFFABC270), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x334CAF50), blurRadius: 8, offset: Offset(0, 2))]),
      child: Center(
        child: SvgPicture.asset(
          'assets/Images/Bouton/check.svg',
          width: size * 0.48,
          height: size * 0.48,
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _OfferRowCentered extends StatelessWidget {
  final double height;
  final BorderRadius borderRadius;
  final String leftTitle;
  final String rightSubtitle;
  final String? bottomStruck;
  final String? bottomValue;
  // Fine-grained controls
  final double centerYOffset; // nudge title+price relative to center
  final double discountOffset; // base offset (from center) for the discount line
  // Unified control: shift the whole block (title+price and discount) together
  final double shiftY;
  final bool outlinedGreen; // show selected outline

  const _OfferRowCentered({
    required this.height,
    required this.borderRadius,
    required this.leftTitle,
    required this.rightSubtitle,
    this.bottomStruck,
    this.bottomValue,
    // ignore: unused_element_parameter
    this.centerYOffset = 0,
    this.discountOffset = 10,
    this.shiftY = 0,
    this.outlinedGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final double effectiveCenterYOffset = centerYOffset + shiftY;
    final double effectiveDiscountOffset = discountOffset + shiftY;
    final bool selected = outlinedGreen;
    final double scale = selected ? 1.065 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: SizedBox(
        width: 318,
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: const Color(0xFFFCFCFE),
            shape: RoundedRectangleBorder(
              side: selected ? const BorderSide(width: 6, color: Color(0xFFABC270)) : BorderSide.none,
              borderRadius: borderRadius,
            ),
            shadows: selected
                ? const [
                    BoxShadow(color: Color(0x554CAF50), blurRadius: 14, offset: Offset(0, 3)),
                  ]
                : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (selected)
                const Positioned(
                  right: -6,
                  top: -12,
                  child: _SelectionBadge(size: 28),
                ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: Transform.translate(
                    offset: Offset(0, effectiveCenterYOffset),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 0),
                        Expanded(
                          child: Text(
                            leftTitle,
                            style: const TextStyle(
                              color: Color(0xFF334355),
                              fontSize: 26,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w600,
                              height: 1.08,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            rightSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF334355),
                              fontSize: 15,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w600,
                              height: 1.87,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (bottomStruck != null && bottomValue != null)
                Positioned(
                  left: 17,
                  top: (height / 2) + effectiveDiscountOffset,
                  child: SizedBox(
                    width: 240,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: bottomStruck!,
                          style: const TextStyle(
                            color: Color(0x87334355),
                            fontSize: 15,
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            height: 1.87,
                            letterSpacing: 1,
                          ),
                        ),
                        TextSpan(
                          text: bottomValue!,
                          style: const TextStyle(
                            color: Color(0xFF334355),
                            fontSize: 15,
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w600,
                            height: 1.87,
                            letterSpacing: 1,
                          ),
                        ),
                      ]),
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

class _OfferRow extends StatelessWidget {
  final double height;
  final BorderRadius borderRadius;
  final bool outlinedGreen;
  final String leftTitle;
  final String rightSubtitle;

  const _OfferRow({
    required this.height,
    required this.borderRadius,
    required this.leftTitle,
    required this.rightSubtitle,
    required this.outlinedGreen,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = outlinedGreen;
    final double scale = selected ? 1.065 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: SizedBox(
        width: 318,
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: const Color(0xFFFCFCFE),
            shape: RoundedRectangleBorder(
              side: selected ? const BorderSide(width: 6, color: Color(0xFFABC270)) : BorderSide.none,
              borderRadius: borderRadius,
            ),
            shadows: selected
                ? const [
                    BoxShadow(color: Color(0x554CAF50), blurRadius: 14, offset: Offset(0, 3)),
                  ]
                : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (selected)
                const Positioned(
                  right: -6,
                  top: -12,
                  child: _SelectionBadge(),
                ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          leftTitle,
                          style: const TextStyle(
                            color: Color(0xFF334355),
                            fontSize: 26,
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w600,
                            height: 1.08,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          rightSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF334355),
                            fontSize: 15,
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w600,
                            height: 1.87,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
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


