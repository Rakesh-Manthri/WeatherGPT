import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String name;
  final String englishName;
  final String sttLocale;
  final String ttsLocale;
  final String tapToSpeakLabel;
  final String listeningLabel;
  final String thinkingLabel;
  final String speakingLabel;
  final List<String> sampleVoicePrompts;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.englishName,
    required this.sttLocale,
    required this.ttsLocale,
    required this.tapToSpeakLabel,
    required this.listeningLabel,
    required this.thinkingLabel,
    required this.speakingLabel,
    required this.sampleVoicePrompts,
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
      tapToSpeakLabel: 'Tap microphone to speak',
      listeningLabel: 'Listening...',
      thinkingLabel: 'Checking microclimate...',
      speakingLabel: 'Speaking...',
      sampleVoicePrompts: [
        'How is the hyperlocal weather and AQI right now?',
        'Is tomorrow good for farming or outdoor travel?',
      ],
    ),
    AppLanguage(
      code: 'hi',
      name: 'हिन्दी',
      englishName: 'Hindi',
      sttLocale: 'hi_IN',
      ttsLocale: 'hi-IN',
      tapToSpeakLabel: 'बोलने के लिए माइक दबाएं',
      listeningLabel: 'सुन रहा हूँ...',
      thinkingLabel: 'मौसम की जाँच हो रही है...',
      speakingLabel: 'बोल रहा हूँ...',
      sampleVoicePrompts: [
        'आज मेरे इलाके में मौसम और हवा की गुणवत्ता कैसी है?',
        'क्या कल बुआई के लिए शुभ मुहूर्त और मौसम ठीक है?',
      ],
    ),
    AppLanguage(
      code: 'te',
      name: 'తెలుగు',
      englishName: 'Telugu',
      sttLocale: 'te_IN',
      ttsLocale: 'te-IN',
      tapToSpeakLabel: 'మాట్లాడటానికి మైక్ నొక్కండి',
      listeningLabel: 'వింటున్నాను...',
      thinkingLabel: 'వాతావరణ వివరాలు చూస్తున్నాను...',
      speakingLabel: 'చెబుతున్నాను...',
      sampleVoicePrompts: [
        'ఈ రోజు మా ప్రాంతంలో వాతావరణం ఎలా ఉంది?',
        'రేపు పంట నాట్లు వేయడానికి తిథి, వర్షం అనుకూలంగా ఉన్నాయా?',
      ],
    ),
    AppLanguage(
      code: 'ta',
      name: 'தமிழ்',
      englishName: 'Tamil',
      sttLocale: 'ta_IN',
      ttsLocale: 'ta-IN',
      tapToSpeakLabel: 'பேச மைக்கைத் தட்டவும்',
      listeningLabel: 'கேட்கிறேன்...',
      thinkingLabel: 'வானிலை சரிபார்க்கப்படுகிறது...',
      speakingLabel: 'பேசுகிறேன்...',
      sampleVoicePrompts: [
        'இன்று எங்கள் பகுதியில் வானிலை மற்றும் காற்றின் தரம் எப்படி உள்ளது?',
        'நாளை பயிர் விதைப்புக்கு நல்ல நேரமும் வானிலையும் உள்ளதா?',
      ],
    ),
    AppLanguage(
      code: 'kn',
      name: 'ಕನ್ನಡ',
      englishName: 'Kannada',
      sttLocale: 'kn_IN',
      ttsLocale: 'kn-IN',
      tapToSpeakLabel: 'ಮಾತನಾಡಲು ಮೈಕ್ ಒತ್ತಿರಿ',
      listeningLabel: 'ಕೇಳುತ್ತಿದ್ದೇನೆ...',
      thinkingLabel: 'ಹವಾಮಾನ ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...',
      speakingLabel: 'ಹೇಳುತ್ತಿದ್ದೇನೆ...',
      sampleVoicePrompts: [
        'ಇಂದು ನಮ್ಮ ಪ್ರದೇಶದಲ್ಲಿ ಹವಾಮಾನ ಮತ್ತು ಗಾಳಿಯ ಗುಣಮಟ್ಟ ಹೇಗಿದೆ?',
        'ನಾಳೆ ಬಿತ್ತನೆ ಮಾಡಲು ಶುಭ ಮುಹೂರ್ತ ಮತ್ತು ಮಳೆ ಹೇಗಿದೆ?',
      ],
    ),
    AppLanguage(
      code: 'bn',
      name: 'বাংলা',
      englishName: 'Bengali',
      sttLocale: 'bn_IN',
      ttsLocale: 'bn-IN',
      tapToSpeakLabel: 'কথা বলতে মাইক চাপুন',
      listeningLabel: 'শুনছি...',
      thinkingLabel: 'আবহাওয়া দেখা হচ্ছে...',
      speakingLabel: 'বলছি...',
      sampleVoicePrompts: [
        'আজ আমার এলাকার আবহাওয়া ও বাতাসের মান কেমন?',
        'আগামীকাল চাষাবাদের জন্য শুভ সময় ও আবহাওয়া কেমন থাকবে?',
      ],
    ),
    AppLanguage(
      code: 'mr',
      name: 'मराठी',
      englishName: 'Marathi',
      sttLocale: 'mr_IN',
      ttsLocale: 'mr-IN',
      tapToSpeakLabel: 'बोलण्यासाठी माइक दाबा',
      listeningLabel: 'ऐकत आहे...',
      thinkingLabel: 'हवामान तपासत आहे...',
      speakingLabel: 'सांगत आहे...',
      sampleVoicePrompts: [
        'आज माझ्या परिसरातील हवामान आणि हवेची गुणवत्ता कशी आहे?',
        'उद्या पेरणीसाठी शुभ मुहूर्त आणि पावसाचा अंदाज कसा आहे?',
      ],
    ),
  ];

  static final ValueNotifier<AppLanguage> currentLanguageNotifier =
      ValueNotifier<AppLanguage>(supportedLanguages[0]);

  static AppLanguage get currentLanguage => currentLanguageNotifier.value;

  static AppLanguage? resolveLanguage(String? identifier) {
    if (identifier == null || identifier.trim().isEmpty) return null;
    final key = identifier.trim().toLowerCase().replaceAll('_', '-');
    for (final lang in supportedLanguages) {
      if (lang.code.toLowerCase().replaceAll('_', '-') == key ||
          lang.englishName.toLowerCase() == key ||
          lang.name.toLowerCase() == key ||
          lang.ttsLocale.toLowerCase() == key) {
        return lang;
      }
    }
    return null;
  }

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
