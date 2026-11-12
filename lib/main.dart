import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/news/screens/news_screen.dart';
import 'features/voice/screens/voice_assistant_screen.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'core/localization/locale_service.dart';
import 'core/api/weather_api_client.dart';
import 'core/ai/offline_edge_ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // We wrap the load in try-catch in case .env doesn't exist yet so the app doesn't crash
  try {
    await dotenv.load(fileName: ".env");
    
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    await LocaleService.init();
    await WeatherApiClient.loadOfflinePreference();
    await OfflineEdgeAiService.instance.init();
  } catch (e) {
    debugPrint("Failed to load .env file or initialize services: $e");
  }
  runApp(const WeatherGptApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class WeatherGptApp extends StatelessWidget {
  const WeatherGptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeatherGPT',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C1C1E),
          surface: const Color(0xFFF7F7F7),
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      ),
      home: const WeatherGptScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherGptScreen extends StatefulWidget {
  const WeatherGptScreen({super.key});

  @override
  State<WeatherGptScreen> createState() => _WeatherGptScreenState();
}

class _WeatherGptScreenState extends State<WeatherGptScreen> {
  int _selectedToggleIndex = 0; // 0: Search, 1: Image
  bool _isIncognito = false;
  final TextEditingController _inputController = TextEditingController();
  late final PageController _pageController;
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: PopScope(
        canPop: _currentPage == 1,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentPage != 1) {
            _goToPage(1);
          }
        },
        child: PageView(
          controller: _pageController,
          physics: _selectedToggleIndex == 1
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(parent: PageScrollPhysics()),
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
            if (index == 0) {
              _profileKey.currentState?.refreshHistory();
            }
          },
          children: [
            // Page 0: Profile Screen (slides slowly from left)
            ProfileScreen(
              key: _profileKey,
              onBack: () => _goToPage(1),
            ),

            // Page 1: Main Home Screen
            _buildHomeScreen(context),

            // Page 2: News Screen (slides slowly from right)
            NewsScreen(
              onBack: () => _goToPage(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScreen(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: Stack(
        children: [
          // Map Background when Mountain pill (index 1) is selected
          if (_selectedToggleIndex == 1)
            Positioned.fill(
              child: MapplsMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(28.6139, 77.2090),
                  zoom: 11.0,
                ),
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.tracking,
              ),
            ),

          // Home Page Interface (Top Pills, Center Area, Bottom Floating Input)
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Profile Button (slides from left to right)
                      _CircularIconButton(
                        icon: Icons.person_outline_rounded,
                        onPressed: () => _goToPage(0),
                      ),

                      // Search / Image Mode Toggle
                      _SegmentedToggle(
                        selectedIndex: _selectedToggleIndex,
                        onChanged: (index) {
                          setState(() {
                            _selectedToggleIndex = index;
                          });
                        },
                      ),

                      // News Button (slides from right to left)
                      _CircularIconButton(
                        icon: Icons.article_outlined,
                        onPressed: () => _goToPage(2),
                      ),
                    ],
                  ),
                ),

                // Hero Center Content (Visible in Search mode, transparent in Map mode)
                Expanded(
                  child: _selectedToggleIndex == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _isIncognito
                                  ? Column(
                                      key: const ValueKey('incognito_hero'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Incognito mode',
                                          style: TextStyle(
                                            fontFamily: 'serif',
                                            fontSize: 36,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF555555),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Your chat will not be stored',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF888888),
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'WeatherGPT',
                                      key: ValueKey('weathergpt_hero'),
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 36,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF555555),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Bottom Chat Input Card (Visible only in Search mode)
                if (_selectedToggleIndex == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _ChatInputCard(
                      controller: _inputController,
                      isIncognito: _isIncognito,
                      onIncognitoChanged: (val) {
                        setState(() {
                          _isIncognito = val;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular Header Navigation Button (Profile, Documents)
class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircularIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented Toggle Switch (Search / Image)
class _SegmentedToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              icon: Icons.search_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _ToggleOption(
              icon: Icons.landscape_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 19,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}

/// Bottom Floating Chat Input Area with Inline STT
class _ChatInputCard extends StatefulWidget {
  final TextEditingController controller;
  final bool isIncognito;
  final ValueChanged<bool> onIncognitoChanged;

  const _ChatInputCard({
    required this.controller,
    required this.isIncognito,
    required this.onIncognitoChanged,
  });

  @override
  State<_ChatInputCard> createState() => _ChatInputCardState();
}

class _ChatInputCardState extends State<_ChatInputCard> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _initialTextBeforeSpeech = '';

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      try {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) {
            debugPrint('Inline STT Status: $status');
            if (status == 'done' || status == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (errorNotification) {
            debugPrint('Inline STT Error: ${errorNotification.errorMsg}');
            if (mounted) setState(() => _isListening = false);
          },
        );
      } catch (e) {
        debugPrint('Error initializing STT: $e');
        _speechAvailable = false;
      }
    }

    if (_speechAvailable) {
      _initialTextBeforeSpeech = widget.controller.text;
      setState(() => _isListening = true);

      try {
        await _speech.listen(
          listenOptions: stt.SpeechListenOptions(
            localeId: LocaleService.currentLanguage.sttLocale,
            partialResults: true,
          ),
          onResult: (result) {
            if (mounted) {
              final recognized = result.recognizedWords;
              if (recognized.isNotEmpty) {
                final newText = _initialTextBeforeSpeech.trim().isEmpty
                    ? recognized
                    : '$_initialTextBeforeSpeech $recognized';
                widget.controller.text = newText;
                widget.controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: widget.controller.text.length),
                );
              }
            }
          },
        );
      } catch (e) {
        debugPrint('Error starting STT listen: $e');
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available or microphone permission denied'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            decoration: const InputDecoration(
              hintText: 'Ask weather...',
              hintStyle: TextStyle(
                color: Color(0xFF6A6A6A),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1C1C1E),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                final query = value.trim();
                widget.controller.clear();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      initialQuery: query,
                      isIncognito: widget.isIncognito,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Add Button
              _ToolbarButton(
                iconWidget: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Color(0xFF333333),
                ),
                onPressed: () {},
              ),

              // Right Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Incognito / Spy Icon
                  _ToolbarButton(
                    iconWidget: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: widget.isIncognito ? const Color(0xFF1C1C1E) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CustomPaint(
                        size: const Size(22, 22),
                        painter: _IncognitoIconPainter(
                          color: widget.isIncognito ? Colors.white : const Color(0xFF333333),
                        ),
                      ),
                    ),
                    onPressed: () {
                      final nextState = !widget.isIncognito;
                      widget.onIncognitoChanged(nextState);
                    },
                  ),
                  const SizedBox(width: 18),

                  // Microphone Button for Inline STT Dictation
                  _ToolbarButton(
                    iconWidget: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isListening ? const Color(0xFFFFECEB) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 24,
                        color: _isListening ? const Color(0xFFD93025) : const Color(0xFF333333),
                      ),
                    ),
                    onPressed: _toggleListening,
                  ),
                  const SizedBox(width: 18),

                  // Dark Circular Button (Wave Icon when empty -> opens Voice Assistant; Enter Icon when typing -> submits query)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, val, _) {
                      final hasText = val.text.trim().isNotEmpty;

                      return Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF212121),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              if (hasText) {
                                final query = val.text.trim();
                                widget.controller.clear();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      initialQuery: query,
                                      isIncognito: widget.isIncognito,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const VoiceAssistantScreen(),
                                  ),
                                );
                              }
                            },
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: hasText
                                    ? const Icon(
                                        Icons.arrow_upward_rounded,
                                        key: ValueKey('enter_btn'),
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : const CustomPaint(
                                        key: ValueKey('wave_btn'),
                                        size: Size(18, 18),
                                        painter: _VoiceWaveIconPainter(
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final Widget iconWidget;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.iconWidget,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: iconWidget,
    );
  }
}

