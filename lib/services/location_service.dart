import 'dart:io';
import 'package:flutter/foundation.dart';

class LocationService {
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
      'UNIVERSAL': 'Universal',
      'IN': 'India',
      'JP': 'Japan',
      'KR': 'South Korea',
      'BR': 'Brazil',
      'CN': 'China',
      'US': 'United States',
      'GB': 'United Kingdom',
      'MX': 'Latin America',
      'TRENDING': 'Trending',
    };
    
    return displayNames[countryCode] ?? countryCode;
  }

  /// Check if a country code is valid
  static bool isValidCountryCode(String? countryCode) {
    if (countryCode == null) return false;
    
    const validCodes = {
      'UNIVERSAL',
      'IN',
      'JP',
      'KR',
      'BR',
      'CN',
      'US',
      'GB',
      'MX',
      'TRENDING',
    };
    
    return validCodes.contains(countryCode.toUpperCase());
  }

  /// Get all supported country codes
  static List<String> getSupportedCountryCodes() {
    return [
      'UNIVERSAL',
      'IN',
      'JP',
      'KR',
      'BR',
      'CN',
      'US',
      'GB',
      'MX',
      'TRENDING',
    ];
  }
}
