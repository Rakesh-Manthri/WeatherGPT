import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String name;
  final String englishName;
  final String sttLocale;
  final String ttsLocale;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.englishName,
    required this.sttLocale,
    required this.ttsLocale,
  });
}

class LocaleService {
  static const String _prefKey = 'selected_language_code';

  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en_IN',
      name: 'English',
      englishName: 'English',
      sttLocale: 'en_IN',
      ttsLocale: 'en-IN',
    ),
    AppLanguage(
      code: 'hi',
      name: 'हिन्दी',
      englishName: 'Hindi',
      sttLocale: 'hi_IN',
      ttsLocale: 'hi-IN',
    ),
    AppLanguage(
      code: 'te',
      name: 'తెలుగు',
      englishName: 'Telugu',
      sttLocale: 'te_IN',
      ttsLocale: 'te-IN',
    ),
    AppLanguage(
      code: 'ta',
      name: 'தமிழ்',
      englishName: 'Tamil',
      sttLocale: 'ta_IN',
      ttsLocale: 'ta-IN',
    ),
    AppLanguage(
      code: 'kn',
      name: 'ಕನ್ನಡ',
      englishName: 'Kannada',
      sttLocale: 'kn_IN',
      ttsLocale: 'kn-IN',
    ),
    AppLanguage(
      code: 'bn',
      name: 'বাংলা',
      englishName: 'Bengali',
      sttLocale: 'bn_IN',
      ttsLocale: 'bn-IN',
    ),
  ];

  static final ValueNotifier<AppLanguage> currentLanguageNotifier =
      ValueNotifier<AppLanguage>(supportedLanguages[0]);

  static AppLanguage get currentLanguage => currentLanguageNotifier.value;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null) {
        final matched = supportedLanguages.firstWhere(
          (lang) => lang.code == savedCode,
          orElse: () => supportedLanguages[0],
        );
        currentLanguageNotifier.value = matched;
      }
    } catch (e) {
      debugPrint('Error initializing LocaleService: $e');
    }
  }

  static Future<void> setLanguage(AppLanguage language) async {
    currentLanguageNotifier.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }
}
