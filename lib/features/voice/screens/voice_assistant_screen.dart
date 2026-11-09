import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/weather_api_client.dart';
import '../../../core/location/location_service.dart';
import '../../../core/localization/locale_service.dart';
import '../../../core/localization/language_picker_sheet.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
  String _statusMessage = 'Tap microphone to speak';
  double _soundLevel = 0.0;
  bool _speechAvailable = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _initVoiceEngine();
    LocaleService.currentLanguageNotifier.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    _updateTtsLanguage();
    if (_state == VoiceState.listening) {
      _stopListening();
    }
  }

  Future<void> _updateTtsLanguage() async {
    try {
      await _flutterTts.setLanguage(LocaleService.currentLanguage.ttsLocale);
    } catch (e) {
      debugPrint('Error updating TTS language: $e');
    }
  }

  Future<void> _initVoiceEngine() async {
    // 1. Initialize TTS
    try {
      await _updateTtsLanguage();
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _state = VoiceState.idle;
            _statusMessage = 'Tap microphone to speak';
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
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

    // 2. Initialize STT
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_state == VoiceState.listening && _recognizedText.trim().isNotEmpty) {
              _processVoiceQuery(_recognizedText.trim());
            } else if (_state == VoiceState.listening) {
              setState(() {
                _state = VoiceState.idle;
                _statusMessage = 'Tap microphone to speak';
              });
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: ${errorNotification.errorMsg}');
          if (mounted && _state == VoiceState.listening) {
            setState(() {
              _state = VoiceState.idle;
              _statusMessage = 'Tap microphone to speak';
            });
          }
        },
      );

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
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) {
        setState(() {
          _statusMessage = 'Microphone permission required';
        });
        return;
      }
    }

    // Stop any ongoing speech
    await _flutterTts.stop();

    setState(() {
      _state = VoiceState.listening;
      _recognizedText = '';
      _aiResponse = '';
      _statusMessage = 'Listening...';
    });

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
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
        localeId: LocaleService.currentLanguage.sttLocale,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (_recognizedText.trim().isNotEmpty) {
      _processVoiceQuery(_recognizedText.trim());
    } else {
      setState(() {
        _state = VoiceState.idle;
        _statusMessage = 'Tap microphone to speak';
      });
    }
  }

  Future<void> _processVoiceQuery(String query) async {
    setState(() {
      _state = VoiceState.processing;
      _statusMessage = 'Thinking...';
    });

    // Save user voice query to Supabase
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

      final reply = await _apiClient.getChatCompletion(
        query,
        lat: position?.latitude,
        lon: position?.longitude,
        sessionId: _sessionId,
        language: LocaleService.currentLanguage.englishName,
      );

      if (mounted) {
        setState(() {
          _aiResponse = reply;
          _state = VoiceState.speaking;
          _statusMessage = 'Speaking...';
        });

        // Save AI reply to Supabase
        _saveToSupabase(reply, 'assistant');

        // Clean markdown symbols (e.g. *, #) for natural speech
        final cleanText = reply
            .replaceAll(RegExp(r'[*#_`>]'), '')
            .replaceAll(RegExp(r'\n+'), '. ');

        await _flutterTts.speak(cleanText);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = VoiceState.idle;
          _statusMessage = 'Error connecting to weather service';
        });
      }
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
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                  IconButton(
                    icon: Icon(
                      _state == VoiceState.speaking ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      size: 24,
                      color: const Color(0xFF5F6368),
                    ),
                    onPressed: () {
                      if (_state == VoiceState.speaking) {
                        _flutterTts.stop();
                        setState(() {
                          _state = VoiceState.idle;
                          _statusMessage = 'Tap microphone to speak';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            // Central Animated Particle Cloud & Text Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Cloud with state-reactive behavior
                  SizedBox(
                    width: 340,
                    height: 340,
                    child: _VoiceAnimatedParticleCloud(
                      voiceState: _state,
                      soundLevel: _soundLevel,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Text
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'serif',
                      color: _state == VoiceState.listening
                          ? const Color(0xFF1A73E8)
                          : const Color(0xFF5F6368),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Real-time Spoken Words / AI Response Preview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
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
                                ? MarkdownBody(
                                    data: _aiResponse,
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                        fontSize: 15.5,
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
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Controls Area
            Positioned(
              bottom: 40,
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

                    // Main Microphone Trigger Button
                    _VoiceCircleBtn(
                      isPrimary: true,
                      onPressed: () {
                        if (_state == VoiceState.listening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                      child: Icon(
                        _state == VoiceState.listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        size: 30,
                        color: _state == VoiceState.listening ? Colors.white : const Color(0xFF202124),
                      ),
                    ),

                    // Stop Speaking / Replay Button
                    _VoiceCircleBtn(
                      onPressed: () {
                        if (_state == VoiceState.speaking) {
                          _flutterTts.stop();
                          setState(() {
                            _state = VoiceState.idle;
                            _statusMessage = 'Tap microphone to speak';
                          });
                        } else if (_aiResponse.isNotEmpty) {
                          final cleanText = _aiResponse
                              .replaceAll(RegExp(r'[*#_`>]'), '')
                              .replaceAll(RegExp(r'\n+'), '. ');
                          setState(() {
                            _state = VoiceState.speaking;
                            _statusMessage = 'Speaking...';
                          });
                          _flutterTts.speak(cleanText);
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
