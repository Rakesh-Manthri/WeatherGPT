import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_gpt/features/map/screens/map_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testWeatherData = {
    'location_name': 'Visakhapatnam Coast',
    'latitude': 17.6868,
    'longitude': 83.2185,
    'temperature': 31.0,
    'condition': 'Cyclone Watch',
    'rain_chance': 85,
    'humidity': 88,
    'wind_speed': 42.0,
    'wind_direction': 90.0,
    'aqi': 45,
    'spatial_downscaling': {
      'microclimate_zone': 'Bay of Bengal Coastal Buffer (Marine Advection)',
    },
  };

  testWidgets('MapScreen renders telemetry, GIS overlays, and controls', (tester) async {
    bool backToChatCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          initialLat: 17.6868,
          initialLon: 83.2185,
          locationName: 'Visakhapatnam Coast',
          weatherData: testWeatherData,
          onBackToChat: () {
            backToChatCalled = true;
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify location title and coordinates
    expect(find.text('Visakhapatnam Coast'), findsOneWidget);
    expect(find.textContaining('17.6868°N, 83.2185°E'), findsOneWidget);
    expect(find.textContaining('Bay of Bengal Coastal Buffer'), findsOneWidget);

    // Verify metrics
    expect(find.text('31°C'), findsWidgets);
    expect(find.text('85%'), findsOneWidget);
    expect(find.text('42 km/h'), findsOneWidget);

    // Verify floating action buttons
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

    // Verify layer pills
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Wind'), findsWidgets);
    expect(find.text('1km UHI'), findsOneWidget);

    // Tap Wind layer pill
    await tester.tap(find.text('Wind').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap 1km UHI layer pill
    await tester.tap(find.text('1km UHI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Chat toggle option (index 0)
    final chatToggleOption = find.byIcon(Icons.chat_bubble_outline_rounded);
    expect(chatToggleOption, findsOneWidget);
    await tester.tap(chatToggleOption);
    await tester.pump();

    expect(backToChatCalled, isTrue);
  });

  testWidgets('MapScreen falls back gracefully to default coordinates when no telemetry passed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifies it rendered cleanly without crashing
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Wind'), findsWidgets);
    expect(find.text('1km UHI'), findsOneWidget);
  });
}
