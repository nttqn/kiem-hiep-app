import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob: rewarded ads the player chooses to watch (revive, double a
/// dungeon reward, free potions) and a rare interstitial when walking back
/// to town.
///
/// The unit ids below are Google's public test units until the game's own
/// AdMob app exists; the App IDs live in android/app/build.gradle.kts and
/// ios/Runner/Info.plist. Everything is a no-op on web and in tests, and
/// any ad failure just means "no ad", never a blocked game.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static String get rewardedUnit => _ios
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  static String get interstitialUnit => _ios
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  /// No interstitial within this long of any other full-screen ad, or of
  /// the app starting.
  static const interstitialGap = Duration(minutes: 4);

  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);
  bool _started = false;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  DateTime _lastFullScreen = DateTime.now();
  bool _loadingRewarded = false;

  /// Whether the consent SDK says a privacy-options entry must be offered.
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  Future<void> init() async {
    if (!_supported) return;
    try {
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _started = true;
      _loadRewarded();
      _loadInterstitial();
    } catch (e) {
      debugPrint('ads off: $e');
    }
  }

  /// Google's consent form (GDPR and similar); shown only where required.
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          privacyOptionsRequired.value =
              await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
                  PrivacyOptionsRequirementStatus.required;
          if (!done.isCompleted) done.complete();
        });
      },
      (error) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Lets the player change their ad consent choice.
  void showPrivacyOptions() {
    if (!_supported) return;
    ConsentForm.showPrivacyOptionsForm((_) {});
  }

  // ------------------------------------------------------------ rewarded

  void _loadRewarded() {
    if (!_started || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: rewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          rewardedReady.value = false;
          // Try again in a minute; no network now may mean network later.
          Timer(const Duration(minutes: 1), _loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded ad. Completes with true only if the player watched
  /// it through and earned the reward.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    rewardedReady.value = false;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _lastFullScreen = DateTime.now();
        _loadRewarded();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        if (!result.isCompleted) result.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  // ------------------------------------------------------------ interstitial

  void _loadInterstitial() {
    if (!_started || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call when the player leaves a map or dungeon for town, never during
  /// play. Shows at most once per [interstitialGap].
  void maybeShowInterstitial() {
    if (!_started) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    if (DateTime.now().difference(_lastFullScreen) < interstitialGap) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _lastFullScreen = DateTime.now();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
