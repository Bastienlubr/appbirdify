import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/boutons/bouton_universel.dart';
// import supprimé: premium_service
import 'package:url_launcher/url_launcher.dart';
import '../../services/premium_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// premium_service supprimé

class GererMonAbonnementPage extends StatelessWidget {
  const GererMonAbonnementPage({
    super.key,
    this.headerLeftMargin = 26,
    this.headerIconSize = 36,
    this.headerRightSpacer = 62,
    this.titleHorizontalOffset = 4,
    this.headerTop = 52,
  });

  final double headerLeftMargin; // marge gauche avant la flèche
  final double headerIconSize; // taille de l'icône/flèche
  final double headerRightSpacer; // espace à droite pour centrage optique
  final double titleHorizontalOffset; // micro-ajustement horizontal du texte
  final double headerTop; // position verticale du header

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
              color: Color(0xFFF2F5F8),
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
                      headerLeftMargin: headerLeftMargin,
                      headerIconSize: headerIconSize,
                      headerRightSpacer: headerRightSpacer,
                      titleHorizontalOffset: titleHorizontalOffset,
                      headerTop: headerTop,
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

  double _computeScale(double w, double h) {
    if (w <= 0 || h <= 0) return 1.0;
    final sx = w / _baseW;
    final sy = h / _baseH;
    return sx < sy ? sx : sy;
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.headerLeftMargin,
    required this.headerIconSize,
    required this.headerRightSpacer,
    required this.titleHorizontalOffset,
    required this.headerTop,
  });

  final double headerLeftMargin;
  final double headerIconSize;
  final double headerRightSpacer;
  final double titleHorizontalOffset;
  final double headerTop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: Stack(
        children: [
          // Restauration auto à l’ouverture (une fois)
          // Restauration automatique supprimée pour éviter les changements visuels à l'ouverture
          // En-tête: flèche gauche + titre centré optiquement (placeholder symétrique à droite)
          Positioned(
            left: 0,
            top: headerTop,
            child: SizedBox(
              width: 375,
              height: 36,
              child: Row(
                children: [
                  SizedBox(width: headerLeftMargin),
                  SizedBox(
                    width: headerIconSize,
                    height: headerIconSize,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(
                        'assets/Images/Bouton/flechegauchecercle.svg',
                        width: headerIconSize,
                        height: headerIconSize,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(Color(0xFF334355), BlendMode.srcIn),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(titleHorizontalOffset, 0),
                        child: const Text(
                          'Gérer mon abonnement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF334355),
                            fontSize: 20,
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: headerRightSpacer),
                ],
              ),
            ),
          ),

          // Statut dynamique (essai/actif)
          Positioned(
            left: 0,
            top: 151,
            child: const _StatusHeader(),
          ),

          // Zone de contenu (cartes + boutons) scrollable au besoin
          Positioned(
            left: 0,
            right: 0,
            top: 192,
            bottom: 20,
            child: const _ContentArea(),
          ),

          // (Boutons déplacés en bas de _ContentArea)

          // Bouton Résilier mon compte — supprimé

          // Historique simple (3 derniers cycles) — lit abonnement/historique/cycles
          Positioned(
            left: 36,
            top: 472,
            child: _HistoryCyclesList(),
          ),

          // (Supprimé) Home indicator
        ],
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 0),
            // Cartes
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 36),
              child: _CurrentSubscriptionCard(),
            ),
            const SizedBox(height: 20),
            // Historique
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 36),
              child: _HistoryCyclesList(),
            ),
            const SizedBox(height: 20),
            // Boutons bas de page
            const _BottomButtons(),
          ],
        );
        // Active le scroll si le contenu dépasse
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

