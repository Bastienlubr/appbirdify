import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
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
  final Set<String> _ownedProductIds = <String>{};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _aboSub;
  bool _premiumInitDone = false;
  String? _packageName;
  static const MethodChannel _billingChannel = MethodChannel('com.mindbird.billing');

  Future<void> start() async {
    // Init IAP et charger produits
    final available = await InAppPurchase.instance.isAvailable();
    // Récupérer dynamiquement le packageName (Android)
    try {
      final info = await PackageInfo.fromPlatform();
      _packageName = info.packageName;
    } catch (_) {}
    if (available) {
      final resp = await InAppPurchase.instance.queryProductDetails({
        // Nouveaux SKUs autorisés uniquement
        'premium_12mois_1', 'premium_12mois_2',
        'premium_6mois_1',  'premium_6mois_2',
        'premium_1mois_1',  'premium_1mois_2',
      });
      _products = resp.productDetails;
      // Ajout ad hoc: tenter de récupérer les nouvelles variantes spécifiques si non présentes
      try {
        final missingIds = <String>{
          'premium_12mois_1','premium_12mois_2',
          'premium_6mois_1','premium_6mois_2',
          'premium_1mois_1','premium_1mois_2',
        }
          .where((id) => !_products.any((p) => p.id == id))
          .toSet();
        if (missingIds.isNotEmpty) {
          final extra = await InAppPurchase.instance.queryProductDetails(missingIds);
          if (extra.productDetails.isNotEmpty) {
            _products = [..._products, ...extra.productDetails];
          }
        }
      } catch (_) {}
      products.value = List<ProductDetails>.from(_products);
      await _loadOwnedPurchases();
      // Écouter les mises à jour d'achats pour déclencher la vérification serveur
      _purchaseSub?.cancel();
      _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e, StackTrace s) {
          if (kDebugMode) debugPrint('❌ purchaseStream error: $e');
        },
        onDone: () {
          if (kDebugMode) debugPrint('ℹ️ purchaseStream done');
        },
      );
      // NE PLUS restaurer automatiquement à l'initialisation pour éviter d'appliquer
      // un abonnement Play du device sur un autre compte Firebase.
    }
    // Écouter le profil pour estPremium
    final user = _auth.currentUser;
    if (user != null) {
      _profileSub?.cancel();
      _profileSub = _db.collection('utilisateurs').doc(user.uid).snapshots().listen((doc) async {
        final premium = doc.data()?['profil']?['estPremium'] == true;
        if (kDebugMode) debugPrint('⭐ estPremium=$premium');
        isPremium.value = premium;
        // Ne plus utiliser le champ racine `abonnement`; la source de vérité est la subcollection `abonnement/current`.
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
            final Map<String, dynamic>? aboMap = abonnement.value;
            final String? token = aboMap?['lastToken'] as String?;
            final String? subscriptionId = (aboMap?['subscriptionId'] as String?) ?? (aboMap?['offre']?['productId'] as String?) ?? (aboMap?['produitId'] as String?);
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
      // Écouter la source de vérité: `utilisateurs/{uid}/abonnement/current`
      _aboSub?.cancel();
      _aboSub = _db
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('abonnement')
          .doc('current')
          .snapshots()
          .listen((doc) {
        abonnement.value = doc.data();
      });
    }
  }

  /// Rafraîchit la liste des produits (à appeler après ajout d'un nouveau SKU côté Play)
  Future<void> refreshProducts() async {
    try {
      final resp = await InAppPurchase.instance.queryProductDetails({
        'premium_12mois_1','premium_12mois_2',
        'premium_6mois_1','premium_6mois_2',
        'premium_1mois_1','premium_1mois_2',
      });
      _products = resp.productDetails;
      // Récupérer aussi les variantes ad hoc si absentes
      try {
        final missingIds = <String>{
          'premium_12mois_1','premium_12mois_2',
          'premium_6mois_1','premium_6mois_2',
          'premium_1mois_1','premium_1mois_2',
        }
          .where((id) => !_products.any((p) => p.id == id))
          .toSet();
        if (missingIds.isNotEmpty) {
          final extra = await InAppPurchase.instance.queryProductDetails(missingIds);
          if (extra.productDetails.isNotEmpty) {
            _products = [..._products, ...extra.productDetails];
          }
        }
      } catch (_) {}
      products.value = List<ProductDetails>.from(_products);
      await _loadOwnedPurchases();
      if (kDebugMode) {
        final ids = _products.map((e) => e.id).toList();
        debugPrint('🧾 Produits rafraîchis: $ids');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ refreshProducts error: $e');
    }
  }

  Future<void> _loadOwnedPurchases() async {
    // API queryPastPurchases indisponible ici → fallback: pas de filtrage local
    _ownedProductIds.clear();
  }

  ProductDetails? _firstAvailableVariant(List<String> candidateIds) {
    for (final id in candidateIds) {
      try {
        final p = _products.firstWhere((e) => e.id == id);
        if (!_ownedProductIds.contains(p.id)) {
          return p;
        }
      } catch (_) {}
    }
    for (final id in candidateIds) {
      try { return _products.firstWhere((e) => e.id == id); } catch (_) {}
    }
    return null;
  }

  Future<void> stop() async {
    await _profileSub?.cancel();
    _profileSub = null;
    await _aboSub?.cancel();
    _aboSub = null;
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  ProductDetails? get monthlyPlan {
    try {
      final List<String> candidates = ['premium_1mois_1','premium_1mois_2'];
      return _firstAvailableVariant(candidates);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    final user = _auth.currentUser;
    if (user == null) return;
    for (final p in purchases) {
      try {
        if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
          final String token = p.verificationData.serverVerificationData;
          final String subscriptionId = p.productID;
          if (token.isNotEmpty && subscriptionId.isNotEmpty) {
            // Remonter au serveur pour qu'il valide via Play et mette à jour Firestore
            await _callVerifierAbonnement(
              uid: user.uid,
              purchaseToken: token,
              subscriptionId: subscriptionId,
              packageName: _packageName ?? 'com.mindbird.app',
            );
          } else {
            // Fallback natif (#2): récupérer le token via BillingClient
            try {
              final subs = await _nativeFetchActiveSubs();
              if (subs.isNotEmpty) {
                final first = subs.first;
                final String nativeToken = (first['purchaseToken'] as String?) ?? '';
                final List<dynamic> prodsDyn = (first['products'] as List?) ?? const [];
                final List<String> prods = prodsDyn.map((e) => e.toString()).toList();
                final String subId = prods.isNotEmpty ? prods.first : subscriptionId;
                if (nativeToken.isNotEmpty && subId.isNotEmpty) {
                  await _callVerifierAbonnement(
                    uid: user.uid,
                    purchaseToken: nativeToken,
                    subscriptionId: subId,
                    packageName: _packageName ?? 'com.mindbird.app',
                  );
                }
              }
            } catch (e) {
              if (kDebugMode) debugPrint('❌ Fallback natif fetchActiveSubs erreur: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ _onPurchaseUpdates error: $e');
      } finally {
        if (p.pendingCompletePurchase) {
          try { await InAppPurchase.instance.completePurchase(p); } catch (_) {}
        }
      }
    }
    // Recharger achats possédés pour la logique de sélection de variante
    await _loadOwnedPurchases();
  }

  Future<List<Map<String, dynamic>>> _nativeFetchActiveSubs() async {
    try {
      final res = await _billingChannel.invokeMethod('fetchActiveSubs');
      final list = (res as List).cast<dynamic>();
      return list
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ nativeFetchActiveSubs error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Force la resynchronisation de l'état d'abonnement depuis Firestore vers le serveur
  Future<bool> forceResync() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await _db.collection('utilisateurs').doc(user.uid).collection('abonnement').doc('current').get();
      final data = doc.data();
      final String? token = data?['lastToken'] as String?;
      final String? subscriptionId = (data?['subscriptionId'] as String?) ?? (data?['offre']?['productId'] as String?);
      final String packageName = (data?['packageName'] as String?) ?? 'com.mindbird.app';
      if (token != null && token.isNotEmpty && subscriptionId != null && subscriptionId.isNotEmpty) {
        await _callVerifierAbonnement(
          uid: user.uid,
          purchaseToken: token,
          subscriptionId: subscriptionId,
          packageName: packageName,
        );
        return true;
      }
      // Fallback natif (#2): interroger BillingClient pour récupérer un token
      try {
        final subs = await _nativeFetchActiveSubs();
        if (subs.isEmpty) return false;
        final first = subs.first;
        final String token = (first['purchaseToken'] as String?) ?? '';
        final List<dynamic> prodsDyn = (first['products'] as List?) ?? const [];
        final List<String> prods = prodsDyn.map((e) => e.toString()).toList();
        final String? subId = prods.isNotEmpty ? prods.first : null;
        if (token.isEmpty || subId == null || subId.isEmpty) return false;
        final info = await PackageInfo.fromPlatform();
        final String packageName = info.packageName;
        await _callVerifierAbonnement(
          uid: user.uid,
          purchaseToken: token,
          subscriptionId: subId,
          packageName: packageName,
        );
        return true;
      } catch (e) {
        if (kDebugMode) debugPrint('❌ forceResync fallback natif erreur: $e');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ forceResync error: $e');
      return false;
    }
  }
  ProductDetails? get yearlyPlan {
    try {
      return _firstAvailableVariant(['premium_12mois_1','premium_12mois_2']);
    } catch (_) { return null; }
  }
  ProductDetails? get semiAnnualPlan {
    try {
      return _firstAvailableVariant(['premium_6mois_1','premium_6mois_2']);
    } catch (_) { return null; }
  }

  // Raw helpers
  double? get monthlyRawPrice => monthlyPlan?.rawPrice;
  String? get monthlyCurrencyCode => monthlyPlan?.currencyCode;

  String formatCurrency(double amount, String? currencyCode) {
    final str = amount.toStringAsFixed(2).replaceAll('.', ',');
    final symbol = _currencySymbol(currencyCode);
    return '$str $symbol';
  }

  // === Diagnostics légers vers Firestore ===
  Future<void> _diag(String label, [Map<String, dynamic>? extra]) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _db
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('diagnostics')
          .doc('abonnement')
          .collection('logs')
          .add({
        'label': label,
        if (extra != null) ...extra,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
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
        return r'$';
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
      // S'assurer que le client est authentifié côté Firebase avant l'appel
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('❌ verifierAbonnement: aucun utilisateur connecté');
        return;
      }
      try { await user.getIdToken(true); } catch (_) {}

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      Future<void> invoke() async {
        await functions.httpsCallable('verifierAbonnement').call({
          'uid': uid,
          'packageName': packageName,
          'subscriptionId': subscriptionId,
          'purchaseToken': purchaseToken,
        });
      }

      try {
        await invoke();
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'unauthenticated') {
          // Tentative unique: rafraîchir le token et réessayer
          try { await user.getIdToken(true); } catch (_) {}
          try {
            await invoke();
          } on FirebaseFunctionsException catch (e2) {
            if (kDebugMode) debugPrint('⚠️ Callable échec après refresh (${e2.code}) → fallback HTTP');
            await _callVerifierAbonnementHttp(
              uid: uid,
              purchaseToken: purchaseToken,
              subscriptionId: subscriptionId,
              packageName: packageName,
            );
            return;
          }
        } else {
          if (kDebugMode) debugPrint('⚠️ Callable erreur ${e.code} → fallback HTTP');
          await _callVerifierAbonnementHttp(
            uid: uid,
            purchaseToken: purchaseToken,
            subscriptionId: subscriptionId,
            packageName: packageName,
          );
          return;
        }
      }
      if (kDebugMode) debugPrint('📡 verifierAbonnement (resync) appelé');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ verifierAbonnement (resync) échec: $e → tentative HTTP');
      try {
        await _callVerifierAbonnementHttp(
          uid: uid,
          purchaseToken: purchaseToken,
          subscriptionId: subscriptionId,
          packageName: packageName,
        );
      } catch (e2) {
        if (kDebugMode) debugPrint('❌ verifierAbonnementHttp échec: $e2');
      }
    }
  }

  Future<void> _callVerifierAbonnementHttp({
    required String uid,
    required String purchaseToken,
    required String subscriptionId,
    String? packageName,
  }) async {
    final String projectId = Firebase.app().options.projectId;
    final String region = 'europe-west1';
    final Uri url = Uri.parse('https://$region-$projectId.cloudfunctions.net/verifierAbonnementHttp');
    final Map<String, dynamic> payload = {
      'uid': uid,
      'packageName': packageName,
      'subscriptionId': subscriptionId,
      'purchaseToken': purchaseToken,
    };
    final resp = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (kDebugMode) debugPrint('✅ verifierAbonnementHttp OK');
    } else {
      if (kDebugMode) debugPrint('❌ verifierAbonnementHttp statut ${resp.statusCode}: ${resp.body}');
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  // Expose une méthode publique pour les écrans (bouton Forcer synchro)
  Future<void> sendVerifierAbonnementHttp({
    required String uid,
    required String purchaseToken,
    required String subscriptionId,
    String? packageName,
  }) async {
    await _callVerifierAbonnementHttp(
      uid: uid,
      purchaseToken: purchaseToken,
      subscriptionId: subscriptionId,
      packageName: packageName,
    );
  }

  Future<bool> buyMonthly() async {
    return _buyWithFallback(['premium_1mois_1','premium_1mois_2']);
  }

  Future<bool> buyYearly() async {
    return _buyWithFallback(['premium_12mois_1','premium_12mois_2']);
  }

  Future<bool> buySemiAnnual() async {
    return _buyWithFallback(['premium_6mois_1','premium_6mois_2']);
  }

  Future<void> restore() async {
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _iapBuy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<bool> _waitForPremiumOrTimeout(Duration timeout) async {
    if (isPremium.value == true) return true;
    final completer = Completer<bool>();
    late VoidCallback sub;
    final timer = Timer(timeout, () {
      try { isPremium.removeListener(sub); } catch (_) {}
      if (!completer.isCompleted) completer.complete(false);
    });
    sub = () {
      if (isPremium.value == true && !completer.isCompleted) {
        timer.cancel();
        try { isPremium.removeListener(sub); } catch (_) {}
        completer.complete(true);
      }
    };
    isPremium.addListener(sub);
    final ok = await completer.future;
    return ok;
  }

  Future<bool> _buyWithFallback(List<String> candidateIds) async {
    // Tente le premier SKU disponible
    final first = _firstAvailableVariant(candidateIds);
    if (first == null) return false;
    await _iapBuy(first);
    var ok = await _waitForPremiumOrTimeout(const Duration(seconds: 15));
    if (ok) return true;
    // Si non confirmé, tenter l'autre variante si différente
    final altId = candidateIds.firstWhere(
      (id) => id != first.id && _products.any((p) => p.id == id),
      orElse: () => '',
    );
    if (altId.isNotEmpty) {
      final alt = _products.firstWhere((p) => p.id == altId);
      await _iapBuy(alt);
      ok = await _waitForPremiumOrTimeout(const Duration(seconds: 15));
      return ok;
    }
    return false;
  }
}


