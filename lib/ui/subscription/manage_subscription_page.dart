import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ManageSubscriptionPage extends StatelessWidget {
  const ManageSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Non connecté')));
    final currentRef = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(uid)
        .collection('abonnement')
        .doc('current');
    final encartRef = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(uid)
        .collection('abonnement')
        .doc('encart');
    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: currentRef.snapshots(),
        builder: (context, snap) {
          final current = snap.data?.data();
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: encartRef.get(),
            builder: (context, encart) {
              final enc = encart.data?.data();
              final plan = enc?['plan']?.toString() ?? '';
              final prochaine = _toDate(enc?['prochaineFacturation']);
              final auto = enc?['renouvellementAutomatique'] == true;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.isNotEmpty ? plan : 'Abonnement'),
                    const SizedBox(height: 8),
                    if (prochaine != null) Text('Prochaine facturation: ${prochaine.toLocal()}'),
                    Text(auto ? 'Renouvellement automatique: activé' : 'Renouvellement automatique: désactivé'),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final data = current ?? {};
                            final String? sku = (data['subscriptionId'] as String?) ?? (data['offre']?['productId'] as String?);
                            final String pkg = (data['packageName'] as String?) ?? 'com.mindbird.app';
                            final Uri url = (sku != null && sku.isNotEmpty)
                                ? Uri.parse('https://play.google.com/store/account/subscriptions?sku=$sku&package=$pkg')
                                : Uri.parse('https://play.google.com/store/account/subscriptions');
                            // ignore: use_build_context_synchronously
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir Google Play')));
                            }
                          } catch (e) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ouverture impossible: $e')));
                          }
                        },
                        child: const Text('Gérer sur Google Play'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}


