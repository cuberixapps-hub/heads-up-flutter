import 'dart:io';
import 'environment.dart';
import 'production_config.dart';

/// Central config for RevenueCat. API key resolved from environment only.
class PurchaseConfig {
  PurchaseConfig._();

  static const String _androidSandboxApiKey = 'goog_njiWXEyTXtyetKjcZXYgnvTYZhZ';
  static const String _iosSandboxApiKey = 'appl_PbXjMaBmSJBfezivQXCZFUlHwzA';

  static bool get _useSandbox => EnvironmentConfig.isDevelopment || EnvironmentConfig.isUAT;

  static String get apiKey {
    if (_useSandbox) {
      return Platform.isIOS ? _iosSandboxApiKey : _androidSandboxApiKey;
    }
    return Platform.isIOS
        ? ProductionConfig.iosRevenueCatApiKey
        : ProductionConfig.androidRevenueCatApiKey;
  }

  static bool get isPlaceholder =>
      apiKey.startsWith('YOUR_') || apiKey.isEmpty;
}
