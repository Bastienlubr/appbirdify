import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service bas niveau pour gérer Play Billing via in_app_purchase
class InAppPurchaseService {
  InAppPurchaseService._internal();
  static final InAppPurchaseService instance = InAppPurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// IDs des produits définis dans Play Console
  /// À aligner avec la console: ex: com.mindbird.appbirdify.premium_monthly, ...
  static const Set<String> kProductIds = {
    'premium_monthly',
    'premium_yearly',
    // Variantes FR acceptées
    'premium_mensuel',
    'premium_annuel',
    // 6 mois (si créé côté Console)
    'premium_semestriel',
    'premium_semestrial',
    'plan-6mois',
    'prenium_6mois',
  };

  /// Dernier lot de produits récupérés
  ProductDetailsResponse? lastProductsResponse;

  Future<bool> init() async {
    final isAvailable = await _iap.isAvailable();
    if (kDebugMode) debugPrint('🛒 IAP disponible: $isAvailable');
    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchasesUpdated, onError: (e) {
      if (kDebugMode) debugPrint('❌ purchaseStream error: $e');
    });
    return isAvailable;
  }

  Future<ProductDetailsResponse> queryProducts() async {
    final resp = await _iap.queryProductDetails(kProductIds);
    lastProductsResponse = resp;
    if (kDebugMode) debugPrint('🧾 Produits: ${resp.productDetails.map((e) => e.id).toList()} | notFound: ${resp.notFoundIDs}');
    return resp;
  }

  Future<void> buy(ProductDetails product) async {
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ buy() error: $e');
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          if (kDebugMode) debugPrint('⏳ Achat en attente: ${p.productID}');
          break;
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('❌ Achat erreur: ${p.error}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndAcknowledge(p);
          break;
        case PurchaseStatus.canceled:
          if (kDebugMode) debugPrint('🛑 Achat annulé: ${p.productID}');
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<void> _verifyAndAcknowledge(PurchaseDetails p) async {
    try {
      // Ici on pourrait appeler un backend pour valider le reçu. Pour MVP, on marque premium localement.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // Déduire la période d'abonnement depuis le produit et la date d'achat
      final DateTime startDate = _extractPurchaseDate(p) ?? DateTime.now();
      final DateTime periodEnd = _computePeriodEnd(startDate, p.productID);
      final String purchaseToken = p.verificationData.serverVerificationData;
      String? packageName;
      try {
        final info = await PackageInfo.fromPlatform();
        packageName = info.packageName;
      } catch (_) {}

      await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).set({
        'profil': {
          'estPremium': true,
        },
        'vie': {
          'livesInfinite': true,
        },
        // Informations d'abonnement exploitées par l'UI
        'abonnement': {
          'produitId': p.productID,
          'subscriptionId': p.productID,
          if (packageName != null) 'packageName': packageName,
          'lastToken': purchaseToken,
          'periodeCourante': {
            'debut': Timestamp.fromDate(startDate),
            'fin': Timestamp.fromDate(periodEnd),
          },
          'prochaineFacturation': Timestamp.fromDate(periodEnd),
          // Sans backend Play Developer API, on ne peut pas connaître exactement un essai gratuit → 0 par défaut
          'joursEssaiRestants': 0,
        },
        // Nettoyage ancien schéma racine si présent
        'livesInfinite': FieldValue.delete(),
      }, SetOptions(merge: true));

      // Appel backend pour récupérer l'état autoritatif Play (périodes exactes, essai, état, etc.)
      await _callVerifierAbonnement(
        uid: user.uid,
        packageName: packageName,
        subscriptionId: p.productID,
        purchaseToken: purchaseToken,
      );
      if (kDebugMode) debugPrint('✅ Premium activé pour ${user.uid} par ${p.productID}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur _verifyAndAcknowledge: $e');
    }
  }

  DateTime? _extractPurchaseDate(PurchaseDetails p) {
    try {
      if (p.transactionDate != null) {
        final int? ms = int.tryParse(p.transactionDate!);
        if (ms != null) {
          return DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
    } catch (_) {}
    return null;
  }

  DateTime _computePeriodEnd(DateTime start, String productId) {
    final String id = productId.toLowerCase();
    int monthsToAdd = 1; // défaut = mensuel
    if (id.contains('year') || id.contains('annuel') || id.contains('yearly')) {
      monthsToAdd = 12;
    } else if (id.contains('6mois') || id.contains('semestr')) {
      monthsToAdd = 6;
    } else if (id.contains('month') || id.contains('mensuel') || id.contains('monthly')) {
      monthsToAdd = 1;
    }
    return _addMonthsClamped(start, monthsToAdd);
  }

  DateTime _addMonthsClamped(DateTime date, int months) {
    final int newYear = date.year + ((date.month - 1 + months) ~/ 12);
    final int newMonth = ((date.month - 1 + months) % 12) + 1;
    final int day = date.day;
    final int lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final int clampedDay = day > lastDayOfNewMonth ? lastDayOfNewMonth : day;
    return DateTime(newYear, newMonth, clampedDay, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
  }

  Future<void> _callVerifierAbonnement({
    required String uid,
    required String purchaseToken,
    required String subscriptionId,
    String? packageName,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await functions.httpsCallable('verifierAbonnement').call({
        'uid': uid,
        'packageName': packageName,
        'subscriptionId': subscriptionId,
        'purchaseToken': purchaseToken,
      });
      if (kDebugMode) debugPrint('🔁 verifierAbonnement appelé pour $uid');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ verifierAbonnement error: $e');
    }
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }
}


