import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_gpt/core/api/weather_api_client.dart';
import 'package:weather_gpt/features/chat/screens/chat_screen.dart';
import 'package:weather_gpt/features/map/screens/map_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeatherApiClient.setForceOfflineMode(true);
  });

  tearDown(() async {
    await WeatherApiClient.setForceOfflineMode(false);
  });

  testWidgets('ChatScreen switches to MapScreen via top segmented toggle and returns', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          initialQuery: 'What is the weather in Hyderabad?',
        ),
      ),
    );

    // Initial pump and wait for location query timer
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    // Verify ChatScreen is mounted and toggle is present
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);

    // Find the Mountain/Map toggle option (second child of toggle)
    final mapToggleOption = find.byIcon(Icons.landscape_rounded);
    expect(mapToggleOption, findsOneWidget);

    // Tap to switch from Chat to GIS/Map
    await tester.tap(mapToggleOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify MapScreen is now active with GIS overlays
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('1km UHI'), findsOneWidget);

    // Tap Chat toggle option in MapScreen to switch back
    final chatToggleOption = find.byIcon(Icons.chat_bubble_outline_rounded).last;
    await tester.tap(chatToggleOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify returned to ChatScreen smoothly
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
  });
}
