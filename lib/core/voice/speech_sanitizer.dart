import '../localization/locale_service.dart';

class SpeechSanitizer {
  static final RegExp _codeBlockRe = RegExp(r'```[\s\S]*?```');
  static final RegExp _mdLinkRe = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  static final RegExp _urlRe = RegExp(r'https?://\S+');
  static final RegExp _inlineCodeRe = RegExp(r'`([^`]*)`');
  static final RegExp _bulletRe = RegExp(r'^\s*(?:[-•*]|\d+\.)\s+', multiLine: true);
  static final RegExp _mdDecorRe = RegExp(r'[*#>~|]+|(?<!\w)_|_(?!\w)');
  static final RegExp _emojiRe = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]+',
    unicode: true,
  );

  static String cleanForSpeech(String rawText, {AppLanguage? language}) {
    if (rawText.trim().isEmpty) return '';
    final lang = language ?? LocaleService.currentLanguage;

    final unitMap = _unitLabels(lang.code);
    var cleaned = rawText
        .replaceAll(_codeBlockRe, ' ')
        .replaceAllMapped(_mdLinkRe, (m) => m.group(1) ?? '')
        .replaceAll(_urlRe, '')
        .replaceAllMapped(_inlineCodeRe, (m) => m.group(1) ?? '')
        .replaceAll(_bulletRe, '')
        .replaceAll(_emojiRe, '')
        .replaceAll(_mdDecorRe, '');

    cleaned = cleaned
        .replaceAll(RegExp(r'\s*°\s*[Cc]\b'), unitMap['degC']!)
        .replaceAll(RegExp(r'\s*°\s*[Ff]\b'), ' degrees Fahrenheit')
        .replaceAll(
          RegExp(r'\s*km\s*/\s*h\b', caseSensitive: false),
          unitMap['kmh']!,
        )
        .replaceAll(
          RegExp(r'\s*kmph\b', caseSensitive: false),
          unitMap['kmh']!,
        )
        .replaceAllMapped(
          RegExp(r'(\d)\s*%'),
          (m) => '${m.group(1)}${unitMap['pct']!}',
        )
        .replaceAll(' & ', unitMap['and']!);

    final lines = cleaned
        .split(RegExp(r'\r?\n+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) {
          final lastChar = l[l.length - 1];
          if ('.!?।'.contains(lastChar)) return l;
          return '$l.';
        })
        .toList();

    return lines.join(' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Split longer vernacular replies into sentence-aligned chunks so Android TTS
  /// engines never drop or truncate multi-sentence weather briefings.
  static List<String> chunkForTts(String text, {int maxChunkLength = 320}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= maxChunkLength) return [trimmed];

    final sentences = trimmed.split(RegExp(r'(?<=[.!?।])\s+'));
    final chunks = <String>[];
    final current = StringBuffer();

    for (final sentence in sentences) {
      if (current.isEmpty) {
        current.write(sentence);
      } else if (current.length + 1 + sentence.length <= maxChunkLength) {
        current.write(' ');
        current.write(sentence);
      } else {
        chunks.add(current.toString().trim());
        current.clear();
        current.write(sentence);
      }
    }
    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }
    return chunks;
  }

  static Map<String, String> _unitLabels(String code) {
    switch (code) {
      case 'hi':
        return const {
          'degC': ' डिग्री सेल्सियस',
          'kmh': ' किलोमीटर प्रति घंटा',
          'pct': ' प्रतिशत',
          'and': ' और ',
        };
      case 'te':
        return const {
          'degC': ' డిగ్రీల సెల్సియస్',
          'kmh': ' కిలోమీటర్లు ప్రతి గంటకు',
          'pct': ' శాతం',
          'and': ' మరియు ',
        };
      case 'ta':
        return const {
          'degC': ' டிகிரி செல்சியஸ்',
          'kmh': ' கிலோமீட்டர் வேகம்',
          'pct': ' சதவீதம்',
          'and': ' மற்றும் ',
        };
      case 'kn':
        return const {
          'degC': ' ಡಿಗ್ರಿ ಸೆಲ್ಸಿಯಸ್',
          'kmh': ' ಕಿಲೋಮೀಟರ್ ಪ್ರತಿ ಗಂಟೆಗೆ',
          'pct': ' ಪ್ರತಿಶತ',
          'and': ' ಮತ್ತು ',
        };
      case 'bn':
        return const {
          'degC': ' ডিগ্রি সেলসিয়াস',
          'kmh': ' কিলোমিটার প্রতি ঘণ্টা',
          'pct': ' শতাংশ',
          'and': ' এবং ',
        };
      case 'mr':
        return const {
          'degC': ' अंश सेल्सिअस',
          'kmh': ' किलोमीटर प्रति तास',
          'pct': ' टक्के',
          'and': ' आणि ',
        };
      default:
        return const {
          'degC': ' degrees Celsius',
          'kmh': ' kilometers per hour',
          'pct': ' percent',
          'and': ' and ',
        };
    }
  }
}
