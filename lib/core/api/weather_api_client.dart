import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ai/offline_edge_ai_service.dart';
import '../cache/offline_weather_cache.dart';
import '../localization/locale_service.dart';

class ChatCompletionResult {
  final String reply;
  final Map<String, dynamic>? weatherData;
  final bool weatherContextUsed;
  final String? ttsText;
  final String? detectedLanguage;
  final String? ttsLocale;
  final String? sttLocale;
  final bool isOfflineEdgeAi;
  final String? offlineCacheAge;

  const ChatCompletionResult({
    required this.reply,
    this.weatherData,
    this.weatherContextUsed = false,
    this.ttsText,
    this.detectedLanguage,
    this.ttsLocale,
    this.sttLocale,
    this.isOfflineEdgeAi = false,
    this.offlineCacheAge,
  });

  factory ChatCompletionResult.fromResponseJson(Map<String, dynamic> data) {
    return ChatCompletionResult(
      reply: data['reply'] as String? ?? '',
      weatherData: data['weather_data'] as Map<String, dynamic>?,
      weatherContextUsed: data['weather_context_used'] as bool? ?? false,
      ttsText: data['tts_text'] as String?,
      detectedLanguage: data['detected_language'] as String?,
      ttsLocale: data['tts_locale'] as String?,
      sttLocale: data['stt_locale'] as String?,
      isOfflineEdgeAi: false,
    );
  }
}

class WeatherApiClient {
  /// Dynamic list of candidate backend URLs (Production Render first, then local/emulator fallbacks)
  List<String> get _candidateUrls {
    final urls = <String>[];

    // Priority 1: Production Render URL or custom BACKEND_URL from .env
    final envBackend = dotenv.env['BACKEND_URL'] ?? dotenv.env['RENDER_URL'];
    if (envBackend != null && envBackend.trim().isNotEmpty) {
      final trimmed = envBackend.trim().replaceAll(RegExp(r'/+$'), '');
      final apiBase = trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
      urls.add(apiBase);
    }

    // Priority 2: Local Wi-Fi network IPs, Android Emulator, and Localhost
    urls.addAll([
      'http://192.168.0.101:8000/api', // Current Local Wi-Fi network IP
      'http://192.168.0.104:8000/api', // Alternate Wi-Fi IP
      'http://10.0.2.2:8000/api',      // Android emulator host alias
      'http://127.0.0.1:8000/api',     // Localhost / ADB reverse
    ]);

    return urls;
  }

  String? _resolvedBaseUrl;

  Dio _createDio(String baseUrl, {int timeoutSeconds = 5}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: timeoutSeconds),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    // Add interceptor to attach Supabase JWT if user is logged in
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
        } catch (_) {}
        return handler.next(options);
      },
    ));

    return dio;
  }

  static const String _forceOfflineKey = 'force_offline_edge_mode';
  static bool forceOfflineMode = false;

  static Future<void> loadOfflinePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      forceOfflineMode = prefs.getBool(_forceOfflineKey) ?? false;
    } catch (_) {}
  }

  static Future<void> setForceOfflineMode(bool enabled) async {
    forceOfflineMode = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_forceOfflineKey, enabled);
    } catch (_) {}
  }

  Future<ChatCompletionResult> getChatCompletionResult(
    String message, {
    double? lat,
    double? lon,
    String? sessionId,
    String? language,
    bool voiceMode = false,
  }) async {
    final selectedLang = language ?? LocaleService.currentLanguage.englishName;

    // Route directly to on-device Offline Edge AI if user forced offline mode
    if (forceOfflineMode) {
      return _runOfflineEdgeAi(
        message,
        lat: lat,
        lon: lon,
        language: selectedLang,
      );
    }

    final payload = {
      'message': message,
      'lat': lat,
      'lon': lon,
      'session_id': sessionId,
      'language': selectedLang,
      'voice_mode': voiceMode,
    };

    final candidates = _candidateUrls;

    // 1. If we already know which URL works, try it first
    if (_resolvedBaseUrl != null) {
      try {
        final dio = _createDio(_resolvedBaseUrl!, timeoutSeconds: 15);
        final response = await dio.post('/chat/completions', data: payload);
        final res = ChatCompletionResult.fromResponseJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (res.weatherData != null) {
          OfflineWeatherCache.instance.saveTelemetry(res.weatherData!);
        }
        return res;
      } catch (_) {
        // If it fails, reset and fall through to auto-discovery
        _resolvedBaseUrl = null;
      }
    }

    // 2. Auto-discovery: iterate through candidates
    // Give Render cold-start extra time (up to 30s) if it is the production URL
    for (final url in candidates) {
      try {
        final isRender = url.contains('onrender.com');
        final timeout = isRender ? 30 : 4;
        final dio = _createDio(url, timeoutSeconds: timeout);
        final response = await dio.post('/chat/completions', data: payload);
        _resolvedBaseUrl = url; // Remember working endpoint
        final res = ChatCompletionResult.fromResponseJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (res.weatherData != null) {
          OfflineWeatherCache.instance.saveTelemetry(res.weatherData!);
        }
        return res;
      } catch (_) {
        // Try next candidate
      }
    }

    // 3. Offline Fallback -> Seamless routing to On-Device Quantized Edge AI (Qwen2.5-0.5B)
    return _runOfflineEdgeAi(
      message,
      lat: lat,
      lon: lon,
      language: selectedLang,
    );
  }

  Future<ChatCompletionResult> _runOfflineEdgeAi(
    String message, {
    double? lat,
    double? lon,
    required String language,
  }) async {
    final edgeResult = await OfflineEdgeAiService.instance.processOfflineQuery(
      message,
      lat: lat,
      lon: lon,
      language: language,
    );
    final activeLang = LocaleService.resolveLanguage(edgeResult.detectedLanguage) ??
        LocaleService.currentLanguage;

    return ChatCompletionResult(
      reply: edgeResult.text,
      ttsText: edgeResult.ttsText,
      detectedLanguage: edgeResult.detectedLanguage,
      ttsLocale: activeLang.ttsLocale,
      sttLocale: activeLang.sttLocale,
      weatherData: edgeResult.weatherData,
      weatherContextUsed: edgeResult.isGroundedOnCache,
      isOfflineEdgeAi: true,
      offlineCacheAge: edgeResult.cacheAge,
    );
  }

  Future<String> getChatCompletion(
    String message, {
    double? lat,
    double? lon,
    String? sessionId,
    String? language,
    bool voiceMode = false,
  }) async {
    final res = await getChatCompletionResult(
      message,
      lat: lat,
      lon: lon,
      sessionId: sessionId,
      language: language,
      voiceMode: voiceMode,
    );
    return res.reply;
  }
}
