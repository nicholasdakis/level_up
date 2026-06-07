import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Test ad unit ID for development, real ID for production
const String _rewardedAdUnitId = kDebugMode
    ? 'ca-app-pub-3940256099942544/5224354917' // Google test rewarded ad
    : 'ca-app-pub-4003172698560190/3613427043';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isReady => _rewardedAd != null;

  // Preloads the rewarded ad so it's ready to show instantly
  Future<void> loadRewardedAd() async {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(customData: uid),
          );
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) debugPrint('RewardedAd failed to load: $error');
          _isLoading = false;
        },
      ),
    );
  }

  // Shows the rewarded ad and calls onRewarded when the user completes it
  Future<void> showRewardedAd({required VoidCallback onRewarded}) async {
    if (_rewardedAd == null) {
      await loadRewardedAd();
      if (_rewardedAd == null) return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // preload next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: (_, reward) => onRewarded());
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

// Global instance
final adService = AdService();
