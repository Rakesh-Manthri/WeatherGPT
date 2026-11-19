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

  testWidgets('MapScreen renders clean full-screen map with top navigation controls', (tester) async {
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

    // Verify MapScreen rendered cleanly
    expect(find.byType(MapScreen), findsOneWidget);

    // Verify overlays, radar, layer pills, and floating action buttons were removed per clean map requirement
    expect(find.text('Radar'), findsNothing);
    expect(find.text('1km UHI'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byIcon(Icons.my_location_rounded), findsNothing);

    // Verify top navigation controls exist
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);

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
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.text('Radar'), findsNothing);
  });
}
