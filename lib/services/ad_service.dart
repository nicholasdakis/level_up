import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String _admobRewardedId = kDebugMode
    ? 'ca-app-pub-3940256099942544/5224354917' // AdMob test rewarded ad
    : 'ca-app-pub-4003172698560190/3613427043';

const String _unityGameId = '800005950';
const String _unityPlacementId = 'Rewarded_Android';

class AdService {
  RewardedAd? _admobAd;
  bool _admobLoading = false;
  bool _unityReady = false;

  bool get isReady => _admobAd != null || _unityReady;

  void initialize() {
    if (kDebugMode) debugPrint('[AdService] initialize() called');
    // Delay 5 seconds so the GMS SDK callbacks don't flood the main looper during app startup
    Future.delayed(const Duration(seconds: 5), () {
      if (kDebugMode) debugPrint('[AdService] delay complete, initing ads');

      unawaited(
        MobileAds.instance.initialize().then((_) {
          unawaited(_loadAdmobAd());
        }),
      );
      UnityAds.init(
        gameId: _unityGameId,
        testMode: kDebugMode,
        onComplete: () => _loadUnityAd(),
        onFailed: (error, message) {
          if (kDebugMode) debugPrint('Unity Ads init failed: $message');
        },
      );
    });
  }

  Future<void> _loadAdmobAd() async {
    if (_admobLoading || _admobAd != null) return;
    _admobLoading = true;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await RewardedAd.load(
      adUnitId: _admobRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(customData: uid),
          );
          _admobAd = ad;
          _admobLoading = false;
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) debugPrint('AdMob failed to load: $error');
          _admobLoading = false;
        },
      ),
    );
  }

  void _loadUnityAd() {
    UnityAds.load(
      placementId: _unityPlacementId,
      onComplete: (placementId) {
        if (kDebugMode) debugPrint('[AdService] Unity ad loaded successfully');
        _unityReady = true;
      },
      onFailed: (placementId, error, message) {
        if (kDebugMode) debugPrint('Unity Ads load failed: $message');
        _unityReady = false;
      },
    );
  }

  Future<void> showRewardedAd({required VoidCallback onRewarded}) async {
    // Try Unity first since AdMob is pending approval
    if (_unityReady) {
      _showUnityAd(onRewarded: onRewarded);
      return;
    }

    // Fall back to AdMob
    if (_admobAd != null) {
      _admobAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _admobAd = null;
          _loadAdmobAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _admobAd = null;
          _loadAdmobAd();
          _showUnityAd(onRewarded: onRewarded);
        },
      );
      await _admobAd!.show(onUserEarnedReward: (_, reward) => onRewarded());
      return;
    }

    // Neither ready, reload in background; user will need to tap again
    unawaited(_loadAdmobAd());
  }

  void _showUnityAd({required VoidCallback onRewarded}) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    UnityAds.showVideoAd(
      placementId: _unityPlacementId,
      onComplete: (placementId) {
        onRewarded();
        _unityReady = false;
        _loadUnityAd();
      },
      onFailed: (placementId, error, message) {
        if (kDebugMode) debugPrint('Unity Ads show failed: $message');
        _unityReady = false;
        _loadUnityAd();
      },
      onSkipped: (placementId) {
        _unityReady = false;
        _loadUnityAd();
      },
      serverId: uid,
    );
  }

  void dispose() {
    _admobAd?.dispose();
    _admobAd = null;
  }
}

// Global instance
final adService = AdService();
