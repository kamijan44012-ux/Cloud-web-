import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/game_config.dart';

/// AdMob wrapper: banner, interstitial and rewarded video. All public methods
/// degrade gracefully when ads are disabled, removed via IAP, or not yet
/// loaded — the game never blocks on an ad.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  bool _initialised = false;
  bool adsRemoved = false;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _runsSinceInterstitial = 0;

  Future<void> init() async {
    if (!GameConfig.enableAds || _initialised) return;
    await MobileAds.instance.initialize();
    _initialised = true;
    _loadInterstitial();
    _loadRewarded();
  }

  bool get _enabled => GameConfig.enableAds && _initialised && !adsRemoved;

  // ---------------------------------------------------------------------------
  // Interstitial — shown between runs, throttled so it isn't obnoxious.
  // ---------------------------------------------------------------------------
  void _loadInterstitial() {
    if (!GameConfig.enableAds) return;
    InterstitialAd.load(
      adUnitId: GameConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) => _interstitial = ad,
        onAdFailedToLoad: (LoadAdError e) => debugPrint('Interstitial failed: $e'),
      ),
    );
  }

  void maybeShowInterstitial() {
    if (!_enabled) return;
    _runsSinceInterstitial++;
    if (_runsSinceInterstitial < 3 || _interstitial == null) return;
    _runsSinceInterstitial = 0;
    _interstitial!.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    _interstitial!.show();
    _interstitial = null;
  }

  // ---------------------------------------------------------------------------
  // Rewarded — opt-in: revive, double coins, free gems.
  // ---------------------------------------------------------------------------
  void _loadRewarded() {
    if (!GameConfig.enableAds) return;
    RewardedAd.load(
      adUnitId: GameConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) => _rewarded = ad,
        onAdFailedToLoad: (LoadAdError e) => debugPrint('Rewarded failed: $e'),
      ),
    );
  }

  bool get isRewardedReady => _rewarded != null;

  /// Shows a rewarded ad and invokes [onReward] only if the user earns it.
  /// When ads are disabled (e.g. in dev), grants the reward immediately so
  /// flows stay testable.
  Future<void> showRewarded({required VoidCallback onReward}) async {
    if (!GameConfig.enableAds) {
      onReward();
      return;
    }
    if (_rewarded == null) return;
    final RewardedAd ad = _rewarded!;
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd a) {
        a.dispose();
        _loadRewarded();
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => onReward());
  }

  BannerAd? createBanner() {
    if (!_enabled) return null;
    return BannerAd(
      adUnitId: GameConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (Ad ad, LoadAdError e) => ad.dispose(),
      ),
    )..load();
  }
}
