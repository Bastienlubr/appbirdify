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

          // Statut (Premium + libellé plan) — centré
          Positioned(
            left: 0,
            top: 151,
            child: SizedBox(
              width: 375,
              child: const Center(
                child: Text(
                  'Aucun abonnement actif',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF334355),
                    fontSize: 20,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Carte d'information avec contenu inclus (aligné à l'intérieur) - lit abonnement/current
          Positioned(
            left: 36,
            top: 192,
            child: _CurrentSubscriptionCard(),
          ),

          // Bouton Gérer sur Google Play (ouverture directe)
          Positioned(
            left: 49.09,
            top: 318.45,
            child: SizedBox(
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
                      pkg = (data?['packageName'] as String?) ?? pkg;
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
          ),

          // Bouton Restaurer mes achats
          Positioned(
            left: 49.09,
            top: 265.0,
            child: SizedBox(
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
          ),

          // Bouton Actualiser l'état de l'abonnement (relance restore pour forcer un event)
          Positioned(
            left: 49.09,
            top: 418.0,
            child: SizedBox(
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
                    'Actualiser l\'état de l\'abonnement',
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
          ),

          // Bouton DEV: Forcer synchro (token) — neutralisé
          Positioned(
            left: 49.09,
            top: 465.0,
            child: SizedBox(
              width: 274.82,
              height: 40.73,
              child: BoutonUniversel(
                onPressed: () async {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonction dev désactivée')),
                    );
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
                    'Forcer synchro (token)',
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
          ),

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

class _CurrentSubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
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
        final int trialDaysLeft = (abo?['joursEssaiRestants'] as int?) ?? 0;
        final DateTime? nextBilling = (abo?['prochaineFacturation'] is Timestamp)
            ? (abo?['prochaineFacturation'] as Timestamp).toDate()
            : (abo?['prochaineFacturation'] as DateTime?);
        final DateTime? periodeDebut = (abo?['periodeCourante']?['debut'] is Timestamp)
            ? (abo?['periodeCourante']?['debut'] as Timestamp).toDate()
            : (abo?['periodeCourante']?['debut'] as DateTime?);
        final DateTime? periodeFin = (abo?['periodeCourante']?['fin'] is Timestamp)
            ? (abo?['periodeCourante']?['fin'] as Timestamp).toDate()
            : (abo?['periodeCourante']?['fin'] as DateTime?);

        final String line1 = (periodeDebut != null && periodeFin != null)
            ? 'Période en cours: du ${_formatDateFr(periodeDebut)} au ${_formatDateFr(periodeFin)}'
            : '';
        final String line2 = (nextBilling != null)
            ? 'Prochaine facturation: ${_formatDateFr(nextBilling)}'
            : (line1.isEmpty ? 'Abonnement en cours' : '');
        final String? trialText = trialDaysLeft > 0
            ? 'Essai gratuit ($trialDaysLeft jour${trialDaysLeft > 1 ? 's' : ''} restant${trialDaysLeft > 1 ? 's' : ''})'
            : null;

        return Container(
          width: 303,
          decoration: ShapeDecoration(
            color: const Color(0xFFFCFCFE),
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 3, color: Color(0xFFDADADA)),
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
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trialText != null)
                  Text(
                    trialText,
                    style: const TextStyle(
                      color: Color(0xFF334355),
                      fontSize: 15,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (line1.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      line1,
                      style: const TextStyle(
                        color: Color(0x8C334355),
                        fontSize: 15,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (line2.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line2,
                      style: const TextStyle(
                        color: Color(0x8C334355),
                        fontSize: 15,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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


