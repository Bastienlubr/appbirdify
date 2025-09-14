import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'in_app_purchase_service.dart';
import '../Mission/communs/commun_chargeur_missions.dart';
import '../Mission/communs/commun_strategie_progression.dart';
import '../../models/mission.dart';

/// Service haut niveau pour exposer l'état premium et les actions d'achat
class PremiumService {
  PremiumService._internal();
  static final PremiumService instance = PremiumService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, dynamic>?> abonnement = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<List<ProductDetails>> products = ValueNotifier<List<ProductDetails>>(<ProductDetails>[]);
  List<ProductDetails> _products = [];
  List<ProductDetails> get productsList => List.unmodifiable(_products);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  bool _premiumInitDone = false;

  Future<void> start() async {
    // Init IAP et charger produits
    final available = await InAppPurchaseService.instance.init();
    if (available) {
      final resp = await InAppPurchaseService.instance.queryProducts();
      _products = resp.productDetails;
      products.value = List<ProductDetails>.from(_products);
      // Tenter une restauration silencieuse pour récupérer l'état sur l'appareil
      try { await InAppPurchaseService.instance.restorePurchases(); } catch (_) {}
    }
    // Écouter le profil pour estPremium
    final user = _auth.currentUser;
    if (user != null) {
      _profileSub?.cancel();
      _profileSub = _db.collection('utilisateurs').doc(user.uid).snapshots().listen((doc) async {
        final premium = doc.data()?['profil']?['estPremium'] == true;
        if (kDebugMode) debugPrint('⭐ estPremium=$premium');
        isPremium.value = premium;
        final Map<String, dynamic>? aboMap = (doc.data()?['abonnement'] as Map<String, dynamic>?);
        abonnement.value = aboMap;
        // Synchroniser le mode vies infinies avec l'état premium
        try {
          final Map<String, dynamic>? data = doc.data();
          final bool livesInfiniteRoot = (data?['livesInfinite'] == true) || (data?.containsKey('livesInfinite') == true);
          final bool livesInfiniteNested = (doc.data()?['vie']?['livesInfinite'] == true);
          final bool current = livesInfiniteNested || livesInfiniteRoot;
          if (current != premium) {
            _db.collection('utilisateurs').doc(user.uid).set({
              'vie': {
                'livesInfinite': premium,
              },
              'livesInfinite': FieldValue.delete(),
            }, SetOptions(merge: true));
            if (kDebugMode) debugPrint('♾️ Sync vie.livesInfinite <- estPremium ($premium)');
          } else if (data?.containsKey('livesInfinite') == true) {
            // Valeur déjà alignée: supprimer le champ racine résiduel pour éviter toute recréation visuelle
            _db.collection('utilisateurs').doc(user.uid).set({
              'livesInfinite': FieldValue.delete(),
            }, SetOptions(merge: true));
            if (kDebugMode) debugPrint('🧹 Suppression du champ racine livesInfinite résiduel');
          }
        } catch (_) {}

        // Si passage en premium → initialiser la première mission de chaque biome
        if (premium && !_premiumInitDone) {
          _premiumInitDone = true;
          try {
            if (kDebugMode) debugPrint('🚀 Initialisation des premières missions pour tous les biomes (premium)');
            const List<String> biomes = ['Urbain', 'Forestier', 'Agricole', 'Humide', 'Montagnard', 'Littoral'];
            for (final biome in biomes) {
              List<Mission> missions = await MissionLoaderService.loadMissionsForBiomeWithProgression(user.uid, biome.toLowerCase());
              if (missions.isNotEmpty) {
                await MissionProgressionInitService.initializeBiomeProgress(biome, missions);
              }
            }
            if (kDebugMode) debugPrint('✅ Premières missions initialisées pour tous les biomes');
          } catch (e) {
            if (kDebugMode) debugPrint('❌ Erreur init missions premium: $e');
          }
        }
        if (!premium) {
          _premiumInitDone = false;
        }

        // Resync abonnement autoritatif Play si données manquantes mais token présent
        try {
          if (premium) {
            final String? token = aboMap?['lastToken'] as String?;
            final String? subscriptionId = aboMap?['subscriptionId'] as String? ?? aboMap?['produitId'] as String?;
            final String? packageName = aboMap?['packageName'] as String?;
            final bool hasPeriod = (aboMap?['periodeCourante']?['debut'] != null) && (aboMap?['periodeCourante']?['fin'] != null);
            final bool hasNext = (aboMap?['prochaineFacturation'] != null);
            if (token != null && subscriptionId != null && (!hasPeriod || !hasNext)) {
              if (kDebugMode) debugPrint('🔁 Resync abonnement via Cloud Function (token présent, champs manquants)');
              await _callVerifierAbonnement(uid: user.uid, purchaseToken: token, subscriptionId: subscriptionId, packageName: packageName);
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ Resync abonnement erreur: $e');
        }
      });
    }
  }

  /// Rafraîchit la liste des produits (à appeler après ajout d'un nouveau SKU côté Play)
  Future<void> refreshProducts() async {
    try {
      final resp = await InAppPurchaseService.instance.queryProducts();
      _products = resp.productDetails;
      products.value = List<ProductDetails>.from(_products);
      if (kDebugMode) {
        final ids = _products.map((e) => e.id).toList();
        debugPrint('🧾 Produits rafraîchis: $ids');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ refreshProducts error: $e');
    }
  }

  Future<void> stop() async {
    await _profileSub?.cancel();
    _profileSub = null;
  }

  ProductDetails? get monthlyPlan {
    try {
      return _products.firstWhere((p) => p.id == 'premium_monthly' || p.id == 'premium_mensuel');
    } catch (_) {
      return null;
    }
  }
  ProductDetails? get yearlyPlan {
    try {
      return _products.firstWhere((p) => p.id == 'premium_yearly' || p.id == 'premium_annuel');
    } catch (_) {
      return null;
    }
  }
  ProductDetails? get semiAnnualPlan {
    try {
      return _products.firstWhere((p) =>
        p.id == 'premium_semestriel' ||
        p.id == 'premium_semestrial' ||
        p.id == 'plan-6mois' ||
        p.id == 'prenium_6mois'
      );
    } catch (_) {
      return null;
    }
  }

  // Raw helpers
  double? get monthlyRawPrice => monthlyPlan?.rawPrice;
  String? get monthlyCurrencyCode => monthlyPlan?.currencyCode;

  String formatCurrency(double amount, String? currencyCode) {
    final str = amount.toStringAsFixed(2).replaceAll('.', ',');
    final symbol = _currencySymbol(currencyCode);
    return '$str $symbol';
  }

  // === Labels dynamiques ===
  String? get monthlyPriceLabel => monthlyPlan?.price; // ex: "4,99 €"
  String? get yearlyTotalPriceLabel => yearlyPlan?.price; // ex: "39,99 €"
  String? get yearlyPerMonthLabel {
    final p = yearlyPlan;
    if (p == null) return null;
    try {
      final doublePerMonth = (p.rawPrice) / 12.0;
      // Affichage avec 2 décimales en locale fr
      final str = doublePerMonth.toStringAsFixed(2).replaceAll('.', ',');
      final currency = p.currencyCode; // ex: EUR
      final symbol = _currencySymbol(currency);
      return '$str $symbol / mois';
    } catch (_) {
      return null;
    }
  }

  String? get semiAnnualPerMonthLabel {
    final p = semiAnnualPlan;
    if (p == null) return null;
    try {
      final doublePerMonth = (p.rawPrice) / 6.0;
      final str = doublePerMonth.toStringAsFixed(2).replaceAll('.', ',');
      final symbol = _currencySymbol(p.currencyCode);
      return '$str $symbol / mois';
    } catch (_) {
      return null;
    }
  }

  String? get semiAnnualTotalPriceLabel => semiAnnualPlan?.price;

  String _currencySymbol(String? code) {
    switch (code) {
      case 'EUR':
        return '€';
      case 'USD':
        return ' 24';
      case 'GBP':
        return '£';
      default:
        return code ?? '';
    }
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
      if (kDebugMode) debugPrint('📡 verifierAbonnement (resync) appelé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ verifierAbonnement (resync) échec: $e');
    }
  }

  Future<bool> buyMonthly() async {
    final p = monthlyPlan;
    if (p == null) return false;
    await InAppPurchaseService.instance.buy(p);
    return true;
  }

  Future<bool> buyYearly() async {
    final p = yearlyPlan;
    if (p == null) return false;
    await InAppPurchaseService.instance.buy(p);
    return true;
  }

  Future<bool> buySemiAnnual() async {
    final p = semiAnnualPlan;
    if (p == null) return false;
    await InAppPurchaseService.instance.buy(p);
    return true;
  }

  Future<void> restore() async {
    await InAppPurchaseService.instance.restorePurchases();
  }
}


