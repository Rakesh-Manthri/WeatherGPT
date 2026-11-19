import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_gpt/core/ai/device_capability_checker.dart';
import 'package:weather_gpt/core/ai/offline_edge_ai_service.dart';
import 'package:weather_gpt/core/api/weather_api_client.dart';
import 'package:weather_gpt/core/cache/offline_weather_cache.dart';
import 'package:weather_gpt/features/chat/models/chat_message.dart';
import 'package:weather_gpt/features/chat/widgets/message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineWeatherCache Tests', () {
    test('saves and retrieves structured weather telemetry', () async {
      final cache = OfflineWeatherCache.instance;
      expect(await cache.getCachedTelemetry(), isNull);

      final mockData = {
        'location_name': 'Hyderabad Abids',
        'latitude': 17.3850,
        'longitude': 78.4867,
        'temperature': 29.5,
        'condition': 'Partly Cloudy',
        'rain_chance': 15,
        'humidity': 64,
        'wind_speed': 13.0,
        'aqi': 78,
      };

      await cache.saveTelemetry(mockData);

      final retrieved = await cache.getCachedTelemetry();
      expect(retrieved, isNotNull);
      expect(retrieved!['location_name'], 'Hyderabad Abids');
      expect(retrieved['temperature'], 29.5);
      expect(retrieved['rain_chance'], 15);
      expect(await cache.hasValidCache(), isTrue);

      final age = await cache.getCacheAgeString();
      expect(age, 'Just now');

      await cache.clear();
      expect(await cache.getCachedTelemetry(), isNull);
      expect(await cache.hasValidCache(), isFalse);
    });

    test('automatically detects and purges obsolete static 27.5°C mock fallback', () async {
      final cache = OfflineWeatherCache.instance;
      // Inject the old buggy static fallback
      final obsoleteData = {
        'location_name': 'Your Location',
        'latitude': 17.3850,
        'longitude': 78.4867,
        'temperature': 27.5,
        'apparent_temperature': 29.1,
        'condition': 'Partly Cloudy',
        'humidity': 62,
        'rain_chance': 5,
      };
      await cache.saveTelemetry(obsoleteData);

      // getCachedTelemetry should detect obsolete 27.5°C and purge it
      final purged = await cache.getCachedTelemetry(purgeStaleFallback: true);
      expect(purged, isNull);
    });
  });

  group('OfflineEdgeAiService Inference & Grounding Tests', () {
    final edgeService = OfflineEdgeAiService.instance;

    test('initializes and detects on-device model weights from edge_ai/models', () async {
      await edgeService.init();
      expect(edgeService.isModelReady, isTrue);
      expect(edgeService.status, EdgeAiStatus.ready);
    });

    test('generates grounded response matching cached metrics in English', () async {
      await OfflineWeatherCache.instance.saveTelemetry({
        'location_name': 'Hyderabad',
        'temperature': 31.0,
        'condition': 'Sunny',
        'rain_chance': 5,
        'humidity': 55,
        'wind_speed': 11.0,
        'aqi': 82,
        'spatial_downscaling': {
          'microclimate_zone': '1km High-Density Urban UHI (+1.9°C)',
        },
      });

      final res = await edgeService.processOfflineQuery(
        'What is the weather right now?',
        language: 'English',
      );

      expect(res.isGroundedOnCache, isTrue);
      expect(res.text.contains('Offline Edge AI'), isTrue);
      expect(res.text.contains('31'), isTrue);
      expect(res.text.contains('Sunny'), isTrue);
      expect(res.text.contains('5%'), isTrue);
      expect(res.text.contains('High-Density Urban UHI'), isTrue);
      expect(res.ttsText.contains('degrees Celsius'), isTrue);
    });

    test('generates grounded farming Panchangam advisory in Telugu', () async {
      await OfflineWeatherCache.instance.saveTelemetry({
        'location_name': 'Hyderabad',
        'temperature': 28.0,
        'condition': 'Clear Sky',
        'rain_chance': 10,
        'humidity': 60,
        'wind_speed': 12.0,
        'aqi': 70,
        'panchangam_fusion': {
          'panchangam': {
            'tithi': {'name': 'Shukla Panchami'},
          },
        },
      });

      final res = await edgeService.processOfflineQuery(
        'రేపు పంట నాట్లు వేయడానికి తిథి అనుకూలంగా ఉందా?',
        language: 'Telugu',
      );

      expect(res.detectedLanguage, 'Telugu');
      expect(res.text.contains('ఆఫ్‌లైన్ ఎడ్జ్ AI'), isTrue);
      expect(res.text.contains('Shukla Panchami'), isTrue);
      expect(res.text.contains('28'), isTrue);
    });

    test('generates grounded rain forecast in Hindi', () async {
      await OfflineWeatherCache.instance.saveTelemetry({
        'location_name': 'Delhi',
        'temperature': 26.0,
        'condition': 'Overcast',
        'rain_chance': 75,
        'humidity': 85,
        'wind_speed': 20.0,
        'aqi': 140,
      });

      final res = await edgeService.processOfflineQuery(
        'क्या आज बारिश होगी?',
        language: 'Hindi',
      );

      expect(res.detectedLanguage, 'Hindi');
      expect(res.text.contains('ऑफ़लाइन एज एआई'), isTrue);
      expect(res.text.contains('75%'), isTrue);
      expect(res.text.contains('छाता साथ रखें'), isTrue);
    });

    test('generates grounded rain forecast in Marathi', () async {
      await OfflineWeatherCache.instance.saveTelemetry({
        'location_name': 'Pune',
        'temperature': 27.0,
        'condition': 'Partly Cloudy',
        'rain_chance': 15,
        'humidity': 65,
        'wind_speed': 14.0,
        'aqi': 60,
      });

      final res = await edgeService.processOfflineQuery(
        'आज पाऊस पडेल का?',
        language: 'Marathi',
      );

      expect(res.detectedLanguage, 'Marathi');
      expect(res.text.contains('ऑफलाइन एज एआय'), isTrue);
      expect(res.text.contains('15%'), isTrue);
      expect(res.text.contains('कमी आहे'), isTrue);
    });

    test('returns emergency guidance fallback when cache is empty', () async {
      await OfflineWeatherCache.instance.clear();

      final res = await edgeService.processOfflineQuery(
        'Is it raining right now?',
        language: 'English',
      );

      expect(res.isGroundedOnCache, isFalse);
      expect(res.text.contains('No local weather telemetry is cached'), isTrue);
    });
  });

  group('WeatherApiClient Force Offline Edge Mode Tests', () {
    test('routes directly to Offline Edge AI when forceOfflineMode is true', () async {
      await OfflineWeatherCache.instance.saveTelemetry({
        'location_name': 'Mumbai',
        'temperature': 30.0,
        'condition': 'Humid',
        'rain_chance': 20,
        'humidity': 80,
        'wind_speed': 16.0,
        'aqi': 95,
      });

      await WeatherApiClient.setForceOfflineMode(true);
      expect(WeatherApiClient.forceOfflineMode, isTrue);

      final client = WeatherApiClient();
      final result = await client.getChatCompletionResult(
        'What should I wear today?',
        language: 'English',
      );

      expect(result.isOfflineEdgeAi, isTrue);
      expect(result.reply.contains('Offline Edge AI'), isTrue);
      expect(result.reply.contains('Mumbai'), isTrue);
      expect(result.reply.contains('30°C'), isTrue);

      // Clean up
      await WeatherApiClient.setForceOfflineMode(false);
    });

    test('persists and retrieves provider preference correctly', () async {
      await WeatherApiClient.setPrimaryProvider('openmeteo');
      expect(WeatherApiClient.primaryProvider, 'openmeteo');

      await WeatherApiClient.loadProviderPreference();
      expect(WeatherApiClient.primaryProvider, 'openmeteo');

      // Switch back to weathernext
      await WeatherApiClient.setPrimaryProvider('weathernext');
      expect(WeatherApiClient.primaryProvider, 'weathernext');
    });

    test('caches and isolates telemetry based on provider preference', () async {
      final cache = OfflineWeatherCache.instance;
      await cache.saveTelemetry({
        'location_name': 'Hyderabad WN',
        'temperature': 24.5,
        'condition': 'Clear',
      }, provider: 'weathernext');

      await cache.saveTelemetry({
        'location_name': 'Hyderabad OM',
        'temperature': 26.0,
        'condition': 'Cloudy',
      }, provider: 'openmeteo');

      final wnData = await cache.getCachedTelemetry(provider: 'weathernext');
      final omData = await cache.getCachedTelemetry(provider: 'openmeteo');

      expect(wnData?['location_name'], 'Hyderabad WN');
      expect(wnData?['temperature'], 24.5);

      expect(omData?['location_name'], 'Hyderabad OM');
      expect(omData?['temperature'], 26.0);
    });

    test('suppresses weather card data for small queries and greetings in offline mode', () async {
      final edge = OfflineEdgeAiService.instance;
      await OfflineWeatherCache.instance.saveTelemetry({
        'location_name': 'Bengaluru',
        'temperature': 22.0,
        'condition': 'Pleasant',
      });

      // 1. Greeting query -> tailored conversational greeting, weatherData is null
      final greetingRes = await edge.processOfflineQuery('Hello, how are you?');
      expect(greetingRes.text.contains('Hello! I am WeatherGPT'), isTrue);
      expect(greetingRes.weatherData, isNull);
      expect(greetingRes.isGroundedOnCache, isFalse);

      // 2. Gratitude query -> polite acknowledgement, weatherData is null
      final thanksRes = await edge.processOfflineQuery('Thanks for your help!');
      expect(thanksRes.text.contains('welcome'), isTrue);
      expect(thanksRes.weatherData, isNull);

      // 3. Meteorological query -> weatherData is attached for card rendering
      final weatherRes = await edge.processOfflineQuery('What is the weather in Bengaluru?');
      expect(weatherRes.weatherData, isNotNull);
      expect(weatherRes.weatherData?['temperature'], 22.0);
      expect(weatherRes.isGroundedOnCache, isTrue);

      // 4. Wind query -> targeted wind focus
      final windRes = await edge.processOfflineQuery('Is it windy?');
      expect(windRes.text.contains('Wind Conditions'), isTrue);

      // 5. Temperature query -> targeted temperature focus
      final tempRes = await edge.processOfflineQuery('What is the temperature?');
      expect(tempRes.text.contains('Temperature in Bengaluru'), isTrue);
    });
  });

  group('DeviceCapabilityChecker Hardware Tests', () {
    test('evaluates device hardware capabilities with fallback gracefully', () async {
      DeviceCapabilityChecker.resetCache();
      final result = await DeviceCapabilityChecker.check(forceRefresh: true);

      expect(result, isNotNull);
      expect(result.freeStorageMb, greaterThanOrEqualTo(0));
      expect(result.totalRamMb, greaterThan(0));
      expect(result.cpuAbi.isNotEmpty, isTrue);
      // Verify cached result returns identical instance
      final cached = await DeviceCapabilityChecker.check();
      expect(cached, same(result));
    });

    test('DeviceCapabilityResult formats diagnostic string correctly', () {
      const cap = DeviceCapabilityResult(
        isCapable: true,
        reason: 'Device compatible',
        freeStorageMb: 1200,
        totalRamMb: 4096,
        cpuAbi: 'arm64-v8a',
      );
      expect(cap.isCapable, isTrue);
      expect(cap.toString().contains('arm64-v8a'), isTrue);
      expect(cap.toString().contains('1200MB'), isTrue);
    });
  });

  group('OfflineEdgeAiService Lifecycle & Loading State Tests', () {
    test('warmUpModel transitions state to loading and then ready', () async {
      final edge = OfflineEdgeAiService.instance;
      await edge.init();
      edge.unloadModelFromMemory();

      expect(edge.isModelReady, isTrue);
      expect(edge.isModelInMemory, isFalse);

      // Trigger warm up
      final warmupFuture = edge.warmUpModel();
      expect(edge.status, EdgeAiStatus.loading);

      await warmupFuture;
      expect(edge.isModelInMemory, isTrue);
      expect(edge.isModelReady, isTrue);
    });

    test('cancelDownload updates status to notDownloaded and resets progress', () {
      final edge = OfflineEdgeAiService.instance;
      edge.statusNotifier.value = EdgeAiStatus.downloading;
      edge.downloadProgressNotifier.value = 0.5;

      edge.cancelDownload();

      expect(edge.status, EdgeAiStatus.notDownloaded);
      expect(edge.downloadProgressNotifier.value, 0.0);
    });
  });

  group('ChatMessage Model & Actions Tests', () {
    test('generates unique UUID messageId and sets editability', () {
      final userMsg = ChatMessage(
        text: 'What is the temperature?',
        isUser: true,
        timestamp: DateTime.now(),
      );
      final aiMsg = ChatMessage(
        text: 'It is 28°C.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      expect(userMsg.id, isNotEmpty);
      expect(aiMsg.id, isNotEmpty);
      expect(userMsg.id, isNot(equals(aiMsg.id)));
      expect(userMsg.isEditable, isTrue);
      expect(aiMsg.isEditable, isFalse);
    });

    testWidgets('MessageBubble renders action buttons and invokes callbacks', (tester) async {
      bool copyTapped = false;
      bool retryTapped = false;
      bool speakTapped = false;

      final message = ChatMessage(
        text: 'Partly cloudy with mild breeze.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              onCopyTap: () => copyTapped = true,
              onRetryTap: () => retryTapped = true,
              onSpeakTap: () => speakTapped = true,
            ),
          ),
        ),
      );

      // Verify Copy, Retry, Listen buttons exist
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copyTapped, isTrue);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retryTapped, isTrue);

      await tester.tap(find.text('Listen'));
      await tester.pump();
      expect(speakTapped, isTrue);
    });
  });
}
