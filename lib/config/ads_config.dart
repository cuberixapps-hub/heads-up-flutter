import 'dart:io';
import 'environment.dart';
import 'production_config.dart';

/// Central config for AdMob. IDs resolved from environment only.
class AdsConfig {
  AdsConfig._();

  static const String _testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static bool get _useTestIds => EnvironmentConfig.isDevelopment || EnvironmentConfig.isUAT;

  static String get bannerAdUnitId {
    if (_useTestIds) {
      if (Platform.isAndroid) return _testAndroidBanner;
      if (Platform.isIOS) return _testIosBanner;
    } else {
      if (Platform.isAndroid) return ProductionConfig.androidBannerAdUnitId;
      if (Platform.isIOS) return ProductionConfig.iosBannerAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (_useTestIds) {
      if (Platform.isAndroid) return _testAndroidInterstitial;
      if (Platform.isIOS) return _testIosInterstitial;
    } else {
      if (Platform.isAndroid) return ProductionConfig.androidInterstitialAdUnitId;
      if (Platform.isIOS) return ProductionConfig.iosInterstitialAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (_useTestIds) {
      if (Platform.isAndroid) return _testAndroidRewarded;
      if (Platform.isIOS) return _testIosRewarded;
    } else {
      if (Platform.isAndroid) return ProductionConfig.androidRewardedAdUnitId;
      if (Platform.isIOS) return ProductionConfig.iosRewardedAdUnitId;
    }
    throw UnsupportedError('Unsupported platform');
  }
}
