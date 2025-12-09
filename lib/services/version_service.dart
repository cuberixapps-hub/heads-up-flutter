import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents the update status of the app
enum UpdateStatus {
  /// App is up to date
  upToDate,
  /// A soft update is available (can be dismissed)
  softUpdateAvailable,
  /// A force update is required (blocking)
  forceUpdateRequired,
}

/// Version information from Remote Config
class VersionInfo {
  final String currentVersion;
  final String minRequiredVersion;
  final String latestVersion;
  final bool forceUpdateEnabled;
  final bool softUpdateEnabled;
  final String updateMessage;
  final String updateUrlIos;
  final String updateUrlAndroid;

  VersionInfo({
    required this.currentVersion,
    required this.minRequiredVersion,
    required this.latestVersion,
    required this.forceUpdateEnabled,
    required this.softUpdateEnabled,
    required this.updateMessage,
    required this.updateUrlIos,
    required this.updateUrlAndroid,
  });

  /// Get the platform-specific store URL
  String get storeUrl {
    if (Platform.isIOS) {
      return updateUrlIos;
    } else if (Platform.isAndroid) {
      return updateUrlAndroid;
    }
    return updateUrlAndroid; // Default fallback
  }
}

/// Service to handle app version checking and force/soft updates
class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  // Remote Config Keys
  static const String _forceUpdateEnabledKey = 'force_update_enabled';
  static const String _minRequiredVersionKey = 'min_required_version';
  static const String _softUpdateEnabledKey = 'soft_update_enabled';
  static const String _latestVersionKey = 'latest_version';
  static const String _updateUrlIosKey = 'update_url_ios';
  static const String _updateUrlAndroidKey = 'update_url_android';
  static const String _updateMessageKey = 'update_message';

  String? _currentVersion;
  VersionInfo? _cachedVersionInfo;

  /// Get the current app version
  Future<String> getCurrentVersion() async {
    if (_currentVersion != null) return _currentVersion!;
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      debugPrint('📱 Current app version: $_currentVersion');
      return _currentVersion!;
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return '0.0.0';
    }
  }

  /// Get version info from Remote Config
  Future<VersionInfo> getVersionInfo() async {
    if (_cachedVersionInfo != null) return _cachedVersionInfo!;

    final remoteConfig = FirebaseRemoteConfig.instance;
    final currentVersion = await getCurrentVersion();

    _cachedVersionInfo = VersionInfo(
      currentVersion: currentVersion,
      minRequiredVersion: remoteConfig.getString(_minRequiredVersionKey),
      latestVersion: remoteConfig.getString(_latestVersionKey),
      forceUpdateEnabled: remoteConfig.getBool(_forceUpdateEnabledKey),
      softUpdateEnabled: remoteConfig.getBool(_softUpdateEnabledKey),
      updateMessage: remoteConfig.getString(_updateMessageKey),
      updateUrlIos: remoteConfig.getString(_updateUrlIosKey),
      updateUrlAndroid: remoteConfig.getString(_updateUrlAndroidKey),
    );

    debugPrint('🔍 Version Info:');
    debugPrint('   - Current: $currentVersion');
    debugPrint('   - Min Required: ${_cachedVersionInfo!.minRequiredVersion}');
    debugPrint('   - Latest: ${_cachedVersionInfo!.latestVersion}');
    debugPrint('   - Force Update Enabled: ${_cachedVersionInfo!.forceUpdateEnabled}');
    debugPrint('   - Soft Update Enabled: ${_cachedVersionInfo!.softUpdateEnabled}');

    return _cachedVersionInfo!;
  }

  /// Check if an update is required
  Future<UpdateStatus> checkUpdateStatus() async {
    try {
      final versionInfo = await getVersionInfo();

      // Check force update first
      if (versionInfo.forceUpdateEnabled &&
          versionInfo.minRequiredVersion.isNotEmpty) {
        final comparison = compareVersions(
          versionInfo.currentVersion,
          versionInfo.minRequiredVersion,
        );
        if (comparison < 0) {
          debugPrint('🚨 Force update required: ${versionInfo.currentVersion} < ${versionInfo.minRequiredVersion}');
          return UpdateStatus.forceUpdateRequired;
        }
      }

      // Check soft update
      if (versionInfo.softUpdateEnabled &&
          versionInfo.latestVersion.isNotEmpty) {
        final comparison = compareVersions(
          versionInfo.currentVersion,
          versionInfo.latestVersion,
        );
        if (comparison < 0) {
          debugPrint('📢 Soft update available: ${versionInfo.currentVersion} < ${versionInfo.latestVersion}');
          return UpdateStatus.softUpdateAvailable;
        }
      }

      debugPrint('✅ App is up to date');
      return UpdateStatus.upToDate;
    } catch (e) {
      debugPrint('Error checking update status: $e');
      return UpdateStatus.upToDate; // Fail silently, don't block user
    }
  }

  /// Compare two semantic version strings
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  int compareVersions(String v1, String v2) {
    try {
      // Remove any leading 'v' if present
      v1 = v1.replaceFirst(RegExp(r'^v'), '');
      v2 = v2.replaceFirst(RegExp(r'^v'), '');

      // Split version strings into parts
      final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      // Pad shorter list with zeros
      while (parts1.length < 3) parts1.add(0);
      while (parts2.length < 3) parts2.add(0);

      // Compare major, minor, patch
      for (int i = 0; i < 3; i++) {
        if (parts1[i] < parts2[i]) return -1;
        if (parts1[i] > parts2[i]) return 1;
      }

      return 0;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return 0;
    }
  }

  /// Open the app store for update
  Future<void> openStore() async {
    try {
      final versionInfo = await getVersionInfo();
      final urlString = versionInfo.storeUrl;

      if (urlString.isEmpty) {
        debugPrint('⚠️ Store URL is empty');
        return;
      }

      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch store URL: $urlString');
      }
    } catch (e) {
      debugPrint('Error opening store: $e');
    }
  }

  /// Clear cached version info (useful for testing or forcing refresh)
  void clearCache() {
    _cachedVersionInfo = null;
    _currentVersion = null;
  }

  /// Get default Remote Config values for version service
  static Map<String, dynamic> getRemoteConfigDefaults() {
    return {
      _forceUpdateEnabledKey: false,
      _minRequiredVersionKey: '1.0.0',
      _softUpdateEnabledKey: false,
      _latestVersionKey: '1.0.0',
      _updateUrlIosKey: '',
      _updateUrlAndroidKey: '',
      _updateMessageKey: 'A new version is available with exciting features and improvements!',
    };
  }
}



