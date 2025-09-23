import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
        // Plus de fallback client: la vérification doit passer par la CF pour lier le token à l'UID
        if (kDebugMode) debugPrint('❌ Vérification backend requise pour activer l\'abonnement');
      }

      // Ecrire/mettre à jour un encart local d'information (fallback UI)
      try {
        await _writeLocalEncart(p, productId);
      } catch (_) {}

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

  Future<void> _writeLocalEncart(PurchaseDetails p, String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Détails Android (commande/heure)
    DateTime now = DateTime.now();
    DateTime? purchaseTime;
    if (p is GooglePlayPurchaseDetails) {
      final w = p.billingClientPurchase;
      if (w.purchaseTime != null) {
        purchaseTime = DateTime.fromMillisecondsSinceEpoch(w.purchaseTime!);
      }
    }
    if (purchaseTime == null && p.transactionDate != null) {
      try { purchaseTime = DateTime.fromMillisecondsSinceEpoch(int.parse(p.transactionDate!)); } catch (_) {}
    }
    purchaseTime ??= now;

    // Récupérer le produit pour prix/périodes
    String? freeTrialIso;
    String? billIso;
    String? priceDisplay;
    final pd = _products.cast<ProductDetails?>().firstWhere((e) => e?.id == productId, orElse: () => null);
    // Estimations génériques si les détails de plate-forme ne sont pas exposés
    if (pd != null) {
      // Prix
      try {
        priceDisplay = pd.price; // déjà formaté (ex: "4,99 €")
      } catch (_) {}
      // Période facturation à partir de l'ID produit
      final id = pd.id.toLowerCase();
      if (id.contains('12')) billIso = 'P1Y';
      else if (id.contains('6')) billIso = 'P6M';
      else billIso = 'P1M';
      // Essai: 3 jours par défaut si présent dans l'offre
      freeTrialIso = 'P3D';
    }

    final finEssai = (freeTrialIso != null && freeTrialIso.isNotEmpty)
        ? _addIsoPeriodDt(purchaseTime, freeTrialIso)
        : null;
    final debutFacturation = finEssai ?? purchaseTime;
    final prochaine = (debutFacturation != null && (billIso != null))
        ? _addIsoPeriodDt(debutFacturation, billIso!)
        : null;

    // Libellé plan + prix
    String planLabel = 'Abonnement 1 mois';
    if (billIso == 'P6M') planLabel = 'Abonnement 6 mois';
    if (billIso == 'P1Y') planLabel = 'Abonnement 12 mois';
    final prixAffiche = priceDisplay != null
        ? (billIso == 'P1Y'
            ? '$priceDisplay / 12 mois'
            : billIso == 'P6M'
                ? '$priceDisplay / 6 mois'
                : '$priceDisplay / mois')
        : null;

    final encart = <String, dynamic>{
      'produitId': productId,
      'plan': planLabel,
      if (prixAffiche != null) 'prixAffiche': prixAffiche,
      if (finEssai != null)
        'essai': {
          'debut': purchaseTime,
          'fin': finEssai,
        },
      if (debutFacturation != null) 'debutFacturation': debutFacturation,
      if (prochaine != null) 'prochaineFacturation': prochaine,
      'renouvellementAutomatique': true,
    };

    final db = FirebaseFirestore.instance;
    await db
        .collection('utilisateurs')
        .doc(user.uid)
        .collection('abonnement')
        .doc('encart')
        .set(encart, SetOptions(merge: true));
  }

  DateTime _addIsoPeriodDt(DateTime start, String iso) {
    final reg = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$', caseSensitive: false);
    final m = reg.firstMatch(iso);
    if (m == null) return start;
    final years = int.tryParse(m.group(1) ?? '0') ?? 0;
    final months = int.tryParse(m.group(2) ?? '0') ?? 0;
    final weeks = int.tryParse(m.group(3) ?? '0') ?? 0;
    final days = int.tryParse(m.group(4) ?? '0') ?? 0;
    final base = DateTime(start.year + years, start.month + months, start.day, start.hour, start.minute, start.second);
    return base.add(Duration(days: weeks * 7 + days));
  }
}


