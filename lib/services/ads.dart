import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';

/// AdMob: rewarded ads the player chooses to watch (revive, double a
/// dungeon reward, free potions) and a rare interstitial when walking back
/// to town.
///
/// Both platforms use the game's own AdMob units; the App IDs live in
/// android/app/build.gradle.kts and ios/Runner/Info.plist. Everything is a no-op on web and in tests, and
/// any ad failure just means "no ad", never a blocked game.
class AdsService with WidgetsBindingObserver {
  AdsService._();
  static final AdsService instance = AdsService._();

  /// The app's navigator, for the lead-in screen before each ad.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Players tap fast (attacking, reeling a fish); an ad that opened at once
  /// caught the next taps as clicks. A short screen that swallows every tap
  /// comes first, so only a deliberate tap reaches the ad.
  static const leadIn = Duration(milliseconds: 900);

  Future<void> _leadIn() async {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => const Positioned.fill(
        child: AbsorbPointer(
          child: ColoredBox(
            color: Color(0xCC000000),
            child: Center(
              child: Text(
                'Quảng cáo sắp bắt đầu…',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Color(0xFFF3E6C8), fontSize: 16, decoration: TextDecoration.none),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(leadIn);
    entry.remove();
  }

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static String get rewardedUnit => _ios
      ? 'ca-app-pub-9078637596840810/7162883061'
      : 'ca-app-pub-9078637596840810/7500446917';

  static String get interstitialUnit => _ios
      ? 'ca-app-pub-9078637596840810/7393983201'
      : 'ca-app-pub-9078637596840810/6558066189';

  /// No interstitial within this long of any other full-screen ad, or of
  /// the app starting.
  static const interstitialGap = Duration(minutes: 4);

  /// App Open ads (1.7.0) when the player comes back after [appOpenAway].
  /// One unit per platform.
  static String get appOpenUnit => _ios ? 'ca-app-pub-9078637596840810/4638692857' : 'ca-app-pub-9078637596840810/4136789119';
  static const appOpenAway = Duration(minutes: 30);

  /// Gói bỏ quảng cáo bought (services/purchase.dart): no interstitial or
  /// App Open ads, and every rewarded ad is granted without being shown.
  final ValueNotifier<bool> adFree = ValueNotifier(false);
  static const _adFreeKey = 'no_ads';

  /// Asked before an App Open ad: false while the player is new.
  bool Function() appOpenAllowed = () => true;

  AppOpenAd? _appOpen;
  DateTime? _pausedAt;

  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);
  bool _started = false;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  DateTime _lastFullScreen = DateTime.now();
  bool _loadingRewarded = false;

  /// Whether the consent SDK says a privacy-options entry must be offered.
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  Future<void> loadAdFree() async {
    try {
      final p = await SharedPreferences.getInstance();
      setAdFree(p.getBool(_adFreeKey) ?? false, save: false);
    } catch (_) {}
  }

  void setAdFree(bool v, {bool save = true}) {
    adFree.value = v;
    if (v) rewardedReady.value = true;
    if (save) {
      SharedPreferences.getInstance().then((p) => p.setBool(_adFreeKey, v)).catchError((_) => false);
    }
  }

  void _setReady(bool v) => rewardedReady.value = v || adFree.value;

  Future<void> init() async {
    await loadAdFree();
    if (!_supported) return;
    try {
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      if (_ios) await _askTracking();
      await MobileAds.instance.initialize();
      _started = true;
      _loadRewarded();
      _loadInterstitial();
      _loadAppOpen();
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('ads off: $e');
    }
  }

  /// iOS App Tracking Transparency, asked once before the first ad request.
  /// Whatever the answer, ads still load (non-personalised when denied). The
  /// prompt only shows once the app is on screen, so wait for the first frame.
  Future<void> _askTracking() async {
    try {
      if (await AppTrackingTransparency.trackingAuthorizationStatus != TrackingStatus.notDetermined) return;
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('tracking prompt failed: $e');
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
          _setReady(true);
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          _setReady(false);
          // Try again in a minute; no network now may mean network later.
          Timer(const Duration(minutes: 1), _loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded ad. Completes with true only if the player watched
  /// it through and earned the reward.
  Future<bool> showRewarded() async {
    if (adFree.value) {
      Analytics.instance.log('ad_free_reward');
      return true;
    }
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    _setReady(false);
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
    await _leadIn();
    await ad.show(onUserEarnedReward: (_, _) {
      earned = true;
      Analytics.instance.log('ad_reward');
    });
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
    if (!_started || adFree.value) return;
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
    _leadIn().then((_) => ad.show());
  }

  // ------------------------------------------------------------ app open

  void _loadAppOpen() {
    if (!_started || _appOpen != null || appOpenUnit.isEmpty) return;
    AppOpenAd.load(
      adUnitId: appOpenUnit,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (_) => _appOpen = null,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away >= appOpenAway) _maybeShowAppOpen();
    }
  }

  void _maybeShowAppOpen() {
    final ad = _appOpen;
    if (!_started || adFree.value || ad == null || !appOpenAllowed()) {
      _loadAppOpen();
      return;
    }
    if (DateTime.now().difference(_lastFullScreen) < interstitialGap) return;
    _appOpen = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _lastFullScreen = DateTime.now();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadAppOpen();
      },
    );
    Analytics.instance.log('ad_app_open');
    ad.show();
  }
}
