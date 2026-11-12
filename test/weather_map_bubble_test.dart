import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_gpt/features/chat/models/chat_message.dart';
import 'package:weather_gpt/features/chat/widgets/message_bubble.dart';
import 'package:weather_gpt/features/chat/widgets/weather_map_bubble.dart';

void main() {
  final mockWeatherData = {
    'location_name': 'Hyderabad Abids',
    'latitude': 17.3850,
    'longitude': 78.4867,
    'temperature': 29.0,
    'condition': 'Partly Cloudy',
    'rain_chance': 65,
    'humidity': 72,
    'wind_speed': 16.5,
    'wind_direction': 225.0,
    'aqi': 68,
    'spatial_downscaling': {
      'microclimate_zone': '1km High-Density Urban UHI (+1.9°C)',
    },
    'hourly': [
      {'time': 'Now', 'temp': 29, 'rain_chance': 65, 'weather_code': 2, 'wind_speed': 16},
    ],
  };

  group('WeatherMapBubble Widget Tests', () {
    testWidgets('renders GIS header, coordinates, layers, and telemetry footer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeatherMapBubble(
                weatherData: mockWeatherData,
              ),
            ),
          ),
        ),
      );

      // Verify title and coordinates
      expect(find.text('GIS Weather Radar • Hyderabad Abids'), findsOneWidget);
      expect(find.textContaining('17.3850°N, 78.4867°E'), findsOneWidget);

      // Verify layer buttons
      expect(find.text('Radar'), findsOneWidget);
      expect(find.text('Wind'), findsOneWidget);
      expect(find.text('1km UHI'), findsOneWidget);

      // Verify zoom and location buttons
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

      // Verify footer metrics
      expect(find.text('29°C Partly Cloudy'), findsOneWidget);
      expect(find.text('65% Rain'), findsOneWidget);
      expect(find.text('17 km/h'), findsOneWidget);

      // Tap on Wind layer pill and verify layer switch
      await tester.tap(find.text('Wind'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Wind Vector'), findsOneWidget);

      // Tap on 1km UHI layer pill
      await tester.tap(find.text('1km UHI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('1km UHI: -3°C'), findsOneWidget);
    });

    testWidgets('triggers onExpandFullscreen callback when fullscreen button is tapped', (tester) async {
      double? clickedLat;
      double? clickedLon;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeatherMapBubble(
                weatherData: mockWeatherData,
                onExpandFullscreen: (lat, lon) {
                  clickedLat = lat;
                  clickedLon = lon;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pump();

      expect(clickedLat, 17.3850);
      expect(clickedLon, 78.4867);
    });
  });

  group('MessageBubble GIS Radar Map Integration Tests', () {
    testWidgets('renders WeatherMapBubble when showMapBubble is true', (tester) async {
      final msg = ChatMessage(
        text: 'Here is your interactive radar map for Hyderabad.',
        isUser: false,
        timestamp: DateTime.now(),
        weatherData: mockWeatherData,
        showMapBubble: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: msg),
            ),
          ),
        ),
      );

      expect(find.byType(WeatherMapBubble), findsOneWidget);
      expect(find.text('GIS Weather Radar • Hyderabad Abids'), findsOneWidget);
    });

    testWidgets('toggles inline radar map via WeatherCardBubble button', (tester) async {
      final msg = ChatMessage(
        text: 'Standard weather report.',
        isUser: false,
        timestamp: DateTime.now(),
        weatherData: mockWeatherData,
        showMapBubble: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: msg),
            ),
          ),
        ),
      );

      // Initially inline map is collapsed
      expect(find.byType(WeatherMapBubble), findsNothing);
      expect(find.text('Live Radar & Wind Map'), findsOneWidget);

      // Tap toggle button to open inline map
      await tester.tap(find.text('Live Radar & Wind Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(WeatherMapBubble), findsOneWidget);
      expect(find.text('Hide Radar Map'), findsOneWidget);

      // Scroll if needed and tap toggle button to close inline map
      await tester.ensureVisible(find.text('Hide Radar Map'));
      await tester.tap(find.text('Hide Radar Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(WeatherMapBubble), findsNothing);
      expect(find.text('Live Radar & Wind Map'), findsOneWidget);
    });
  });
}
