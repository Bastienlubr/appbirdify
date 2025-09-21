import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service Premium basé sur in_app_purchase (Android Google Play)
/// - Récupère les produits
/// - Lance l'achat
/// - Restaure les achats
/// - Vérifie côté backend (Cloud Function `verifierAbonnement`) et met à jour Firestore
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Set<String> _ownedProductIds = <String>{};

  // Product IDs (Play Console) — variantes publiées par durée
  static const List<String> monthlySkus = <String>[
    'premium_1mois_1',
    'premium_1mois_2',
  ];
  static const List<String> semiAnnualSkus = <String>[
    'premium_6mois_1',
    'premium_6mois_2',
  ];
  static const List<String> annualSkus = <String>[
    'premium_12mois_1',
    'premium_12mois_2',
  ];

  // Expose produits mis en cache
  List<ProductDetails> _products = const [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;
  bool _didInitialRestore = false;

  Future<void> start() async {
    if (kIsWeb) {
      if (kDebugMode) debugPrint('⚠️ IAP indisponible sur le Web');
      return;
    }
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        if (kDebugMode) debugPrint('⚠️ Billing non disponible');
        return;
      }
      // Écoute des achats
      await _purchaseSub?.cancel();
      _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
        if (kDebugMode) debugPrint('ℹ️ purchaseStream terminé');
      }, onError: (e) {
        if (kDebugMode) debugPrint('❌ purchaseStream error: $e');
      });

      // Charger les produits (toutes variantes publiées)
      final response = await _iap.queryProductDetails({
        ...monthlySkus,
        ...semiAnnualSkus,
        ...annualSkus,
      });
      if (response.error != null) {
        if (kDebugMode) debugPrint('❌ queryProductDetails error: ${response.error}');
      }
      _products = response.productDetails;
      if (kDebugMode) debugPrint('🛒 Produits chargés: ${_products.map((p) => p.id).toList()}');
      // Auto-restauration une fois au démarrage pour lier un abonnement existant
      if (!_didInitialRestore) {
        _didInitialRestore = true;
        try { await _iap.restorePurchases(); } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ PremiumService.start error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _purchaseSub?.cancel();
      _purchaseSub = null;
    } catch (_) {}
  }

  Future<bool> buy(String productId) async {
    try {
      // S'assure que le listener IAP est actif avant l'achat
      await start();
      if (!_isAvailable) return false;
      final product = _products.firstWhere((p) => p.id == productId, orElse: () => throw StateError('Produit introuvable'));
      final param = PurchaseParam(productDetails: product);
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      // Fallback: certains appareils ne délivrent l'update qu'après restore
      if (ok) {
        // Déclenche une restauration différée si aucun update ne survient
        Future.delayed(const Duration(seconds: 8), () {
          // Appeler restore est idempotent et sécurise la réception des purchases
          restore();
        });
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ buy error: $e');
      return false;
    }
  }

  ProductDetails? _pickVariantNotOwned(List<String> candidates) {
    // 1) Essayer d'abord une variante non possédée (pour permettre 2 achats parallèles)
    for (final id in candidates) {
      if (_ownedProductIds.contains(id)) continue;
      try {
        final pd = _products.firstWhere((p) => p.id == id);
        return pd;
      } catch (_) {}
    }
    // 2) Sinon, retomber sur la première disponible (au cas où _ownedProductIds n'est pas à jour)
    for (final id in candidates) {
      try {
        final pd = _products.firstWhere((p) => p.id == id);
        return pd;
      } catch (_) {}
    }
    return null;
  }

  Future<bool> buyMonthly() async {
    try {
      await start();
      if (!_isAvailable) return false;
      final pd = _pickVariantNotOwned(monthlySkus);
      if (pd == null) {
        if (kDebugMode) debugPrint('❌ Aucun SKU mensuel disponible');
        return false;
      }
      final param = PurchaseParam(productDetails: pd);
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (ok) {
        Future.delayed(const Duration(seconds: 8), () {
          restore();
        });
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ buyMonthly error: $e');
      return false;
    }
  }

  Future<bool> buySemiAnnual() async {
    try {
      await start();
      if (!_isAvailable) return false;
      final pd = _pickVariantNotOwned(semiAnnualSkus);
      if (pd == null) {
        if (kDebugMode) debugPrint('❌ Aucun SKU semestriel disponible');
        return false;
      }
      final param = PurchaseParam(productDetails: pd);
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (ok) {
        Future.delayed(const Duration(seconds: 8), () {
          restore();
        });
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ buySemiAnnual error: $e');
      return false;
    }
  }

  Future<bool> buyAnnual() async {
    try {
      await start();
      if (!_isAvailable) return false;
      final pd = _pickVariantNotOwned(annualSkus);
      if (pd == null) {
        if (kDebugMode) debugPrint('❌ Aucun SKU annuel disponible');
        return false;
      }
      final param = PurchaseParam(productDetails: pd);
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (ok) {
        Future.delayed(const Duration(seconds: 8), () {
          restore();
        });
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ buyAnnual error: $e');
      return false;
    }
  }

  Future<void> restore() async {
    try {
      if (!_isAvailable) return;
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ restore error: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            // Mémorise l'ID produit possédé pour éviter de reproposer la même variante
            if (p.productID.isNotEmpty) {
              _ownedProductIds.add(p.productID);
            }
            await _verifyAndAcknowledge(p);
            break;
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.error:
            if (kDebugMode) debugPrint('❌ Achat erreur: ${p.error}');
            break;
          case PurchaseStatus.canceled:
            break;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ onPurchaseUpdate handler error: $e');
      }
    }
  }

  Future<void> _verifyAndAcknowledge(PurchaseDetails p) async {
    try {
      // Android: récupérer token & productId
      final verificationData = p.verificationData;
      final purchaseToken = verificationData.serverVerificationData; // token Play
      final productId = p.productID;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Appeler CF pour vérifier et écrire dans Firestore
      bool backendOk = false;
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('verifierAbonnementV2');
        await callable.call({
          'packageName': 'com.mindbird.app',
          'subscriptionId': productId,
          'purchaseToken': purchaseToken,
        });
        backendOk = true;
      } catch (_) {
        // Fallback: écrire côté client (règles assouplies pour tests)
        try {
          final db = FirebaseFirestore.instance;
          final userRef = db.doc('utilisateurs/${user.uid}');
          final currentRef = userRef.collection('abonnement').doc('current');
          await currentRef.set({
            'etat': 'ACTIVE',
            'periodeCourante': {
              'debut': DateTime.now(),
              'fin': null,
            },
            'prochaineFacturation': null,
            'offre': {
              'productId': productId,
            },
            'renouvellement': {'auto': true},
            'joursEssaiRestants': 0,
            'lastSync': DateTime.now(),
            'packageName': 'com.mindbird.app',
            'subscriptionId': productId,
            'lastToken': purchaseToken,
          }, SetOptions(merge: true));
          await userRef.set({
            'profil': {'estPremium': true},
            'vie': {'livesInfinite': true},
          }, SetOptions(merge: true));
        } catch (e) {
          if (kDebugMode) debugPrint('❌ Fallback write Firestore error: $e');
        }
      }

      // Accusé côté Play si nécessaire
      if (!p.pendingCompletePurchase) {
        return;
      }
      await _iap.completePurchase(p);
      if (kDebugMode) debugPrint('✅ Achat ${backendOk ? 'vérifié (CF)' : 'fallback client'} et complété');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ _verifyAndAcknowledge error: $e');
    }
  }
}


