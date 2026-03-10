import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ads_config.dart';
import '../config/environment.dart';
import 'firebase_service.dart';
import 'purchases_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static bool _initialized = false;

  /// Check if Mobile Ads SDK is initialized
  static bool get isInitialized => _initialized;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  /// Check if rewarded ad is ready to be shown
  bool get isRewardedAdReady => _isRewardedAdReady && _rewardedAd != null;

  // Frequency control for interstitial ads
  DateTime? _lastInterstitialTime;
  int _gamesPlayedSinceLastAd = 0;
  static const int _gamesBeforeAd = 3;
  static const Duration _minTimeBetweenAds = Duration(minutes: 3);

  // Daily rewarded ad limit - to encourage premium conversions
  static const int maxDailyRewardedAds = 5;
  static const String _dailyAdCountKey = 'daily_rewarded_ad_count';
  static const String _lastAdDateKey = 'last_rewarded_ad_date';
  
  // Cached daily ad count for sync access
  int _cachedDailyAdCount = 0;
  String _cachedAdDate = '';
  bool _dailyAdCountInitialized = false;

  String get bannerAdUnitId => AdsConfig.bannerAdUnitId;
  String get interstitialAdUnitId => AdsConfig.interstitialAdUnitId;
  String get rewardedAdUnitId => AdsConfig.rewardedAdUnitId;

  /// Initialize Mobile Ads SDK. Always runs on app start.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;

      final instance = AdService();
      if (EnvironmentConfig.enableDebugLogging) {
        final platform = Platform.isAndroid ? 'Android' : 'iOS';
        debugPrint('🔧 AdMob SDK initialized');
        debugPrint('📱 Platform: $platform');
        debugPrint('🆔 Banner ID: ${instance.bannerAdUnitId}');
      }

      await instance.initializeDailyAdCount();
      instance.loadBannerAd();
      instance.loadInterstitialAd();
      instance.loadRewardedAd();
    } catch (e, stackTrace) {
      debugPrint('❌ AdMob initialization failed: $e');
      FirebaseService.logError(e, stackTrace);
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

  /// Get adaptive banner ad size for full width
  Future<AdSize?> getAdaptiveBannerSize(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width.truncate();

    // Get adaptive ad size
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      screenWidth,
    );
  }

  /// Get Banner Ad Widget
  /// Returns null for premium users (ad-free experience)
  Widget? getBannerAdWidget() {
    // Skip ads ONLY if user has verified premium status
    final isPremium = PurchasesService().isPremium;
    if (isPremium) {
      debugPrint('⭐ Banner ad skipped - user has premium');
      return null;
    }
    
    if (_isBannerAdReady && _bannerAd != null) {
      debugPrint('📢 Showing banner ad to free user');
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    debugPrint('⚠️ Banner ad not ready');
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

          ad.fullScreenContentCallback = FullScreenContentCallback(
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
  /// Skips showing ads ONLY for verified premium users
  Future<void> showInterstitialAd() async {
    // Skip ads ONLY if user has verified premium status
    final isPremium = PurchasesService().isPremium;
    if (isPremium) {
      debugPrint('⭐ Skipping interstitial ad - user has premium');
      return;
    }
    
    if (!shouldShowInterstitialAd()) {
      return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      debugPrint('📢 Showing interstitial ad to free user');
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
  /// Skips showing ads ONLY for verified premium users
  Future<void> showInterstitialAdForHome() async {
    // Skip ads ONLY if user has verified premium status
    final isPremium = PurchasesService().isPremium;
    if (isPremium) {
      debugPrint('⭐ Skipping home interstitial ad - user has premium');
      return;
    }
    
    // Only show occasionally (1 in 3 times)
    if (math.Random().nextInt(3) != 0) return;

    // Check time limit
    if (_lastInterstitialTime != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialTime!);
      if (timeSinceLastAd < _minTimeBetweenAds) return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      debugPrint('📢 Showing home interstitial ad to free user');
      _lastInterstitialTime = DateTime.now();
      await _interstitialAd!.show();

      // Log event
      await FirebaseService().logEvent(
        'interstitial_ad_shown',
        parameters: {'location': 'return_home'},
      );
    }
  }

  /// Force show interstitial ad without frequency restrictions
  /// Used for game over screen actions (Play Again, Home)
  /// Skips showing ads ONLY for verified premium users
  Future<void> showInterstitialAdForced({required String location}) async {
    // Skip ads ONLY if user has verified premium status
    final isPremium = PurchasesService().isPremium;
    if (isPremium) {
      debugPrint('⭐ Skipping forced interstitial ad - user has premium');
      return;
    }
    
    debugPrint('🎯 Attempting to force show interstitial ad for: $location');

    if (_isInterstitialAdReady && _interstitialAd != null) {
      debugPrint('📢 Showing forced interstitial ad to free user');
      _lastInterstitialTime = DateTime.now();
      _gamesPlayedSinceLastAd = 0; // Reset counter

      try {
        await _interstitialAd!.show();

        // Log event
        await FirebaseService().logEvent(
          'interstitial_ad_shown',
          parameters: {'location': location},
        );
      } catch (e) {
        debugPrint('❌ Error showing interstitial ad: $e');
      }
    } else {
      debugPrint('⚠️ Interstitial ad not ready for forced show');
      debugPrint('   - Ad ready: $_isInterstitialAdReady');
      debugPrint(
        '   - Ad instance: ${_interstitialAd != null ? "exists" : "null"}',
      );

      // Try to load the ad for next time
      loadInterstitialAd();
    }
  }

  /// Optional one-shot callback when rewarded ad finishes loading (e.g. for paywall).
  void Function()? _onRewardedAdLoaded;

  /// Load Rewarded Ad. Optionally [onLoaded] is called once when this load completes.
  void loadRewardedAd({void Function()? onLoaded}) {
    _onRewardedAdLoaded = onLoaded;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('✅ Rewarded ad loaded');
          _onRewardedAdLoaded?.call();
          _onRewardedAdLoaded = null;

          ad.fullScreenContentCallback = FullScreenContentCallback(
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
          _onRewardedAdLoaded = null;

          // Retry after delay
          Future.delayed(const Duration(seconds: 60), () => loadRewardedAd());
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

  // ============================================================
  // DAILY REWARDED AD LIMIT - MAX 5 ADS PER DAY
  // ============================================================

  /// Get today's date as YYYY-MM-DD string (UTC to avoid timezone/device-clock exploits)
  String _getTodayDateString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Initialize daily ad count cache from SharedPreferences
  Future<void> initializeDailyAdCount() async {
    if (_dailyAdCountInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_lastAdDateKey) ?? '';
      final todayDate = _getTodayDateString();
      
      if (storedDate == todayDate) {
        // Same day - load existing count
        _cachedDailyAdCount = prefs.getInt(_dailyAdCountKey) ?? 0;
      } else {
        // New day - reset count
        _cachedDailyAdCount = 0;
        await prefs.setInt(_dailyAdCountKey, 0);
        await prefs.setString(_lastAdDateKey, todayDate);
      }
      
      _cachedAdDate = todayDate;
      _dailyAdCountInitialized = true;
      debugPrint('📊 Daily ad count initialized: $_cachedDailyAdCount/$maxDailyRewardedAds');
    } catch (e) {
      debugPrint('❌ Failed to initialize daily ad count: $e');
      _cachedDailyAdCount = 0;
      _dailyAdCountInitialized = true;
    }
  }

  /// Get daily rewarded ad count (async version with persistence check)
  Future<int> getDailyAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_lastAdDateKey) ?? '';
    final todayDate = _getTodayDateString();
    
    if (storedDate != todayDate) {
      // New day - reset count
      await prefs.setInt(_dailyAdCountKey, 0);
      await prefs.setString(_lastAdDateKey, todayDate);
      _cachedDailyAdCount = 0;
      _cachedAdDate = todayDate;
      debugPrint('🌅 New day detected - resetting daily ad count');
      return 0;
    }
    
    final count = prefs.getInt(_dailyAdCountKey) ?? 0;
    _cachedDailyAdCount = count;
    _cachedAdDate = todayDate;
    return count;
  }

  /// Get daily ad count synchronously (uses cached value)
  /// Call initializeDailyAdCount() first during app startup
  int getDailyAdCountSync() {
    // Check if we need to reset for a new day
    final todayDate = _getTodayDateString();
    if (_cachedAdDate != todayDate) {
      _cachedDailyAdCount = 0;
      _cachedAdDate = todayDate;
    }
    return _cachedDailyAdCount;
  }

  /// Get remaining ads for today
  Future<int> getRemainingAdsToday() async {
    final count = await getDailyAdCount();
    return math.max(0, maxDailyRewardedAds - count);
  }

  /// Get remaining ads synchronously (uses cached value)
  int getRemainingAdsTodaySync() {
    return math.max(0, maxDailyRewardedAds - getDailyAdCountSync());
  }

  /// Check if user can watch a rewarded ad today (async)
  Future<bool> canWatchRewardedAd() async {
    final count = await getDailyAdCount();
    return count < maxDailyRewardedAds;
  }

  /// Check if user can watch a rewarded ad today (sync - uses cache)
  bool canWatchRewardedAdSync() {
    return getDailyAdCountSync() < maxDailyRewardedAds;
  }

  /// Increment daily ad count after user watches a rewarded ad
  Future<void> incrementDailyAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final todayDate = _getTodayDateString();
    
    // Ensure we're on the correct day
    final storedDate = prefs.getString(_lastAdDateKey) ?? '';
    if (storedDate != todayDate) {
      // New day - start fresh
      await prefs.setInt(_dailyAdCountKey, 1);
      await prefs.setString(_lastAdDateKey, todayDate);
      _cachedDailyAdCount = 1;
      _cachedAdDate = todayDate;
    } else {
      // Same day - increment
      final currentCount = prefs.getInt(_dailyAdCountKey) ?? 0;
      final newCount = currentCount + 1;
      await prefs.setInt(_dailyAdCountKey, newCount);
      _cachedDailyAdCount = newCount;
    }
    
    final remaining = maxDailyRewardedAds - _cachedDailyAdCount;
    debugPrint('📊 Daily ad count: $_cachedDailyAdCount/$maxDailyRewardedAds ($remaining remaining)');
    
    // Log event for analytics
    await FirebaseService().logEvent(
      'rewarded_ad_daily_count',
      parameters: {
        'count': _cachedDailyAdCount,
        'remaining': remaining,
        'limit_reached': _cachedDailyAdCount >= maxDailyRewardedAds,
      },
    );
  }

  /// Get progressive message based on daily ad count
  /// Returns a message that increases pressure as user approaches limit
  String getProgressiveAdMessage() {
    final count = getDailyAdCountSync();
    final remaining = maxDailyRewardedAds - count;
    
    if (count >= maxDailyRewardedAds) {
      return 'No more free plays today';
    } else if (remaining == 1) {
      return 'Last free play today!';
    } else if (count >= 3) {
      return 'Still watching ads? Unlock forever';
    } else if (count >= 1) {
      return '$remaining free plays left today';
    } else {
      return 'Watch ad to continue';
    }
  }

  /// Get secondary message for progressive paywall
  String getProgressiveAdSubMessage() {
    final count = getDailyAdCountSync();
    
    if (count >= maxDailyRewardedAds) {
      return 'Go Premium for unlimited access';
    } else if (count >= 3) {
      return 'Premium = No ads, all decks';
    } else {
      return '30s';
    }
  }
}
