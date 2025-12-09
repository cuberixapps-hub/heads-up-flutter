import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  // SharedPreferences keys
  static const String _manualCountryOverrideKey = 'manual_country_override';
  static const String _detectedCountryKey = 'detected_country';
  
  // Cached values
  String? _cachedDetectedCountry;
  String? _cachedManualOverride;
  bool _initialized = false;
  
  static const Map<String, String> _countryCodeMapping = {
    // Direct mappings
    'US': 'US',
    'IN': 'IN',
    'JP': 'JP',
    'KR': 'KR',
    'BR': 'BR',
    'CN': 'CN',
    'GB': 'GB',
    'MX': 'MX',
    // Additional mappings for common locales
    'CA': 'US', // Canada -> US content
    'AU': 'GB', // Australia -> UK content
    'NZ': 'GB', // New Zealand -> UK content
    'AR': 'MX', // Argentina -> Latin America content
    'CO': 'MX', // Colombia -> Latin America content
    'CL': 'MX', // Chile -> Latin America content
    'PE': 'MX', // Peru -> Latin America content
    'VE': 'MX', // Venezuela -> Latin America content
    'ES': 'MX', // Spain -> Latin America content (Spanish content)
    'FR': 'US', // France -> Universal/US content
    'DE': 'US', // Germany -> Universal/US content
    'IT': 'US', // Italy -> Universal/US content
    'RU': 'US', // Russia -> Universal/US content
    'PH': 'US', // Philippines -> US content
    'TH': 'US', // Thailand -> US content
    'ID': 'US', // Indonesia -> US content
    'MY': 'US', // Malaysia -> US content
    'SG': 'US', // Singapore -> US content
    'VN': 'US', // Vietnam -> US content
    'TW': 'CN', // Taiwan -> Chinese content
    'HK': 'CN', // Hong Kong -> Chinese content
    'PT': 'BR', // Portugal -> Brazilian Portuguese content
  };

  /// Initialize the location service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedManualOverride = prefs.getString(_manualCountryOverrideKey);
      _cachedDetectedCountry = prefs.getString(_detectedCountryKey);
      _initialized = true;
      debugPrint('LocationService: Initialized (override: $_cachedManualOverride, detected: $_cachedDetectedCountry)');
    } catch (e) {
      debugPrint('LocationService: Error initializing: $e');
    }
  }

  /// Get the user's preferred country (manual override takes precedence)
  Future<String> getUserPreferredCountry() async {
    await initialize();
    
    // Check for manual override first
    if (_cachedManualOverride != null && _cachedManualOverride!.isNotEmpty) {
      debugPrint('LocationService: Using manual override: $_cachedManualOverride');
      return _cachedManualOverride!;
    }
    
    // Fall back to auto-detected country
    return await detectUserCountry();
  }

  /// Set manual country override
  Future<bool> setManualCountryOverride(String? countryCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (countryCode == null || countryCode.isEmpty) {
        // Clear the override
        await prefs.remove(_manualCountryOverrideKey);
        _cachedManualOverride = null;
        debugPrint('LocationService: Cleared manual country override');
      } else {
        // Set the override
        await prefs.setString(_manualCountryOverrideKey, countryCode.toUpperCase());
        _cachedManualOverride = countryCode.toUpperCase();
        debugPrint('LocationService: Set manual country override to: $countryCode');
      }
      
      return true;
    } catch (e) {
      debugPrint('LocationService: Error setting manual override: $e');
      return false;
    }
  }

  /// Get the current manual override (null if auto-detecting)
  String? getManualCountryOverride() {
    return _cachedManualOverride;
  }

  /// Check if using manual override
  bool isUsingManualOverride() {
    return _cachedManualOverride != null && _cachedManualOverride!.isNotEmpty;
  }

  /// Detect user's country from device locale
  static Future<String> detectUserCountry() async {
    try {
      // Get the device locale
      final String locale = Platform.localeName; // e.g., "en_US", "hi_IN", "ja_JP"
      debugPrint('LocationService: Detected locale: $locale');

      // Extract country code from locale
      final List<String> parts = locale.split('_');
      if (parts.length >= 2) {
        final String countryCode = parts.last.toUpperCase();
        debugPrint('LocationService: Extracted country code: $countryCode');

        // Map to our supported regions
        final String mappedCountry = _mapCountryCode(countryCode);
        debugPrint('LocationService: Mapped to region: $mappedCountry');
        
        return mappedCountry;
      }

      // If we can't parse the locale, default to US
      debugPrint('LocationService: Could not parse locale, defaulting to US');
      return 'US';
    } catch (e) {
      debugPrint('LocationService: Error detecting country: $e');
      return 'US'; // Default to US on error
    }
  }

  /// Map country code to our supported regions
  static String _mapCountryCode(String code) {
    final upperCode = code.toUpperCase();
    return _countryCodeMapping[upperCode] ?? 'US';
  }

  /// Get the display name for a country code
  static String getCountryDisplayName(String countryCode) {
    const Map<String, String> displayNames = {
      'UNIVERSAL': 'Universal (All Regions)',
      'IN': 'India 🇮🇳',
      'JP': 'Japan 🇯🇵',
      'KR': 'South Korea 🇰🇷',
      'BR': 'Brazil 🇧🇷',
      'CN': 'China 🇨🇳',
      'US': 'United States 🇺🇸',
      'GB': 'United Kingdom 🇬🇧',
      'MX': 'Latin America 🌎',
      'CA': 'Canada 🇨🇦',
      'AU': 'Australia 🇦🇺',
      'FR': 'France 🇫🇷',
      'DE': 'Germany 🇩🇪',
      'ES': 'Spain 🇪🇸',
      'IT': 'Italy 🇮🇹',
      'TRENDING': 'Trending 🔥',
    };
    
    return displayNames[countryCode] ?? countryCode;
  }
  
  /// Get country emoji flag
  static String getCountryFlag(String countryCode) {
    const Map<String, String> flags = {
      'UNIVERSAL': '🌍',
      'IN': '🇮🇳',
      'JP': '🇯🇵',
      'KR': '🇰🇷',
      'BR': '🇧🇷',
      'CN': '🇨🇳',
      'US': '🇺🇸',
      'GB': '🇬🇧',
      'MX': '🇲🇽',
      'CA': '🇨🇦',
      'AU': '🇦🇺',
      'FR': '🇫🇷',
      'DE': '🇩🇪',
      'ES': '🇪🇸',
      'IT': '🇮🇹',
      'TRENDING': '🔥',
    };
    
    return flags[countryCode] ?? '🌐';
  }

  /// Check if a country code is valid
  static bool isValidCountryCode(String? countryCode) {
    if (countryCode == null) return false;
    
    return getSupportedCountryCodes().contains(countryCode.toUpperCase());
  }

  /// Get all supported country codes for user selection
  static List<String> getSupportedCountryCodes() {
    return [
      'US',
      'GB',
      'IN',
      'JP',
      'KR',
      'BR',
      'CN',
      'MX',
      'CA',
      'AU',
      'FR',
      'DE',
      'ES',
      'IT',
    ];
  }
  
  /// Get all country options with display names for UI
  static List<Map<String, String>> getCountryOptions() {
    return getSupportedCountryCodes().map((code) => {
      'code': code,
      'name': getCountryDisplayName(code),
      'flag': getCountryFlag(code),
    }).toList();
  }
}
