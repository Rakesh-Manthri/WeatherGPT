import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/weather_api_client.dart';
import '../../../core/location/location_service.dart';
import '../../../core/localization/locale_service.dart';
import '../../../core/localization/language_picker_sheet.dart';
import '../../../core/voice/speech_sanitizer.dart';
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/activity_chips_bar.dart';
import '../../map/screens/map_screen.dart';

class ChatScreen extends StatefulWidget {
  final String initialQuery;
  final String? sessionId;
  final bool isIncognito;

  const ChatScreen({
    super.key,
    this.initialQuery = '',
    this.sessionId,
    this.isIncognito = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final WeatherApiClient _apiClient = WeatherApiClient();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isTyping = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _initialTextBeforeSpeech = '';
  String? _currentSessionId;
  int? _speakingMessageIndex;
  int _ttsToken = 0;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    _initTts();
    _initChat();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setSpeechRate(0.48);
    } catch (e) {
      debugPrint('Chat TTS init warning: $e');
    }
  }

  @override
  void dispose() {
    _ttsToken++;
    _speech.stop();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    if (widget.initialQuery.isNotEmpty) {
      await _sendMessage(widget.initialQuery);
    } else {
      await _loadExistingMessages();
    }
  }

  Future<void> _ensureSession() async {
    // In incognito mode, do NOT create or persist a chat session in history
    if (widget.isIncognito) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _currentSessionId != null) return;
    try {
      final res = await Supabase.instance.client
          .from('chat_sessions')
          .insert({'user_id': user.id})
          .select('id')
          .single();
      _currentSessionId = res['id'] as String?;
    } catch (e) {
      debugPrint('Error creating chat session: $e');
    }
  }

  Future<void> _saveMessageToDb(String content, String role) async {
    // In incognito mode, do NOT store messages in history
    if (widget.isIncognito) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await _ensureSession();
      if (_currentSessionId != null) {
        await Supabase.instance.client.from('chat_messages').insert({
          'session_id': _currentSessionId,
          'role': role,
          'content': content,
        });
      }
    } catch (e) {
      debugPrint('Error saving message to Supabase: $e');
    }
  }

  Future<void> _loadExistingMessages() async {
    if (widget.isIncognito) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || _currentSessionId == null) return;

      final response = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('session_id', _currentSessionId!)
          .order('created_at', ascending: true);

      if (mounted && response.isNotEmpty) {
        setState(() {
          _messages.clear();
          for (final item in response) {
            _messages.add(
              ChatMessage(
                text: item['content'] ?? '',
                isUser: item['role'] == 'user',
                timestamp:
                    DateTime.tryParse(item['created_at'] ?? '') ??
                    DateTime.now(),
              ),
            );
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading chat messages: $e');
    }
  }

  bool _isMapIntent(String query) {
    final q = query.toLowerCase();
    return q.contains('map') ||
        q.contains('radar') ||
        q.contains('gis') ||
        q.contains('wind layer') ||
        q.contains('satellite layer') ||
        q.contains('precipitation cell') ||
        q.contains('నక్ష') ||
        q.contains('नक्शा');
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _textController.clear();

    // Save user message to Supabase
    _saveMessageToDb(text, 'user');
    _scrollToBottom();

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
        text,
        lat: position?.latitude,
        lon: position?.longitude,
        sessionId: widget.isIncognito ? null : _currentSessionId,
        language: LocaleService.currentLanguage.englishName,
      );

      final isMapRequested = _isMapIntent(text);

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              text: result.reply,
              isUser: false,
              timestamp: DateTime.now(),
              weatherData: result.weatherData,
              ttsText: result.ttsText,
              ttsLocale: result.ttsLocale,
              detectedLanguage: result.detectedLanguage,
              isOfflineEdgeAi: result.isOfflineEdgeAi,
              offlineCacheAge: result.offlineCacheAge,
              showMapBubble: isMapRequested,
            ),
          );
        });
        // Save assistant reply to Supabase
        _saveMessageToDb(result.reply, 'assistant');
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              text: "Connection Error: $e",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleSpeakMessage(int index) async {
    if (_speakingMessageIndex == index) {
      _ttsToken++;
      await _flutterTts.stop();
      if (mounted) setState(() => _speakingMessageIndex = null);
      return;
    }

    final msg = _messages[index];
    final targetLang = LocaleService.resolveLanguage(msg.detectedLanguage) ??
        LocaleService.resolveLanguage(msg.ttsLocale) ??
        LocaleService.currentLanguage;
    final cleanText = (msg.ttsText != null && msg.ttsText!.trim().isNotEmpty)
        ? msg.ttsText!.trim()
        : SpeechSanitizer.cleanForSpeech(msg.text, language: targetLang);
    final chunks = SpeechSanitizer.chunkForTts(cleanText);
    if (chunks.isEmpty) return;

    final myToken = ++_ttsToken;
    await _flutterTts.stop();
    try {
      final avail = await _flutterTts.isLanguageAvailable(targetLang.ttsLocale);
      if (avail == true || avail == 1) {
        await _flutterTts.setLanguage(targetLang.ttsLocale);
      } else {
        await _flutterTts.setLanguage('en-IN');
      }
    } catch (_) {}

    if (mounted) setState(() => _speakingMessageIndex = index);

    for (final chunk in chunks) {
      if (!mounted || myToken != _ttsToken) return;
      await _flutterTts.speak(chunk);
    }

    if (mounted && myToken == _ttsToken) {
      setState(() => _speakingMessageIndex = null);
    }
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
            debugPrint('Chat STT Status: $status');
            if (status == 'done' || status == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (errorNotification) {
            debugPrint('Chat STT Error: ${errorNotification.errorMsg}');
            if (mounted) setState(() => _isListening = false);
          },
        );
      } catch (e) {
        debugPrint('Error initializing Speech: $e');
        _speechAvailable = false;
      }
    }

    if (_speechAvailable) {
      _initialTextBeforeSpeech = _textController.text;
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
                _textController.text = newText;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              }
            }
          },
        );
      } catch (e) {
        debugPrint('Error listening: $e');
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Speech recognition not available or microphone permission denied',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openGisMapScreen([double? lat, double? lon, int? messageIndex]) {
    Map<String, dynamic>? weather;
    if (messageIndex != null &&
        messageIndex < _messages.length &&
        _messages[messageIndex].weatherData != null) {
      weather = _messages[messageIndex].weatherData;
    } else {
      for (final msg in _messages.reversed) {
        if (msg.weatherData != null && msg.weatherData!.isNotEmpty) {
          weather = msg.weatherData;
          break;
        }
      }
    }
    final targetLat = lat ?? (weather?['latitude'] as num?)?.toDouble();
    final targetLon = lon ?? (weather?['longitude'] as num?)?.toDouble();
    final locName = weather?['location_name']?.toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialLat: targetLat,
          initialLon: targetLon,
          locationName: locName,
          weatherData: weather,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _ChatCircularIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Mode Segmented Toggle (Chat vs GIS Map)
                  _ChatSegmentedToggle(
                    selectedIndex: 0,
                    onChanged: (index) {
                      if (index == 1) {
                        _openGisMapScreen();
                      }
                    },
                  ),

                  // Language Picker Button
                  _ChatCircularIconButton(
                    icon: Icons.translate_rounded,
                    onPressed: () => LanguagePickerSheet.show(context),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _messages.isEmpty
                    ? 1
                    : (_isTyping ? _messages.length + 1 : _messages.length),
                itemBuilder: (context, index) {
                  if (_messages.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 36, 12, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FC),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.cloud_outlined,
                              size: 34,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'How can I help with your weather?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ask about today, the forecast, or what to do outdoors.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF6A6A6A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (_isTyping && index == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: TypingIndicator(),
                    );
                  }
                  return MessageBubble(
                    message: _messages[index],
                    isSpeaking: _speakingMessageIndex == index,
                    onSpeakTap: () => _toggleSpeakMessage(index),
                    onViewMap: (lat, lon) {
                      _openGisMapScreen(lat, lon, index);
                    },
                  );
                },
              ),
            ),

            // Activity Suggestion Chips Bar
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ActivityChipsBar(
                onChipSelected: (prompt) {
                  if (_isTyping) return;
                  _textController.text = prompt;
                  _sendMessage(prompt);
                },
              ),
            ),

            // Bottom Input Area with Inline STT
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Ask weather...',
                  hintStyle: TextStyle(
                    color: Color(0xFF6A6A6A),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Inline STT Microphone Button
          Tooltip(
            message: _isListening ? 'Stop listening' : 'Ask by voice',
            child: GestureDetector(
              onTap: _isTyping ? null : _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isListening
                      ? const Color(0xFFFFECEB)
                      : const Color(0xFFF1F3F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isListening
                      ? const Color(0xFFD93025)
                      : const Color(0xFF333333),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Submit Button
          Tooltip(
            message: 'Send message',
            child: GestureDetector(
              onTap: _isTyping
                  ? null
                  : () => _sendMessage(_textController.text),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ChatCircularIconButton({required this.icon, required this.onPressed});

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
            child: Icon(icon, size: 20, color: const Color(0xFF1C1C1E)),
          ),
        ),
      ),
    );
  }
}

class _ChatSegmentedToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ChatSegmentedToggle({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChatToggleOption(
              icon: Icons.chat_bubble_outline_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _ChatToggleOption(
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

class _ChatToggleOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatToggleOption({
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
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 19,
            color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}
