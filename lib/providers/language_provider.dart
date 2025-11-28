import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app language/locale
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  
  /// Current app locale
  Locale get locale => _locale;
  
  /// Supported locales in the app
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('es'), // Spanish
    Locale('fr'), // French
    Locale('de'), // German
    Locale('hi'), // Hindi
    Locale('ar'), // Arabic
    Locale('pt'), // Portuguese
    Locale('zh'), // Chinese (Simplified)
    Locale('ja'), // Japanese
    Locale('ko'), // Korean
    Locale('ru'), // Russian
    Locale('it'), // Italian
    Locale('nl'), // Dutch
    Locale('tr'), // Turkish
    Locale('id'), // Indonesian
    Locale('th'), // Thai
    Locale('vi'), // Vietnamese
  ];
  
  /// Map of language codes to native language names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'hi': 'हिन्दी',
    'ar': 'العربية',
    'pt': 'Português',
    'zh': '简体中文',
    'ja': '日本語',
    'ko': '한국어',
    'ru': 'Русский',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'tr': 'Türkçe',
    'id': 'Bahasa Indonesia',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
  };
  
  LanguageProvider() {
    _loadSavedLocale();
  }
  
  /// Load the saved language preference from SharedPreferences
  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('language_code');
      
      if (savedLanguageCode != null) {
        // Verify that the saved language is still supported
        if (supportedLocales.any((l) => l.languageCode == savedLanguageCode)) {
          _locale = Locale(savedLanguageCode);
          notifyListeners();
          debugPrint('✅ Loaded saved language: $savedLanguageCode');
        }
      } else {
        debugPrint('📱 Using default language: en');
      }
    } catch (e) {
      debugPrint('Error loading saved locale: $e');
      // Keep default locale
    }
  }
  
  /// Set the app locale and persist the choice
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) {
      return; // No change needed
    }
    
    // Verify the locale is supported
    if (!supportedLocales.contains(locale)) {
      debugPrint('⚠️ Unsupported locale: ${locale.languageCode}');
      return;
    }
    
    try {
      _locale = locale;
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
      
      notifyListeners();
      debugPrint('✅ Language changed to: ${locale.languageCode}');
    } catch (e) {
      debugPrint('Error saving locale: $e');
      // Revert to previous locale
      _locale = _locale;
    }
  }
  
  /// Get the native name for the current language
  String get currentLanguageName {
    return languageNames[_locale.languageCode] ?? 'English';
  }
  
  /// Get the native name for a specific language code
  static String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }
  
  /// Check if the current language is RTL (Right-to-Left)
  bool get isRTL {
    return _locale.languageCode == 'ar';
  }
}




