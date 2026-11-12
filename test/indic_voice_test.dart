import 'package:flutter_test/flutter_test.dart';
import 'package:weather_gpt/core/api/weather_api_client.dart';
import 'package:weather_gpt/core/localization/locale_service.dart';
import 'package:weather_gpt/core/voice/speech_sanitizer.dart';

void main() {
  group('LocaleService F2.2 Indic languages', () {
    test('supports all 7 expected languages including Marathi', () {
      final codes = LocaleService.supportedLanguages.map((l) => l.code).toSet();
      expect(
        codes,
        equals({'en_IN', 'hi', 'te', 'ta', 'kn', 'bn', 'mr'}),
      );
      for (final lang in LocaleService.supportedLanguages) {
        expect(lang.sampleVoicePrompts.isNotEmpty, isTrue);
        expect(lang.tapToSpeakLabel.isNotEmpty, isTrue);
      }
    });

    test('resolveLanguage matches English name, code, and BCP-47 locale', () {
      expect(LocaleService.resolveLanguage('Telugu')?.code, 'te');
      expect(LocaleService.resolveLanguage('mr-IN')?.code, 'mr');
      expect(LocaleService.resolveLanguage('mr_IN')?.code, 'mr');
      expect(LocaleService.resolveLanguage('हिन्दी')?.code, 'hi');
    });
  });

  group('SpeechSanitizer F2.2 TTS preparation', () {
    test('strips markdown/emojis and localizes units per script', () {
      final telugu = LocaleService.resolveLanguage('te')!;
      const raw = '**ఈ రోజు** వాతావరణం 29°C, గాలి 15 km/h & తేమ 70% 🌤️';
      final cleaned = SpeechSanitizer.cleanForSpeech(raw, language: telugu);

      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('🌤'), isFalse);
      expect(cleaned.contains('డిగ్రీల సెల్సియస్'), isTrue);
      expect(cleaned.contains('కిలోమీటర్లు ప్రతి గంటకు'), isTrue);
      expect(cleaned.contains('శాతం'), isTrue);
    });

    test('chunks long Devanagari text on sentence boundaries', () {
      final s1 = 'आज मुंबई में मौसम सुहावना रहेगा और तापमान 29 डिग्री सेल्सियस है।';
      final s2 = 'दोपहर में हल्की हवा चलेगी और शाम को बारिश की संभावना कम है।';
      final s3 = 'कल सुबह बुआई और खेती के काम के लिए मौसम पूरी तरह अनुकूल रहेगा।';
      final combined = '$s1 $s2 $s3';

      final chunks = SpeechSanitizer.chunkForTts(combined, maxChunkLength: 100);
      expect(chunks.length, greaterThan(1));
      expect(chunks.join(' '), equals(combined));
    });
  });

  group('ChatCompletionResult JSON parsing', () {
    test('parses voice_mode fields from backend response', () {
      final parsed = ChatCompletionResult.fromResponseJson({
        'reply': 'आज मौसम साफ रहेगा।',
        'weather_context_used': true,
        'tts_text': 'आज मौसम साफ रहेगा।',
        'detected_language': 'Hindi',
        'tts_locale': 'hi-IN',
        'stt_locale': 'hi_IN',
        'weather_data': {'temperature': 30.0},
      });

      expect(parsed.detectedLanguage, 'Hindi');
      expect(parsed.ttsLocale, 'hi-IN');
      expect(parsed.sttLocale, 'hi_IN');
      expect(parsed.ttsText, 'आज मौसम साफ रहेगा।');
      expect(parsed.weatherData?['temperature'], 30.0);
    });
  });
}
