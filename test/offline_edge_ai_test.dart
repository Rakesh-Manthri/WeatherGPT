import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_gpt/core/ai/offline_edge_ai_service.dart';
import 'package:weather_gpt/core/api/weather_api_client.dart';
import 'package:weather_gpt/core/cache/offline_weather_cache.dart';

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
  });

  group('OfflineEdgeAiService Inference & Grounding Tests', () {
    final edgeService = OfflineEdgeAiService.instance;

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
  });
}
