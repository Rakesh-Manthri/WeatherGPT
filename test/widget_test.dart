// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_gpt/main.dart';
import 'package:weather_gpt/features/voice/screens/voice_assistant_screen.dart';

void main() {
  testWidgets('WeatherGPT UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WeatherGptApp());

    // Verify header and hero title render.
    expect(find.text('WeatherGPT'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Verify input placeholder renders.
    expect(find.text('Ask weather...'), findsOneWidget);

    // Verify search and image toggle icons exist.
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);

    // Tap the image toggle button
    await tester.tap(find.byIcon(Icons.image_rounded));
    await tester.pumpAndSettle();

    // Verify text field accepts input
    await tester.enterText(find.byType(TextField), 'What is the weather in Tokyo?');
    // Tap the wave button to open VoiceAssistantScreen
    await tester.tap(find.byType(CustomPaint).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify VoiceAssistantScreen is displayed
    expect(find.byType(VoiceAssistantScreen), findsOneWidget);
    expect(find.byType(AnimatedParticleCloud), findsOneWidget);
    expect(find.text('Say something...'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tap close button to return
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify back on WeatherGPT screen
    expect(find.text('WeatherGPT'), findsOneWidget);
  });
}
