/// Production-only configuration: AdMob and RevenueCat production IDs/keys.
/// Only read when [EnvironmentConfig.isProduction] is true.
/// Replace placeholders with real values for production builds.
/// See production_config.dart.example for a template.
class ProductionConfig {
  ProductionConfig._();

  // =============================================================================
  // ADMOB - Production ad unit IDs (Android / iOS)
  // =============================================================================
  static const String androidBannerAdUnitId = 'ca-app-pub-9565182775442262/2581191296';
  static const String androidInterstitialAdUnitId = 'ca-app-pub-9565182775442262/1463534832';
  static const String androidRewardedAdUnitId = 'ca-app-pub-9565182775442262/9150453169';

  static const String iosBannerAdUnitId = 'ca-app-pub-9565182775442262/6105503333';
  static const String iosInterstitialAdUnitId = 'ca-app-pub-9565182775442262/3834547309';
  static const String iosRewardedAdUnitId = 'ca-app-pub-9565182775442262/4433329011';

  // =============================================================================
  // REVENUECAT - Production API keys (from RevenueCat dashboard)
  // =============================================================================
  static const String androidRevenueCatApiKey = 'goog_njiWXEyTXtyetKjcZXYgnvTYZhZ';
  static const String iosRevenueCatApiKey = 'appl_PbXjMaBmSJBfezivQXCZFUlHwzA';
}
