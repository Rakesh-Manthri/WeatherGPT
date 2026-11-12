import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_gpt/core/api/weather_api_client.dart';
import 'package:weather_gpt/main.dart';
import 'package:weather_gpt/features/map/screens/map_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeatherApiClient.setForceOfflineMode(true);
  });

  tearDown(() async {
    await WeatherApiClient.setForceOfflineMode(false);
  });

  testWidgets('WeatherGPT UI smoke and GIS map toggle test', (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherGptApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify header and hero title render
    expect(find.text('WeatherGPT'), findsOneWidget);

    // Verify input placeholder renders
    expect(find.text('Ask weather...'), findsOneWidget);

    // Verify search and map toggle icons exist
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.landscape_rounded), findsOneWidget);

    // Tap the map toggle button (switching to GIS/map)
    await tester.tap(find.byIcon(Icons.landscape_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify MapScreen with GIS overlays is active
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('1km UHI'), findsOneWidget);

    // Tap chat toggle in MapScreen to return to search mode
    final chatToggle = find.byIcon(Icons.chat_bubble_outline_rounded);
    expect(chatToggle, findsOneWidget);
    await tester.tap(chatToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify returned to Search mode
    expect(find.text('Ask weather...'), findsOneWidget);
    expect(find.text('WeatherGPT'), findsOneWidget);
  });
}
