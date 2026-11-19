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
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);

    // Verify GIS layer selector pills
    expect(find.text('Clean Map'), findsOneWidget);
    expect(find.text('Rain Radar'), findsOneWidget);
    expect(find.text('AQI Heatmap'), findsOneWidget);

    // Tap Chat toggle option (index 0)
    final chatToggleOption = find.byIcon(Icons.chat_bubble_outline_rounded);
    expect(chatToggleOption, findsOneWidget);
    await tester.tap(chatToggleOption);
    await tester.pump();

    expect(backToChatCalled, isTrue);
  });

  testWidgets('MapScreen activates Rainfall Radar Animation and controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          weatherData: testWeatherData,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap 'Rain Radar' layer tab
    await tester.tap(find.text('Rain Radar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Radar animation controls & dBZ legend render
    expect(find.text('Rainfall Radar Sweep'), findsOneWidget);
    expect(find.textContaining('dBZ'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Tap pause button
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('MapScreen activates AQI Heatmap layer and displays dispersion legend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          weatherData: testWeatherData,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap 'AQI Heatmap' layer tab
    await tester.tap(find.text('AQI Heatmap'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify AQI legend renders
    expect(find.textContaining('Air Quality Heatmap'), findsOneWidget);
  });

  testWidgets('MapScreen opens Share Weather Report Card preview modal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          weatherData: testWeatherData,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Share Report Card button
    final shareBtn = find.byIcon(Icons.share_rounded);
    expect(shareBtn, findsOneWidget);
    await tester.tap(shareBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify share modal and WeatherShareCard render
    expect(find.text('Share Weather Report'), findsOneWidget);
    expect(find.text('Weather GPT'), findsOneWidget);
    expect(find.text('Share Report Card'), findsOneWidget);
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
