import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool isAvailable = false;
  List<ProductDetails> products = const [];
  final Set<String> _ownedProductIds = <String>{};
  IAPError? lastQueryError;

  static const List<String> sku1M = <String>['premium_1mois_1', 'premium_1mois_2'];
  static const List<String> sku6M = <String>['premium_6mois_1', 'premium_6mois_2'];
  static const List<String> sku12M = <String>['premium_12mois_1', 'premium_12mois_2'];

  Future<void> init() async {
    if (kIsWeb) {
      if (kDebugMode) debugPrint('⚠️ IAP indisponible sur Web');
      return;
    }
    try {
      isAvailable = await _iap.isAvailable();
      if (!isAvailable) return;

      await _sub?.cancel();
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (e) {
        if (kDebugMode) debugPrint('❌ purchaseStream error: $e');
      });

      final response = await _iap.queryProductDetails({
        ...sku1M,
        ...sku6M,
        ...sku12M,
      });
      products = response.productDetails;
      lastQueryError = response.error;
      if (kDebugMode) debugPrint('🛒 Produits: ${products.map((e) => e.id).toList()}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ IapService.init error: $e');
    }
  }

  ProductDetails? pickVariantFirstNotOwned(List<String> variants) {
    for (final id in variants) {
      final p = _findProduct(id);
      if (p != null && !_ownedProductIds.contains(id)) return p;
    }
    for (final id in variants) {
      final p = _findProduct(id);
      if (p != null) return p;
    }
    return null;
  }

  ProductDetails? _findProduct(String id) {
    try { return products.firstWhere((p) => p.id == id); } catch (_) { return null; }
  }

  Future<bool> buy(ProductDetails product) async {
    try {
      // Phase 1 — validation de paiement (avant validation bancaire): aucun accès
      await _writeValidationPhaseFirestore(product.id);

      PurchaseParam param = PurchaseParam(productDetails: product);
      // Android: fournir offerToken si disponible (subscriptions v2)
      try {
        if (product is GooglePlayProductDetails) {
          final dynamic gpd = product;
          dynamic offers = _tryGetList(() => (gpd as dynamic).subscriptionOfferDetails);
          offers ??= _tryGetList(() => (gpd as dynamic).billingClientProductDetails?.subscriptionOfferDetails);
          if (offers is List && offers.isNotEmpty) {
            dynamic selected = offers.first;
            try { selected = (offers).firstWhere((o) => _hasPricingPhases(o), orElse: () => offers.first); } catch (_) {}
            final String? offerToken = _tryGetString(() => selected?.offerToken);
            if (offerToken != null && offerToken.isNotEmpty) {
              param = GooglePlayPurchaseParam(productDetails: product, offerToken: offerToken);
            }
          }
        }
      } catch (_) {}
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ buy error: $e');
      return false;
    }
  }

  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      // Ignorer discrètement les erreurs de restauration (pas bloquant)
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        switch (p.status) {
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (p.productID.isNotEmpty) _ownedProductIds.add(p.productID);
            // Phase 2 — en_attente (après confirmation Play / validation banque en cours): accès provisoire
            await _writePendingAccessGranted(p.productID, p.verificationData.serverVerificationData);
            await _verifyServer(p);
            if (p.pendingCompletePurchase) {
              try { await _iap.completePurchase(p); } catch (_) {}
            }
            break;
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            break;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ onPurchase error: $e');
      }
    }
  }

  Future<void> _verifyServer(PurchaseDetails p) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('verifierAbonnement');
      final res = await callable.call({
        'packageName': 'com.mindbird.app',
        'subscriptionId': p.productID,
        'purchaseToken': p.verificationData.serverVerificationData,
      });
      // Si le serveur renvoie un état coupant l'accès, révoquer immédiatement côté client
      try {
        final data = (res.data is Map) ? (res.data as Map) : null;
        final state = data != null ? data['state']?.toString() : null;
        if (state == 'SUSPENDED' || state == 'EXPIRED') {
          final db = FirebaseFirestore.instance;
          await db.doc('utilisateurs/${user.uid}').set({
            'profil': {'estPremium': false},
            'vie': {'livesInfinite': false},
          }, SetOptions(merge: true));
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('❌ verifyServer error: $e');
    }
  }

  Future<void> dispose() async { try { await _sub?.cancel(); } catch (_) {} }

  List<dynamic>? _tryGetList(List<dynamic>? Function() getter) {
    try { final v = getter(); if (v is List) return v; } catch (_) {}
    return null;
  }
  String? _tryGetString(String? Function() getter) {
    try { final v = getter(); if (v is String) return v; } catch (_) {}
    return null;
  }
  bool _hasPricingPhases(dynamic offer) {
    try {
      final phases = offer?.pricingPhases?.pricingPhaseList;
      return phases is List && phases.isNotEmpty;
    } catch (_) { return false; }
  }

  Future<void> _writeValidationPhaseFirestore(String productId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final String plan = productId.startsWith('premium_12mois')
          ? 'Abonnement 12 mois'
          : productId.startsWith('premium_6mois')
              ? 'Abonnement 6 mois'
              : 'Abonnement 1 mois';
      final String variant = productId.endsWith('_2') ? '2' : '1';

      final currentRef = db.doc('utilisateurs/${user.uid}/abonnement/current');
      final encartRef = db.doc('utilisateurs/${user.uid}/abonnement/encart');

      await currentRef.set({
        'etat': 'PENDING',
        'phase': 'validation_paiement',
        'periodeCourante': {
          'debut': now,
          'fin': null,
        },
        'prochaineFacturation': null,
        'offre': {
          'productId': productId,
          'variantId': variant,
        },
        'renouvellement': {'auto': true},
        'packageName': 'com.mindbird.app',
        'subscriptionId': productId,
        'lastToken': null,
        'lastSync': now,
        'accesAutorise': false,
        'dateEtat': now,
      }, SetOptions(merge: true));

      await encartRef.set({
        'plan': plan,
        'prochaineFacturation': null,
        'renouvellementAutomatique': true,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ _writeValidationPhaseFirestore error: $e');
    }
  }

  Future<void> _writePendingAccessGranted(String productId, String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final encartTrialEnd = now.add(const Duration(days: 3));
      final currentRef = db.doc('utilisateurs/${user.uid}/abonnement/current');
      final encartRef = db.doc('utilisateurs/${user.uid}/abonnement/encart');

      await currentRef.set({
        'etat': 'PENDING',
        'phase': 'en_attente',
        'accesAutorise': true,
        'dateEtat': now,
        'lastToken': token,
      }, SetOptions(merge: true));

      await encartRef.set({
        'essai': {
          'debut': now,
          'fin': encartTrialEnd,
          'actif': true,
        },
        'debutFacturation': encartTrialEnd,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await db.doc('utilisateurs/${user.uid}').set({
        'profil': {'estPremium': true},
        'vie': {'livesInfinite': true},
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ _writePendingAccessGranted error: $e');
    }
  }
}


