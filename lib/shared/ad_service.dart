import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppAdService {
  AppAdService._();

  static final AppAdService instance = AppAdService._();

  // 디버그 빌드(flutter run)에서는 Google 공식 테스트 광고 ID 사용
  static const String _rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-4392701551381492/7686779947';

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
        },
      ),
    );
  }

  bool get isReady => _rewardedAd != null;

  /// 보상형 광고를 보여주고, 유저가 끝까지 시청하면 true 반환.
  /// 광고가 준비되지 않았거나 도중에 닫으면 false 반환.
  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) return false;
    _rewardedAd = null; // 사용 중 처리

    final completer = Completer<bool>();
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd(); // 다음 광고 미리 로딩
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (_, reward) {
        rewarded = true;
      },
    );

    return completer.future;
  }
}
