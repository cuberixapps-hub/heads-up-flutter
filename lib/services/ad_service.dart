import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static bool _initialized = false;

  // PRODUCTION Ad IDs - Replace with your actual IDs
  // Android
  static const String _prodAndroidBannerAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodAndroidInterstitialAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodAndroidRewardedAdUnitId = 'ca-app-pub-XXXX/XXXX';

  // iOS
  static const String _prodIosBannerAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodIosInterstitialAdUnitId = 'ca-app-pub-XXXX/XXXX';
  static const String _prodIosRewardedAdUnitId = 'ca-app-pub-XXXX/XXXX';

  // TEST Ad IDs - Google's official test IDs (DO NOT CHANGE)
  // Android
  static const String _testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // iOS
  static const String _testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  // Frequency control for interstitial ads
  DateTime? _lastInterstitialTime;
  int _gamesPlayedSinceLastAd = 0;
  static const int _gamesBeforeAd = 3;
  static const Duration _minTimeBetweenAds = Duration(minutes: 3);

  /// CRITICAL: Automatically use test ads in debug/profile mode
  /// This prevents accidental clicks during development
  /// Also checks Firebase Remote Config for production override
  bool get _useTestAds {
    // Always use test ads in debug/profile mode for safety
    if (kDebugMode || kProfileMode) return true;

    // In release mode, check Firebase Remote Config
    // If Remote Config says use_production_ads = false, use test ads
    return !FirebaseService.shouldUseProductionAds();
  }

  /// Get the appropriate banner ad unit ID based on platform and mode
  String get bannerAdUnitId {
    if (_useTestAds) {
      if (Platform.isAndroid) return _testAndroidBannerAdUnitId;
      if (Platform.isIOS) return _testIosBannerAdUnitId;
    } else {
      if (Platform.isAndroid) return _prodAndroidBannerAdUnitId;
      if (Platform.isIOS) return _prodIosBannerAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  String get interstitialAdUnitId {
    if (_useTestAds) {
      if (Platform.isAndroid) return _testAndroidInterstitialAdUnitId;
      if (Platform.isIOS) return _testIosInterstitialAdUnitId;
    } else {
      if (Platform.isAndroid) return _prodAndroidInterstitialAdUnitId;
      if (Platform.isIOS) return _prodIosInterstitialAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  String get rewardedAdUnitId {
    if (_useTestAds) {
      if (Platform.isAndroid) return _testAndroidRewardedAdUnitId;
      if (Platform.isIOS) return _testIosRewardedAdUnitId;
    } else {
      if (Platform.isAndroid) return _prodAndroidRewardedAdUnitId;
      if (Platform.isIOS) return _prodIosRewardedAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;

      // Log initialization details for debugging
      final instance = AdService();
      final platform = Platform.isAndroid ? 'Android' : 'iOS';

      if (instance._useTestAds) {
        debugPrint('🔧 AdMob SDK initialized with TEST ADS');
        debugPrint('📍 Reason: ${kDebugMode ? "Debug Mode" : "Profile Mode"}');
      } else {
        debugPrint('✅ AdMob SDK initialized with PRODUCTION ADS');
      }
      debugPrint('📱 Platform: $platform');
      debugPrint('🆔 Banner ID: ${instance.bannerAdUnitId}');

      // Preload ads for better performance
      instance.loadBannerAd();
      instance.loadInterstitialAd();
      instance.loadRewardedAd();
    } catch (e) {
      debugPrint('❌ AdMob SDK initialization failed: $e');
      FirebaseService.logError(e, StackTrace.current);
    }
  }

  /// Load Banner Ad
  void loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isBannerAdReady = true;
          debugPrint('✅ Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner ad failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
          _bannerAd = null;

          // Retry after delay
          Future.delayed(const Duration(seconds: 30), loadBannerAd);
        },
      ),
    );
    _bannerAd?.load();
  }

  /// Get Banner Ad Widget
  Widget? getBannerAdWidget() {
    if (_isBannerAdReady && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  /// Load Interstitial Ad
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('✅ Interstitial ad loaded');

          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Interstitial ad failed to show: $error');
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;

          // Retry after delay
          Future.delayed(const Duration(seconds: 60), loadInterstitialAd);
        },
      ),
    );
  }

  /// Check if we should show interstitial ad
  bool shouldShowInterstitialAd() {
    _gamesPlayedSinceLastAd++;

    // Check game count
    if (_gamesPlayedSinceLastAd < _gamesBeforeAd) {
      debugPrint('📊 Games played: $_gamesPlayedSinceLastAd/$_gamesBeforeAd');
      return false;
    }

    // Check time limit
    if (_lastInterstitialTime != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialTime!);
      if (timeSinceLastAd < _minTimeBetweenAds) {
        debugPrint(
          '⏱️ Too soon for next ad. Wait: ${_minTimeBetweenAds - timeSinceLastAd}',
        );
        return false;
      }
    }

    // Check with random probability (1 in 3 chance)
    if (math.Random().nextInt(3) != 0) {
      debugPrint('🎲 Random check failed for interstitial');
      return false;
    }

    return true;
  }

  /// Show Interstitial Ad with frequency control
  Future<void> showInterstitialAd() async {
    if (!shouldShowInterstitialAd()) {
      return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      _gamesPlayedSinceLastAd = 0;
      _lastInterstitialTime = DateTime.now();
      await _interstitialAd!.show();

      // Log event
      await FirebaseService().logEvent(
        'interstitial_ad_shown',
        parameters: {'location': 'game_complete'},
      );
    } else {
      debugPrint('⚠️ Interstitial ad not ready');
      loadInterstitialAd(); // Try loading if not ready
    }
  }

  /// Show Interstitial Ad for returning home
  Future<void> showInterstitialAdForHome() async {
    // Only show occasionally (1 in 3 times)
    if (math.Random().nextInt(3) != 0) return;

    // Check time limit
    if (_lastInterstitialTime != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialTime!);
      if (timeSinceLastAd < _minTimeBetweenAds) return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      _lastInterstitialTime = DateTime.now();
      await _interstitialAd!.show();

      // Log event
      await FirebaseService().logEvent(
        'interstitial_ad_shown',
        parameters: {'location': 'return_home'},
      );
    }
  }

  /// Load Rewarded Ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('✅ Rewarded ad loaded');

          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Rewarded ad failed to show: $error');
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded ad failed to load: $error');
          _isRewardedAdReady = false;

          // Retry after delay
          Future.delayed(const Duration(seconds: 60), loadRewardedAd);
        },
      ),
    );
  }

  /// Show Rewarded Ad with callback
  Future<void> showRewardedAd({
    required Function(num amount) onUserEarnedReward,
    required String rewardType,
  }) async {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.setImmersiveMode(true);
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onUserEarnedReward(reward.amount);

          // Log event
          FirebaseService().logEvent(
            'rewarded_ad_earned',
            parameters: {
              'reward_type': rewardType,
              'reward_amount': reward.amount.toInt(),
            },
          );
        },
      );
    } else {
      debugPrint('⚠️ Rewarded ad not ready');
      loadRewardedAd(); // Try loading if not ready
    }
  }

  /// Dispose all ads
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }

  /// Reset game counter for interstitial ads
  void incrementGameCount() {
    _gamesPlayedSinceLastAd++;
  }
}

