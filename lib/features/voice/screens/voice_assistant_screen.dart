import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/weather_api_client.dart';
import '../../../core/localization/language_picker_sheet.dart';
import '../../../core/localization/locale_service.dart';
import '../../../core/location/location_service.dart';
import '../../../core/voice/speech_sanitizer.dart';

enum VoiceState { idle, listening, processing, speaking }

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final WeatherApiClient _apiClient = WeatherApiClient();

  VoiceState _state = VoiceState.idle;
  String _recognizedText = '';
  String _aiResponse = '';
  String _ttsText = '';
  Map<String, dynamic>? _weatherData;
  String? _detectedLanguageName;
  String _statusMessage = LocaleService.currentLanguage.tapToSpeakLabel;
  double _soundLevel = 0.0;
  bool _speechAvailable = false;
  bool _ttsVoiceAvailable = true;
  bool _continuousHandsFree = false;
  bool _isSubmittingQuery = false;
  int _ttsPlaybackToken = 0;
  List<stt.LocaleName> _deviceSttLocales = const [];
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    LocaleService.currentLanguageNotifier.addListener(_onLanguageChanged);
    _initVoiceEngine();
  }

  void _onLanguageChanged() {
    final lang = LocaleService.currentLanguage;
    _ttsPlaybackToken++;
    _flutterTts.stop();
    _configureTtsForLocale(lang.ttsLocale);
    if (_state == VoiceState.listening) {
      _speech.cancel();
    }
    if (mounted) {
      setState(() {
        _state = VoiceState.idle;
        _statusMessage = lang.tapToSpeakLabel;
      });
    }
  }

  Future<void> _configureTtsForLocale(String ttsLocale) async {
    try {
      final available = await _flutterTts.isLanguageAvailable(ttsLocale);
      final isAvail = available == true || available == 1;
      if (isAvail) {
        await _flutterTts.setLanguage(ttsLocale);
      } else {
        // Fallback to underscore variant before reverting to English India
        final altLocale = ttsLocale.replaceAll('-', '_');
        final altAvail = await _flutterTts.isLanguageAvailable(altLocale);
        if (altAvail == true || altAvail == 1) {
          await _flutterTts.setLanguage(altLocale);
        } else {
          await _flutterTts.setLanguage('en-IN');
        }
      }
      if (mounted) {
        setState(() {
          _ttsVoiceAvailable = isAvail || ttsLocale.startsWith('en');
        });
      }
    } catch (e) {
      debugPrint('Error updating TTS language ($ttsLocale): $e');
    }
  }

  String _resolveDeviceSttLocale(AppLanguage lang) {
    if (_deviceSttLocales.isEmpty) return lang.sttLocale;
    final exactNormalized = lang.sttLocale.toLowerCase().replaceAll('-', '_');
    for (final loc in _deviceSttLocales) {
      if (loc.localeId.toLowerCase().replaceAll('-', '_') == exactNormalized) {
        return loc.localeId;
      }
    }
    final prefix = '${lang.code.split('_').first.toLowerCase()}_';
    for (final loc in _deviceSttLocales) {
      final norm = loc.localeId.toLowerCase().replaceAll('-', '_');
      if (norm.startsWith(prefix)) {
        return loc.localeId;
      }
    }
    return lang.sttLocale;
  }

  Future<void> _initVoiceEngine() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _configureTtsForLocale(LocaleService.currentLanguage.ttsLocale);

      _flutterTts.setErrorHandler((msg) {
        _ttsPlaybackToken++;
        if (mounted) {
          setState(() {
            _state = VoiceState.idle;
            _statusMessage = 'Playback error: $msg';
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }

    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if ((status == 'done' || status == 'notListening') &&
              _state == VoiceState.listening &&
              !_isSubmittingQuery) {
            final pending = _recognizedText.trim();
            if (pending.isNotEmpty) {
              _processVoiceQuery(pending);
            } else if (mounted) {
              setState(() {
                _state = VoiceState.idle;
                _statusMessage = LocaleService.currentLanguage.tapToSpeakLabel;
              });
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: ${errorNotification.errorMsg}');
          if (mounted && _state == VoiceState.listening && !_isSubmittingQuery) {
            setState(() {
              _state = VoiceState.idle;
              _statusMessage = LocaleService.currentLanguage.tapToSpeakLabel;
            });
          }
        },
      );

      if (_speechAvailable) {
        _deviceSttLocales = await _speech.locales();
      }

      if (mounted) {
        setState(() {});
        if (_speechAvailable) {
          _startListening();
        }
      }
    } catch (e) {
      debugPrint('Error initializing Speech: $e');
    }
  }

  Future<void> _startListening() async {
    final lang = LocaleService.currentLanguage;
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) {
        if (mounted) {
          setState(() {
            _state = VoiceState.idle;
            _statusMessage = 'Microphone permission required';
          });
        }
        return;
      }
      _deviceSttLocales = await _speech.locales();
    }

    _ttsPlaybackToken++;
    await _flutterTts.stop();
    _isSubmittingQuery = false;

    if (mounted) {
      setState(() {
        _state = VoiceState.listening;
        _recognizedText = '';
        _aiResponse = '';
        _ttsText = '';
        _detectedLanguageName = null;
        _statusMessage = lang.listeningLabel;
      });
    }

    final sttLocaleId = _resolveDeviceSttLocale(lang);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _recognizedText = result.recognizedWords;
        });
        if (result.finalResult &&
            result.recognizedWords.trim().isNotEmpty &&
            !_isSubmittingQuery) {
          _processVoiceQuery(result.recognizedWords.trim());
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: sttLocaleId,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    final pending = _recognizedText.trim();
    if (pending.isNotEmpty && !_isSubmittingQuery) {
      await _processVoiceQuery(pending);
    } else if (mounted && _state == VoiceState.listening) {
      setState(() {
        _state = VoiceState.idle;
        _statusMessage = LocaleService.currentLanguage.tapToSpeakLabel;
      });
    }
  }

  Future<void> _speakChunked(String rawSpeechText, AppLanguage targetLang) async {
    final chunks = SpeechSanitizer.chunkForTts(rawSpeechText);
    if (chunks.isEmpty) {
      if (mounted) {
        setState(() {
          _state = VoiceState.idle;
          _statusMessage = targetLang.tapToSpeakLabel;
        });
      }
      return;
    }

    final myToken = ++_ttsPlaybackToken;
    await _configureTtsForLocale(targetLang.ttsLocale);

    if (mounted) {
      setState(() {
        _state = VoiceState.speaking;
        _statusMessage = targetLang.speakingLabel;
      });
    }

    for (final chunk in chunks) {
      if (!mounted || myToken != _ttsPlaybackToken) return;
      await _flutterTts.speak(chunk);
    }

    if (!mounted || myToken != _ttsPlaybackToken) return;

    if (_continuousHandsFree) {
      await _startListening();
    } else {
      setState(() {
        _state = VoiceState.idle;
        _statusMessage = LocaleService.currentLanguage.tapToSpeakLabel;
      });
    }
  }

  Future<void> _stopSpeaking() async {
    _ttsPlaybackToken++;
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _state = VoiceState.idle;
        _statusMessage = LocaleService.currentLanguage.tapToSpeakLabel;
      });
    }
  }

  Future<void> _processVoiceQuery(String query) async {
    if (_isSubmittingQuery || query.trim().isEmpty) return;
    _isSubmittingQuery = true;
    await _speech.stop();

    final currentLang = LocaleService.currentLanguage;
    if (mounted) {
      setState(() {
        _recognizedText = query;
        _state = VoiceState.processing;
        _statusMessage = currentLang.thinkingLabel;
      });
    }

    _saveToSupabase(query, 'user');

    try {
      Position? position;
      try {
        position = await LocationService.getCurrentPosition().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (_) {
        position = null;
      }

      final result = await _apiClient.getChatCompletionResult(
        query,
        lat: position?.latitude,
        lon: position?.longitude,
        sessionId: _sessionId,
        language: currentLang.englishName,
        voiceMode: true,
      );

      final responseLang =
          LocaleService.resolveLanguage(result.detectedLanguage) ??
              LocaleService.resolveLanguage(result.ttsLocale) ??
              currentLang;

      final cleanSpeech = (result.ttsText != null && result.ttsText!.trim().isNotEmpty)
          ? result.ttsText!.trim()
          : SpeechSanitizer.cleanForSpeech(result.reply, language: responseLang);

      if (mounted) {
        setState(() {
          _aiResponse = result.reply;
          _ttsText = cleanSpeech;
          _weatherData = result.weatherData;
          _detectedLanguageName = responseLang.name;
          _recognizedText = '';
        });

        _saveToSupabase(result.reply, 'assistant');
        await _speakChunked(cleanSpeech, responseLang);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = VoiceState.idle;
          _statusMessage = 'Error connecting to weather service';
        });
      }
    } finally {
      _isSubmittingQuery = false;
    }
  }

  Future<void> _saveToSupabase(String content, String role) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      if (_sessionId == null) {
        final res = await Supabase.instance.client
            .from('chat_sessions')
            .insert({'user_id': user.id})
            .select('id')
            .single();
        _sessionId = res['id'] as String?;
      }

      if (_sessionId != null) {
        await Supabase.instance.client.from('chat_messages').insert({
          'session_id': _sessionId,
          'role': role,
          'content': content,
        });
      }
    } catch (e) {
      debugPrint('Error saving voice message to Supabase: $e');
    }
  }

  @override
  void dispose() {
    LocaleService.currentLanguageNotifier.removeListener(_onLanguageChanged);
    _ttsPlaybackToken++;
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Widget _buildWeatherContextPill(Map<String, dynamic> weather) {
    final temp = weather['temperature'];
    final cond = weather['condition']?.toString() ?? '';
    final loc = weather['location_name']?.toString() ?? '';
    final downscale = weather['spatial_downscaling'] as Map<String, dynamic>?;
    final panchangam = weather['panchangam_fusion'] as Map<String, dynamic>?;

    final subtitleParts = <String>[
      if (loc.isNotEmpty) loc,
      if (downscale != null && downscale['microclimate_zone'] != null)
        '1km ${downscale['microclimate_zone']}'
      else if (panchangam != null && panchangam['panchangam'] != null)
        ((panchangam['panchangam'] as Map<String, dynamic>)['tithi']
                    as Map<String, dynamic>?)?['name']
                ?.toString() ??
            'Panchangam',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_outlined, size: 16, color: Color(0xFF1A73E8)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${temp != null ? '${(temp as num).round()}°C ' : ''}$cond'
              '${subtitleParts.isNotEmpty ? ' • ${subtitleParts.join(' • ')}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3A6E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = LocaleService.currentLanguage;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Bar
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: Color(0xFF5F6368)),
                    onPressed: () {
                      _ttsPlaybackToken++;
                      _speech.stop();
                      _flutterTts.stop();
                      Navigator.pop(context);
                    },
                  ),

                  // Interactive Language Selector Pill
                  ValueListenableBuilder<AppLanguage>(
                    valueListenable: LocaleService.currentLanguageNotifier,
                    builder: (context, lang, _) {
                      return GestureDetector(
                        onTap: () => LanguagePickerSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.translate_rounded, size: 16, color: Color(0xFF5F6368)),
                              const SizedBox(width: 6),
                              Text(
                                lang.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF5F6368)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Continuous Hands-Free Mode Toggle + Mute
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: _continuousHandsFree
                            ? 'Hands-free loop ON'
                            : 'Hands-free loop OFF',
                        child: IconButton(
                          icon: Icon(
                            Icons.loop_rounded,
                            size: 22,
                            color: _continuousHandsFree
                                ? const Color(0xFF1A73E8)
                                : const Color(0xFF9AA0A6),
                          ),
                          onPressed: () {
                            setState(() {
                              _continuousHandsFree = !_continuousHandsFree;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _state == VoiceState.speaking
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 24,
                          color: const Color(0xFF5F6368),
                        ),
                        onPressed: () {
                          if (_state == VoiceState.speaking) {
                            _stopSpeaking();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Central Animated Particle Cloud & Text Content
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 105),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Cloud with state-reactive behavior
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: _VoiceAnimatedParticleCloud(
                        voiceState: _state,
                        soundLevel: _soundLevel,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Text
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'serif',
                        color: _state == VoiceState.listening
                            ? const Color(0xFF1A73E8)
                            : const Color(0xFF5F6368),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    if (!_ttsVoiceAvailable) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${currentLang.name} offline TTS voice pack missing on device — using fallback',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A5300),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    if (_weatherData != null && _recognizedText.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildWeatherContextPill(_weatherData!),
                      ),

                    // Real-time Spoken Words / AI Response / Vernacular Prompt Chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 165),
                        child: SingleChildScrollView(
                          child: _recognizedText.isNotEmpty
                              ? Text(
                                  '“$_recognizedText”',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: Color(0xFF202124),
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : _aiResponse.isNotEmpty
                                  ? Column(
                                      children: [
                                        if (_detectedLanguageName != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              'Voice • $_detectedLanguageName',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A73E8),
                                              ),
                                            ),
                                          ),
                                        MarkdownBody(
                                          data: _aiResponse,
                                          styleSheet: MarkdownStyleSheet(
                                            p: const TextStyle(
                                              fontSize: 15,
                                              height: 1.45,
                                              color: Color(0xFF202124),
                                            ),
                                            strong: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF202124),
                                            ),
                                            listBullet: const TextStyle(
                                              color: Color(0xFF202124),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: currentLang.sampleVoicePrompts.map((prompt) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: ActionChip(
                                            backgroundColor: const Color(0xFFF7F9FC),
                                            side: const BorderSide(color: Color(0xFFE3EAF4)),
                                            avatar: const Icon(
                                              Icons.graphic_eq_rounded,
                                              size: 16,
                                              color: Color(0xFF1A73E8),
                                            ),
                                            label: Text(
                                              prompt,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF202124),
                                              ),
                                            ),
                                            onPressed: () => _processVoiceQuery(prompt),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls Area
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Close Button
                    _VoiceCircleBtn(
                      onPressed: () {
                        _ttsPlaybackToken++;
                        _speech.stop();
                        _flutterTts.stop();
                        Navigator.of(context).pop();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: Color(0xFF202124),
                      ),
                    ),

                    // Main Microphone Trigger Button (interrupts speech & starts listening)
                    _VoiceCircleBtn(
                      isPrimary: true,
                      onPressed: () {
                        if (_state == VoiceState.listening) {
                          _stopListening();
                        } else if (_state != VoiceState.processing) {
                          _startListening();
                        }
                      },
                      child: Icon(
                        _state == VoiceState.listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        size: 30,
                        color: _state == VoiceState.listening
                            ? const Color(0xFF6BC4FF)
                            : Colors.white,
                      ),
                    ),

                    // Stop Speaking / Replay Button
                    _VoiceCircleBtn(
                      onPressed: () {
                        if (_state == VoiceState.speaking) {
                          _stopSpeaking();
                        } else if (_ttsText.isNotEmpty || _aiResponse.isNotEmpty) {
                          final replayLang = LocaleService.resolveLanguage(_detectedLanguageName) ??
                              LocaleService.currentLanguage;
                          final textToSpeak = _ttsText.isNotEmpty
                              ? _ttsText
                              : SpeechSanitizer.cleanForSpeech(_aiResponse, language: replayLang);
                          _speakChunked(textToSpeak, replayLang);
                        }
                      },
                      child: Icon(
                        _state == VoiceState.speaking ? Icons.stop_rounded : Icons.replay_rounded,
                        size: 24,
                        color: const Color(0xFF202124),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _VoiceCircleBtn({
    required this.child,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isPrimary ? 80 : 64,
      height: isPrimary ? 80 : 64,
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF1C1C1E) : const Color(0xFFF1F3F4),
        shape: BoxShape.circle,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Exact SDF Cloud Particle System matching HTML/Canvas specification
/// Features: Pill base, multi-lobe SDF puffs, sharp border contours,
/// diffuse aura, harmonic floating drift, spring physics, touch repel, and voice reactivity.
class _VoiceAnimatedParticleCloud extends StatefulWidget {
  final VoiceState voiceState;
  final double soundLevel;

  const _VoiceAnimatedParticleCloud({
    required this.voiceState,
    this.soundLevel = 0.0,
  });

  @override
  State<_VoiceAnimatedParticleCloud> createState() => _VoiceAnimatedParticleCloudState();
}

class _VoiceAnimatedParticleCloudState extends State<_VoiceAnimatedParticleCloud>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  final List<_SdfCloudParticle> _particles = [];
  static const int _particleCount = 4200;
  Offset? _touchPos;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _ticker = createTicker((elapsed) {
      setState(() {
        _elapsed = elapsed;
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Smooth minimum function for organic SDF union
  static double _smin(double a, double b, [double k = 22.0]) {
    final double h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / k));
    return b * (1.0 - h) + a * h - k * h * (1.0 - h);
  }

  // Distance from point (px, py) to line segment (ax, ay)-(bx, by)
  static double _distSegment(double px, double py, double ax, double ay, double bx, double by) {
    final double pax = px - ax, pay = py - ay;
    final double bax = bx - ax, bay = by - ay;
    final double lenSq = bax * bax + bay * bay;
    final double h = max(0.0, min(1.0, (pax * bax + pay * bay) / (lenSq == 0 ? 1.0 : lenSq)));
    final double dx = pax - bax * h;
    final double dy = pay - bay * h;
    return sqrt(dx * dx + dy * dy);
  }

  // Signed Distance Field (SDF) of the cloud silhouette
  static double _cloudSDF(double x, double y) {
    // Pill base
    final double dBase = _distSegment(x, y, -95.0, 28.0, 105.0, 28.0) - 38.0;

    // Cloud puffs (overlapping spheres)
    final double dTop = sqrt((x - (-12.0)) * (x - (-12.0)) + (y - (-45.0)) * (y - (-45.0))) - 70.0;     // Big central dome
    final double dLeft = sqrt((x - (-95.0)) * (x - (-95.0)) + (y - 2.0) * (y - 2.0)) - 52.0;           // Left puff
    final double dRight = sqrt((x - 70.0) * (x - 70.0) + (y - (-18.0)) * (y - (-18.0))) - 48.0;         // Right puff
    final double dFarRight = sqrt((x - 122.0) * (x - 122.0) + (y - 22.0) * (y - 22.0)) - 38.0;         // Lower-right bump
    final double dFill1 = sqrt((x - (-45.0)) * (x - (-45.0)) + (y - 10.0) * (y - 10.0)) - 58.0;         // Body fill
    final double dFill2 = sqrt((x - 40.0) * (x - 40.0) + (y - 15.0) * (y - 15.0)) - 54.0;               // Body fill

    double d = _smin(dBase, dTop, 25.0);
    d = _smin(d, dLeft, 22.0);
    d = _smin(d, dRight, 22.0);
    d = _smin(d, dFarRight, 18.0);
    d = _smin(d, dFill1, 25.0);
    d = _smin(d, dFill2, 25.0);

    return d;
  }

  void _initParticles() {
    _particles.clear();
    final random = Random();
    const double minX = -180.0, maxX = 180.0;
    const double minY = -135.0, maxY = 95.0;

    while (_particles.length < _particleCount) {
      final double rx = minX + random.nextDouble() * (maxX - minX);
      final double ry = minY + random.nextDouble() * (maxY - minY);
      final double d = _cloudSDF(rx, ry);

      // Downward dispersion bias at the base (rain/mist vapor trail)
      double vertBias = 0.0;
      if (ry > 15.0 && rx.abs() < 120.0 && d > 0.0) {
        vertBias = (ry - 15.0) * 0.4;
      }
      final double effectiveD = d - vertBias;

      double acceptanceProb = 0.0;
      if (effectiveD < -10.0) {
        // Interior cloud body
        acceptanceProb = 0.28;
      } else if (effectiveD >= -10.0 && effectiveD <= 8.0) {
        // Sharp border contour
        acceptanceProb = 0.95;
      } else if (effectiveD > 8.0 && effectiveD < 55.0) {
        // Outer diffuse aura
        acceptanceProb = 0.95 * exp(-pow((effectiveD - 8.0) / 18.0, 1.4));
      }

      if (random.nextDouble() < acceptanceProb) {
        // Optical properties based on density distance
        final bool isBorder = effectiveD.abs() < 8.0;
        final double size = (isBorder ? 1.0 : 0.8) + random.nextDouble() * 1.2;

        // Blue palette matching the UI
        const hues = [
          Color(0xFF3498DB), // Vibrant sky blue
          Color(0xFF2980B9), // Deep blue
          Color(0xFF4AA3DF), // Medium cyan-blue
          Color(0xFF6BC4FF), // Bright light blue
        ];
        final color = hues[random.nextInt(hues.length)];

        // Outer mist fades out; boundary is crisp and opaque
        double alpha = 0.75;
        if (effectiveD > 0.0) {
          alpha = max(0.15, 0.85 - (effectiveD / 45.0));
        } else {
          alpha = 0.45 + random.nextDouble() * 0.4;
        }

        _particles.add(
          _SdfCloudParticle(
            baseX: rx,
            baseY: ry,
            x: rx,
            y: ry,
            vx: (random.nextDouble() - 0.5) * 0.5,
            vy: (random.nextDouble() - 0.5) * 0.5,
            speed: 0.8 + random.nextDouble() * 1.5,
            phaseX: random.nextDouble() * 2 * pi,
            phaseY: random.nextDouble() * 2 * pi,
            ampX: 1.5 + random.nextDouble() * 3.5,
            ampY: 1.5 + random.nextDouble() * 3.5,
            size: size,
            color: color,
            baseAlpha: alpha,
            alphaPulse: random.nextDouble() * 2 * pi,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double time = _elapsed.inMicroseconds / 1000000.0;

    return Listener(
      onPointerDown: (e) => setState(() => _touchPos = e.localPosition),
      onPointerMove: (e) => setState(() => _touchPos = e.localPosition),
      onPointerUp: (_) => setState(() => _touchPos = null),
      onPointerCancel: (_) => setState(() => _touchPos = null),
      child: CustomPaint(
        painter: _SdfCloudPainter(
          particles: _particles,
          time: time,
          voiceState: widget.voiceState,
          soundLevel: widget.soundLevel,
          touchPos: _touchPos,
        ),
      ),
    );
  }
}

class _SdfCloudParticle {
  final double baseX;
  final double baseY;
  double x;
  double y;
  double vx;
  double vy;
  final double speed;
  final double phaseX;
  final double phaseY;
  final double ampX;
  final double ampY;
  final double size;
  final Color color;
  final double baseAlpha;
  final double alphaPulse;

  _SdfCloudParticle({
    required this.baseX,
    required this.baseY,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.speed,
    required this.phaseX,
    required this.phaseY,
    required this.ampX,
    required this.ampY,
    required this.size,
    required this.color,
    required this.baseAlpha,
    required this.alphaPulse,
  });
}

class _SdfCloudPainter extends CustomPainter {
  final List<_SdfCloudParticle> particles;
  final double time;
  final VoiceState voiceState;
  final double soundLevel;
  final Offset? touchPos;

  static final Paint _paint = Paint()..style = PaintingStyle.fill;

  _SdfCloudPainter({
    required this.particles,
    required this.time,
    required this.voiceState,
    required this.soundLevel,
    this.touchPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    // Scale responsive to size
    final double scale = min(size.width / 380.0, size.height / 480.0) * 0.96;

    // Subtle global breathing effect
    double breath = 1.0 + sin(time * 1.4) * 0.012;

    // Voice State dynamic modifiers
    final double soundNorm = min(soundLevel / 80.0, 1.0);
    if (voiceState == VoiceState.listening) {
      breath += soundNorm * 0.12;
    }

    const double mouseRadius = 80.0;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Scaled target position
      final double targetX = centerX + (p.baseX * scale * breath);
      final double targetY = centerY + (p.baseY * scale * breath);

      // Natural floating drift
      double driftX = sin(time * p.speed + p.phaseX) * p.ampX * (scale / 1.5);
      double driftY = cos(time * p.speed + p.phaseY) * p.ampY * (scale / 1.5);

      // Voice state motion overlays
      switch (voiceState) {
        case VoiceState.listening:
          driftX += (p.baseX / 100.0) * soundNorm * 10.0;
          driftY += (p.baseY / 100.0) * soundNorm * 10.0;
          break;
        case VoiceState.processing:
          final double orbitT = time * 2.0 + p.phaseX;
          driftX += cos(orbitT) * 3.5;
          driftY += sin(orbitT) * 2.5;
          break;
        case VoiceState.speaking:
          final double dist = sqrt(p.baseX * p.baseX + p.baseY * p.baseY);
          final double ripple = sin(time * 7.0 - dist * 0.06) * 3.5;
          final double angle = atan2(p.baseY, p.baseX);
          driftX += cos(angle) * ripple;
          driftY += sin(angle) * ripple;
          break;
        case VoiceState.idle:
          break;
      }

      final double destX = targetX + driftX;
      final double destY = targetY + driftY;

      // Mouse / Touch repel interaction
      if (touchPos != null) {
        final double dx = p.x - touchPos!.dx;
        final double dy = p.y - touchPos!.dy;
        final double dist = sqrt(dx * dx + dy * dy);

        if (dist < mouseRadius && dist > 0.0) {
          final double force = (1.0 - dist / mouseRadius) * 12.0;
          p.vx += (dx / dist) * force;
          p.vy += (dy / dist) * force;
        }
      }

      // Spring back to target (physics integration)
      p.vx += (destX - p.x) * 0.06;
      p.vy += (destY - p.y) * 0.06;
      p.vx *= 0.82;
      p.vy *= 0.82;

      p.x += p.vx;
      p.y += p.vy;

      // Gentle opacity shimmer
      double currentAlpha = max(
        0.05,
        p.baseAlpha + sin(time * 2.5 + p.alphaPulse) * 0.15,
      );

      if (voiceState == VoiceState.listening) {
        currentAlpha = min(1.0, currentAlpha + soundNorm * 0.2);
      }

      _paint.color = p.color.withValues(alpha: currentAlpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SdfCloudPainter oldDelegate) => true;
}