/// Custom Painter for Incognito / Spy Icon (Fedora + Glasses) matching the HTML SVG
class _IncognitoIconPainter extends CustomPainter {
  final Color color;

  const _IncognitoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8 * (size.width / 24.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    // Hat brim: M2 14h20
    canvas.drawLine(const Offset(2, 14), const Offset(22, 14), paint);

    // Hat crown: M6 14v-2.5C6 9.5 8 7 12 7s6 2.5 6 4.5V14
    final crownPath = Path()
      ..moveTo(6, 14)
      ..lineTo(6, 11.5)
      ..cubicTo(6, 9.5, 8, 7, 12, 7)
      ..cubicTo(16, 7, 18, 9.5, 18, 11.5)
      ..lineTo(18, 14);
    canvas.drawPath(crownPath, paint);

    // Left lens: circle cx=8, cy=18, r=3
    canvas.drawCircle(const Offset(8, 18), 3, paint);

    // Right lens: circle cx=16, cy=18, r=3
    canvas.drawCircle(const Offset(16, 18), 3, paint);

    // Bridge: M11 18h2
    canvas.drawLine(const Offset(11, 18), const Offset(13, 18), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IncognitoIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Custom Painter for Sound / Voice Wave Icon matching the HTML SVG
class _VoiceWaveIconPainter extends CustomPainter {
  final Color color;

  const _VoiceWaveIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0 * (size.width / 24.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    // Line 1: x=4, y=12..12
    canvas.drawLine(const Offset(4, 11.9), const Offset(4, 12.1), paint);
    // Line 2: x=8, y=9..15
    canvas.drawLine(const Offset(8, 9), const Offset(8, 15), paint);
    // Line 3: x=12, y=5..19
    canvas.drawLine(const Offset(12, 5), const Offset(12, 19), paint);
    // Line 4: x=16, y=9..15
    canvas.drawLine(const Offset(16, 9), const Offset(16, 15), paint);
    // Line 5: x=20, y=12..12
    canvas.drawLine(const Offset(20, 11.9), const Offset(20, 12.1), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveIconPainter oldDelegate) =>
      oldDelegate.color != color;
}


/// Animated Gaussian Cloud Particle System
class AnimatedParticleCloud extends StatefulWidget {
  const AnimatedParticleCloud({super.key});

  @override
  State<AnimatedParticleCloud> createState() => _AnimatedParticleCloudState();
}

class _AnimatedParticleCloudState extends State<AnimatedParticleCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final int _particleCount = 5000; // Denser Gaussian cloud

  @override
  void initState() {
    super.initState();
    _generateCloud();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Speed of the drifting animation
    )..repeat();
  }

  void _generateCloud() {
    final random = Random();

    // Define the structural "lobes" of the cloud (Center offset and Spread)
    // Spread acts as the standard deviation for the Gaussian scatter
    final List<Map<String, dynamic>> lobes = [
      {'center': const Offset(0, -30), 'spread': 40.0},  // Top puff
      {'center': const Offset(-50, 15), 'spread': 35.0}, // Left puff
      {'center': const Offset(50, 15), 'spread': 35.0},  // Right puff
      {'center': const Offset(0, 15), 'spread': 45.0},   // Main bottom core
    ];

    for (int i = 0; i < _particleCount; i++) {
      // Pick a random lobe to spawn this particle around
      final lobe = lobes[random.nextInt(lobes.length)];
      final Offset center = lobe['center'] as Offset;
      final double spread = lobe['spread'] as double;

      // Generate Gaussian distributed coordinates (dense center, fuzzy edges)
      final double px = center.dx + _generateGaussian(random) * spread;
      final double py = center.dy + _generateGaussian(random) * (spread * 0.75); // Flatten Y slightly

      // Add random animation properties
      _particles.add(Particle(
        basePosition: Offset(px, py),
        phaseOffset: random.nextDouble() * 2 * pi, // Random start phase
        driftRadius: random.nextDouble() * 4 + 1,  // How far it wanders
      ));
    }
  }

  // Helper to generate a normal (Gaussian) distribution using Box-Muller transform
  double _generateGaussian(Random random) {
    double u1 = random.nextDouble();
    double u2 = random.nextDouble();
    // Prevent log(0)
    if (u1 == 0.0) u1 = 0.0001;
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: CloudPainter(
            particles: _particles,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

// Data class to hold individual particle data
class Particle {
  final Offset basePosition;
  final double phaseOffset;
  final double driftRadius;

  Particle({
    required this.basePosition,
    required this.phaseOffset,
    required this.driftRadius,
  });
}

class CloudPainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final Paint _paint;

  CloudPainter({required this.particles, required this.animationValue})
      : _paint = Paint()
          ..color = const Color(0xFF5CA3D6).withValues(alpha: 0.8) // Cloud blue
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5; // Particle size

  @override
  void paint(Canvas canvas, Size size) {
    // Translate canvas so (0,0) is in the exact center of our widget
    canvas.translate(size.width / 2, size.height / 2);

    // Collect all calculated particle positions into a single list
    final List<Offset> currentPositions = [];

    final double time = animationValue * 2 * pi;

    for (final p in particles) {
      // Calculate current position based on base position + sine wave drift
      final double dx = p.basePosition.dx + sin(time + p.phaseOffset) * p.driftRadius;
      final double dy = p.basePosition.dy + cos(time + p.phaseOffset) * p.driftRadius;

      currentPositions.add(Offset(dx, dy));
    }

    // drawPoints is highly optimized and batches all rendering into a single call
    canvas.drawPoints(PointMode.points, currentPositions, _paint);
  }

  @override
  bool shouldRepaint(covariant CloudPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

