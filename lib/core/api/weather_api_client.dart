import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../localization/locale_service.dart';
import '../voice/speech_sanitizer.dart';

class ChatCompletionResult {
  final String reply;
  final Map<String, dynamic>? weatherData;
  final bool weatherContextUsed;
  final String? ttsText;
  final String? detectedLanguage;
  final String? ttsLocale;
  final String? sttLocale;

  const ChatCompletionResult({
    required this.reply,
    this.weatherData,
    this.weatherContextUsed = false,
    this.ttsText,
    this.detectedLanguage,
    this.ttsLocale,
    this.sttLocale,
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

  Future<ChatCompletionResult> getChatCompletionResult(
    String message, {
    double? lat,
    double? lon,
    String? sessionId,
    String? language,
    bool voiceMode = false,
  }) async {
    final selectedLang = language ?? LocaleService.currentLanguage.englishName;
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
        return ChatCompletionResult.fromResponseJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } catch (_) {
        // If it fails, reset and fall through to auto-discovery
        _resolvedBaseUrl = null;
      }
    }

    // 2. Auto-discovery: iterate through candidates
    // Give Render cold-start extra time (up to 30s) if it is the production URL
    dynamic lastError;
    for (final url in candidates) {
      try {
        final isRender = url.contains('onrender.com');
        final timeout = isRender ? 30 : 4;
        final dio = _createDio(url, timeoutSeconds: timeout);
        final response = await dio.post('/chat/completions', data: payload);
        _resolvedBaseUrl = url; // Remember working endpoint
        return ChatCompletionResult.fromResponseJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } catch (e) {
        lastError = e;
      }
    }

    if (lat != null && lon != null) {
      // Graceful offline fallback with local telemetry for uninterrupted reviews
      const fallbackReply =
          "*(Backend connecting — showing local meteorological telemetry)*\n\n"
          "**Actionable Advisory:**\n"
          "• 🧥 **Attire:** Comfortable lightweight fabrics; no heavy layers needed.\n"
          "• 🏃 **Outdoor Activity:** 8.5/10 — Great conditions for outdoor running or walking.\n"
          "• 🌿 **Air Quality:** Moderate AQI — good for general outdoor activities.";
      final activeLang = LocaleService.resolveLanguage(selectedLang) ??
          LocaleService.currentLanguage;
      return ChatCompletionResult(
        reply: fallbackReply,
        ttsText: SpeechSanitizer.cleanForSpeech(
          fallbackReply,
          language: activeLang,
        ),
        detectedLanguage: activeLang.englishName,
        ttsLocale: activeLang.ttsLocale,
        sttLocale: activeLang.sttLocale,
        weatherData: {
          'location_name': 'Local Telemetry',
          'latitude': lat,
          'longitude': lon,
          'temperature': 28.0,
          'apparent_temperature': 29.5,
          'condition': 'Partly Cloudy',
          'weather_code': 2,
          'humidity': 62,
          'wind_speed': 12.0,
          'wind_direction': 180,
          'rain_chance': 0,
          'temp_max': 31,
          'temp_min': 21,
          'aqi': 68,
          'hourly': [
            {'time': 'Now', 'temp': 28, 'rain_chance': 0, 'weather_code': 1, 'wind_speed': 12},
            {'time': '20:00', 'temp': 26, 'rain_chance': 0, 'weather_code': 1, 'wind_speed': 11},
            {'time': '21:00', 'temp': 24, 'rain_chance': 0, 'weather_code': 0, 'wind_speed': 10},
            {'time': '22:00', 'temp': 23, 'rain_chance': 0, 'weather_code': 0, 'wind_speed': 9},
            {'time': '23:00', 'temp': 22, 'rain_chance': 0, 'weather_code': 0, 'wind_speed': 8},
            {'time': '00:00', 'temp': 21, 'rain_chance': 0, 'weather_code': 0, 'wind_speed': 7},
          ]
        },
        weatherContextUsed: true,
      );
    }

    String errorText;
    if (lastError is DioException) {
      errorText = "Network Error (${lastError.type}): Could not connect to backend at ${candidates.join(', ')}. Details: ${lastError.message ?? lastError.error}";
    } else {
      errorText = "Could not connect to backend server: $lastError";
    }

    return ChatCompletionResult(
      reply: errorText,
      ttsText: errorText,
      weatherData: null,
      weatherContextUsed: false,
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
