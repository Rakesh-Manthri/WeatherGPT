import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:weather_gpt/core/cache/local_chat_store.dart';
import 'package:weather_gpt/features/chat/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await LocalChatStore.init();
  });

  tearDown(() async {
    await LocalChatStore.clearAll();
    LocalChatStore.resetForTesting();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ChatMessage Serialization Tests', () {
    test('toMap and fromMap preserves weatherData and metadata', () {
      final msg = ChatMessage(
        text: 'Current temperature is 24°C with low humidity.',
        isUser: false,
        timestamp: DateTime.parse('2026-11-19T10:00:00Z'),
        weatherData: {
          'temperature': 24.0,
          'humidity': 45,
          'condition': 'Clear',
          'source': 'WeatherNext 3 (Google DeepMind)',
        },
      );

      final map = msg.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.id, equals(msg.id));
      expect(restored.text, equals(msg.text));
      expect(restored.isUser, isFalse);
      expect(restored.weatherData, isNotNull);
      expect(restored.weatherData!['temperature'], equals(24.0));
      expect(restored.weatherData!['source'], equals('WeatherNext 3 (Google DeepMind)'));
    });

    test('fromMap parses Supabase format with weather_data json', () {
      final supabaseRow = {
        'id': 'msg-12345',
        'session_id': 'sess-67890',
        'role': 'assistant',
        'content': 'Forecast for Hyderabad: 28°C max, 16°C min.',
        'created_at': '2026-11-19T12:30:00Z',
        'weather_data': {
          'temperature': 28.0,
          'location_name': 'Hyderabad',
          'ensemble_members': 64,
        },
      };

      final restored = ChatMessage.fromMap(supabaseRow);
      expect(restored.id, equals('msg-12345'));
      expect(restored.text, equals('Forecast for Hyderabad: 28°C max, 16°C min.'));
      expect(restored.isUser, isFalse);
      expect(restored.weatherData, isNotNull);
      expect(restored.weatherData!['temperature'], equals(28.0));
      expect(restored.weatherData!['ensemble_members'], equals(64));
    });
  });

  group('LocalChatStore Offline Persistence Tests', () {
    test('saves and retrieves chat messages with weatherData offline', () async {
      const sessionId = 'test-session-offline-001';

      final messages = [
        ChatMessage(
          text: 'What is the weather in Hyderabad?',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        ChatMessage(
          text: 'Hyderabad is currently 21°C and clear.',
          isUser: false,
          timestamp: DateTime.now(),
          weatherData: {
            'temperature': 21.0,
            'condition': 'Clear',
            'location_name': 'Hyderabad',
          },
        ),
      ];

      await LocalChatStore.saveMessages(sessionId, messages);

      final cached = LocalChatStore.getCachedMessages(sessionId);
      expect(cached.length, equals(2));
      expect(cached[0].isUser, isTrue);
      expect(cached[0].text, equals('What is the weather in Hyderabad?'));
      expect(cached[1].isUser, isFalse);
      expect(cached[1].weatherData, isNotNull);
      expect(cached[1].weatherData!['temperature'], equals(21.0));
      expect(cached[1].weatherData!['location_name'], equals('Hyderabad'));
    });

    test('saves and retrieves sessions list with sorting', () async {
      final remoteSessions = [
        {
          'id': 'sess-1',
          'title': 'Session One',
          'is_pinned': false,
          'created_at': '2026-11-18T10:00:00Z',
        },
        {
          'id': 'sess-2',
          'title': 'Pinned Session',
          'is_pinned': true,
          'created_at': '2026-11-17T10:00:00Z',
        },
      ];

      await LocalChatStore.saveSessionsList(remoteSessions);

      final cached = LocalChatStore.getCachedSessions();
      expect(cached.length, equals(2));
      // Pinned session must come first regardless of date
      expect(cached.first['id'], equals('sess-2'));
      expect(cached.first['title'], equals('Pinned Session'));
    });
  });
}