class _BottomButtons extends StatelessWidget {
  const _BottomButtons();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 49.09),
      child: Column(
        children: [
          SizedBox(
            width: 274.82,
            height: 40.73,
            child: BoutonUniversel(
              onPressed: () async { try { await PremiumService.instance.restore(); } catch (_) {} },
              size: BoutonUniverselTaille.small,
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: const Color(0xFFFCFCFE),
              hoverBackgroundColor: const Color(0xFFEDEDED),
              borderColor: const Color(0xFFDADADA),
              hoverBorderColor: const Color(0xFFDADADA),
              shadowColor: const Color(0xFFDADADA),
              child: const Center(
                child: Text(
                  'Restaurer mes achats',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF334355),
                    fontSize: 16,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 274.82,
            height: 40.73,
            child: BoutonUniversel(
              onPressed: () async {
                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  String? sku;
                  String pkg = 'com.mindbird.app';
                  if (uid != null) {
                    final doc = await FirebaseFirestore.instance
                        .collection('utilisateurs')
                        .doc(uid)
                        .collection('abonnement')
                        .doc('current')
                        .get();
                    final data = doc.data();
                    sku = data?['subscriptionId'] as String?
                        ?? data?['offre']?['productId'] as String?;
                    pkg = (data?['packageName'] as String?)
                        ?? (data?['facturation']?['packageName'] as String?)
                        ?? pkg;
                  }
                  final Uri url = (sku != null && sku.isNotEmpty)
                      ? Uri.parse('https://play.google.com/store/account/subscriptions?sku=$sku&package=$pkg')
                      : Uri.parse('https://play.google.com/store/account/subscriptions');
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impossible d\'ouvrir Google Play')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ouverture impossible: $e')),
                    );
                  }
                }
              },
              size: BoutonUniverselTaille.small,
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: const Color(0xFFFCFCFE),
              hoverBackgroundColor: const Color(0xFFEDEDED),
              borderColor: const Color(0xFFDADADA),
              hoverBorderColor: const Color(0xFFDADADA),
              shadowColor: const Color(0xFFDADADA),
              child: const Center(
                child: Text(
                  'Gérer sur Google Play',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF334355),
                    fontSize: 16,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                    height: 1.0,
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

class _CurrentSubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    // Si le compte n'est pas premium, n'affiche pas des infos d'un abonnement potentiellement lié à un autre compte Play
    if (!UserOrchestra.isPremium) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E6ED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aucun abonnement actif pour ce compte',
              style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF344356)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Restaurer les achats (si l'appareil est connecté au bon compte Play)
                    // ignore: discarded_futures
                    PremiumService.instance.restore();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restauration des achats lancée')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A994E), foregroundColor: Colors.white),
                  child: const Text('Restaurer mes achats'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/abonnement/choix-offre'),
                  child: const Text('Voir les offres'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final stream = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(uid)
        .collection('abonnement')
        .doc('current')
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final abo = snap.data?.data();
        final DateTime? nextBilling = _toDate(abo?['prochaineFacturation']);
        final DateTime? periodeDebut = _toDate(abo?['periodeCourante']?['debut']);
        final DateTime? periodeFin = _toDate(abo?['periodeCourante']?['fin']);
        final Map<String, dynamic>? essai = abo?['essai'] as Map<String, dynamic>?;
        final Map<String, dynamic>? payant = abo?['payant'] as Map<String, dynamic>?;
        final Map<String, dynamic>? prix = abo?['prix'] as Map<String, dynamic>?;
        final String? productId = (abo?['offre']?['productId'] as String?) ?? abo?['subscriptionId'] as String?;
        final String planLabel = _resolvePlanLabelFromAbo(abo);
        final bool autoRenew = abo?['renouvellement']?['auto'] == true;

        final int trialDaysLeft = (essai?['joursRestants'] as int?) ?? 0;
        final bool trialActif = essai?['actif'] == true;
        final DateTime? trialDebut = _toDate(essai?['debut']);
        final DateTime? trialFin = _toDate(essai?['fin']);
        final DateTime? payantDebut = _toDate(payant?['debut']);

        // Calcul local de première/prochaine facturation si absent
        final String? dureeIso = (payant?['dureeDeclarative'] as String?) ?? (essai?['dureeDeclarative'] as String?);
        final DateTime? premiereFacturation = (trialFin != null)
            ? trialFin
            : (payantDebut != null && dureeIso != null ? _addIsoPeriod(payantDebut, dureeIso) : null);
        final DateTime? prochaineFacturation = nextBilling ??
            ((periodeFin != null) ? periodeFin : (periodeDebut != null && dureeIso != null ? _addIsoPeriod(periodeDebut, dureeIso) : null));

        // Fallback d’encart local pour affichage UX même si CF/Play indispo
        final encartSnapFuture = FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(uid)
            .collection('abonnement')
            .doc('encart')
            .get();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: encartSnapFuture,
          builder: (context, encartSnap) {
            final encart = encartSnap.data?.data();
            final String? prixAffiche = encart?['prixAffiche'] as String?;
            final DateTime? essaiDebut = _toDate(encart?['essai']?['debut']);
            final DateTime? essaiFin = _toDate(encart?['essai']?['fin']);
            final DateTime? debutFacturation = _toDate(encart?['debutFacturation']);
            final DateTime? prochaineFacturationLocal = _toDate(encart?['prochaineFacturation']);
            final String? planLocal = encart?['plan'] as String?;

            String prixLigne = '';
            if (!trialActif) {
              if (prix != null && prix['montant'] != null && prix['devise'] != null) {
                final num montant = (prix['montant'] is num) ? prix['montant'] as num : num.tryParse('${prix['montant']}') ?? 0;
                if (montant > 0) {
                  prixLigne = 'Prix: ${_formatMontant(montant)} ${prix['devise']}${_formatPeriodePrix(payant?['dureeDeclarative'])}';
                }
              } else if (_isDisplayablePrice(prixAffiche)) {
                prixLigne = 'Prix: $prixAffiche';
              }
            }

            final DateTime? prochaineAff = prochaineFacturation ?? prochaineFacturationLocal;
            final DateTime? finEssaiAff = trialFin ?? essaiFin;
            final DateTime? essaiDebutAff = trialDebut ?? essaiDebut;

            return SizedBox(
              width: 303,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (essaiDebutAff != null && finEssaiAff != null)
                    _InfoCard(
                      title: 'Essai gratuit',
                      lines: [
                        'Du ${_formatDateFr(essaiDebutAff)} au ${_formatDateFr(finEssaiAff)}',
                        if (trialActif) 'Reste: J-${trialDaysLeft.clamp(0, 999)}',
                        'Aucun débit avant le ${_formatDateFr(finEssaiAff)}',
                      ],
                    ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    title: planLabel.isNotEmpty ? planLabel : ((planLocal ?? '').isNotEmpty ? (planLocal ?? '') : 'Abonnement payant'),
                    lines: [
                      if (debutFacturation != null) 'Début: ${_formatDateFr(debutFacturation)}'
                      else if (payantDebut != null) 'Début: ${_formatDateFr(payantDebut)}',
                      if (periodeDebut != null && periodeFin != null)
                        'Période en cours: ${_formatDateFr(periodeDebut)} → ${_formatDateFr(periodeFin)}',
                      if (premiereFacturation != null)
                        'Première facturation le: ${_formatDateFr(premiereFacturation)}',
                      if (autoRenew && (prochaineAff != null))
                        'Prochaine facturation: ${_formatDateFr(prochaineAff)}'
                      else if (!autoRenew && (periodeFin != null))
                        'Prendra fin le: ${_formatDateFr(periodeFin)}',
                      if (prixLigne.isNotEmpty) prixLigne,
                      'Annulable à tout moment via Google Play',
                    ],
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

class _HistoryCyclesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final stream = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(uid)
        .collection('abonnement')
        .doc('historique')
        .collection('cycles')
        .orderBy('periodeCourante.debut', descending: true)
        .limit(3)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final items = snap.data!.docs;
        return Container(
          width: 303,
          decoration: ShapeDecoration(
            color: const Color(0xFFFCFCFE),
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 2, color: Color(0xFFDADADA)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique',
                style: TextStyle(
                  color: Color(0xFF334355),
                  fontSize: 16,
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ...items.map((d) {
                final m = d.data();
                final DateTime? debut = (m['periodeCourante']?['debut'] is Timestamp)
                    ? (m['periodeCourante']?['debut'] as Timestamp).toDate()
                    : (m['periodeCourante']?['debut'] as DateTime?);
                final DateTime? fin = (m['periodeCourante']?['fin'] is Timestamp)
                    ? (m['periodeCourante']?['fin'] as Timestamp).toDate()
                    : (m['periodeCourante']?['fin'] as DateTime?);
                final String range = (debut != null && fin != null)
                    ? '${_formatDateFr(debut)} → ${_formatDateFr(fin)}'
                    : 'Période inconnue';
                final String etat = (m['etat'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          range,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0x8C334355),
                            fontSize: 14,
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        etat,
                        style: const TextStyle(
                          color: Color(0x8C334355),
                          fontSize: 13,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

String _formatDateFr(DateTime date) {
  // Format très simple JJ mois AAAA (sans dépendance intl)
  const mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  final d = date.day;
  final m = mois[date.month - 1];
  final y = date.year;
  return '$d $m $y';
}

String _resolvePlanLabel(Map<String, dynamic>? abo) {
  if (abo == null) return '';
  final String? productId = abo['produitId'] as String?;
  final String? basePlanId = abo['offre'] is Map<String, dynamic>
      ? (abo['offre'] as Map<String, dynamic>)['basePlanId'] as String?
      : null;
  final String id = (basePlanId ?? productId ?? '').toLowerCase();
  if (id.isEmpty) return '';
  if (id.contains('year') || id.contains('annuel') || id.contains('yearly') || id.contains('12')) {
    return '12 mois';
  }
  if (id.contains('6') || id.contains('semestr')) {
    return '6 mois';
  }
  if (id.contains('month') || id.contains('mensuel') || id.contains('monthly') || id.contains('1')) {
    return '1 mois';
  }
  return '';
}

String _resolvePlanLabelFromAbo(Map<String, dynamic>? abo) {
  if (abo == null) return '';
  final String? productId = abo['offre']?['productId'] as String? ?? abo['subscriptionId'] as String?;
  if (productId == null) return '';
  final id = productId.toLowerCase();
  if (id.contains('12') || id.contains('an') || id.contains('annuel') || id.contains('year')) return 'Premium 12 mois';
  if (id.contains('6') || id.contains('sem') || id.contains('six')) return 'Premium 6 mois';
  if (id.contains('1') || id.contains('mois') || id.contains('month')) return 'Premium 1 mois';
  return 'Abonnement payant';
}

String _formatMontant(dynamic m) {
  try {
    final num val = (m is num) ? m : num.parse(m.toString());
    return val.toStringAsFixed(val == val.roundToDouble() ? 0 : 2);
  } catch (_) {
    return m?.toString() ?? '';
  }
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  return null;
}

DateTime? _toDateFromMillis(dynamic v) {
  if (v == null) return null;
  try {
    final ms = (v is int) ? v : int.parse(v.toString());
    return DateTime.fromMillisecondsSinceEpoch(ms);
  } catch (_) {
    return null;
  }
}

String _formatPeriodePrix(dynamic billingPeriodIso) {
  // Affiche "/ mois", "/ 6 mois", "/ 12 mois" selon la durée déclarative ISO 8601 (ex: P1M, P6M, P1Y)
  final s = billingPeriodIso?.toString() ?? '';
  if (s.isEmpty) return '';
  if (s == 'P1M') return ' / mois';
  if (s == 'P6M') return ' / 6 mois';
  if (s == 'P1Y') return ' / 12 mois';
  // fallback simple
  return '';
}

DateTime? _addIsoPeriod(DateTime start, String period) {
  final reg = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$', caseSensitive: false);
  final m = reg.firstMatch(period);
  if (m == null) return null;
  final years = int.tryParse(m.group(1) ?? '0') ?? 0;
  final months = int.tryParse(m.group(2) ?? '0') ?? 0;
  final weeks = int.tryParse(m.group(3) ?? '0') ?? 0;
  final days = int.tryParse(m.group(4) ?? '0') ?? 0;
  final d = DateTime(start.year, start.month, start.day, start.hour, start.minute, start.second);
  final withYM = DateTime(d.year + years, d.month + months, d.day, d.hour, d.minute, d.second);
  return withYM.add(Duration(days: days + weeks * 7));
}

bool _isDisplayablePrice(String? price) {
  if (price == null) return false;
  final s = price.toLowerCase().trim();
  if (s.isEmpty) return false;
  // Masque les affichages "gratuit" ou 0 €
  if (s.contains('gratuit') || s == '0' || s.startsWith('0 ')) return false;
  return true;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 303,
      decoration: ShapeDecoration(
        color: const Color(0xFFFCFCFE),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: Color(0xFFDADADA)),
          borderRadius: BorderRadius.circular(10),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x153C7FD0),
            blurRadius: 19,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF334355),
              fontSize: 16,
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...lines.where((l) => l.isNotEmpty).map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  l,
                  style: const TextStyle(
                    color: Color(0x8C334355),
                    fontSize: 15,
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return SizedBox(
        width: 375,
        child: const Center(child: Text('Non connecté', style: TextStyle(color: Color(0xFF334355), fontSize: 20, fontFamily: 'Fredoka', fontWeight: FontWeight.w600))),
      );
    }
    final stream = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(uid)
        .collection('abonnement')
        .doc('current')
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final abo = snap.data?.data();
        // Fallback: lire encart si current incomplet
        // Note: on ne fait pas de stream combiné pour rester léger
        final Map<String, dynamic>? essai = abo?['essai'] as Map<String, dynamic>?;
        final bool trialActif = essai?['actif'] == true;
        final bool hasAbo = abo != null;
        final String text = !hasAbo
            ? 'Aucun abonnement'
            : (trialActif ? 'Essai gratuit en cours' : 'Abonnement actif');
        return SizedBox(
          width: 375,
          child: Center(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF334355),
                fontSize: 20,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RestoreOnOpenOnce extends StatefulWidget {
  @override
  State<_RestoreOnOpenOnce> createState() => _RestoreOnOpenOnceState();
}

class _RestoreOnOpenOnceState extends State<_RestoreOnOpenOnce> {
  bool _did = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_did) return;
    _did = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try { await PremiumService.instance.restore(); } catch (_) {}
    });
  }
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}


