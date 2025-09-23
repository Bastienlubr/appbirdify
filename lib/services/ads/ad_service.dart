import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service centralisant RewardedAd (préchargement + affichage)
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// IDs (test en debug, réel en release)
  static String get rewardedUnitId {
    if (kDebugMode) {
      // ID Rewarded de TEST officiel Google
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    // ID Rewarded (Android) fourni par AdMob (prod)
    return 'ca-app-pub-3929545845735693/7071165914';
  }

  Future<void> preloadRewarded() async {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
            if (kDebugMode) debugPrint('✅ RewardedAd chargé');
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _isLoading = false;
            if (kDebugMode) debugPrint('❌ Échec chargement RewardedAd: $error');
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      if (kDebugMode) debugPrint('❌ preloadRewarded erreur: $e');
    }
  }

  /// Affiche l'annonce si prête. Retourne true si l'utilisateur a gagné la récompense.
  Future<bool> showRewardedIfAvailable() async {
    final ad = _rewardedAd;
    if (ad == null) {
      // tenter un chargement rapide puis réessayer
      await preloadRewarded();
      if (_rewardedAd == null) return false;
    }

    final completer = Completer<bool>();
    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('📺 RewardedAd affiché');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        // re-précharger
        preloadRewarded();
        completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewarded();
        completer.complete(false);
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      rewarded = true;
      if (kDebugMode) debugPrint('🎁 Récompense acquise: ${reward.amount} ${reward.type}');
    });

    return completer.future;
  }
}


