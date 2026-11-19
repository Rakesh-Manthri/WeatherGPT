import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_gpt/core/api/weather_api_client.dart';
import 'package:weather_gpt/features/news/screens/news_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeatherApiClient.setForceOfflineMode(true);
  });

  tearDown(() async {
    await WeatherApiClient.setForceOfflineMode(false);
  });

  testWidgets('NewsScreen renders header pill and category chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NewsScreen(),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify header pill
    expect(find.text('Weather & Agro Bulletins'), findsOneWidget);

    // Verify multi-source chips
    expect(find.text('All Sources'), findsOneWidget);
    expect(find.text('Govt (IMD/NDMA)'), findsOneWidget);
    expect(find.text('Global (BBC/Reuters)'), findsOneWidget);
    expect(find.text('Science (ISRO/ICAR)'), findsOneWidget);

    // Verify category chips
    expect(find.text('All Updates'), findsOneWidget);
    expect(find.text('Disaster Alerts'), findsOneWidget);
    expect(find.text('Krishi & Sowing'), findsOneWidget);
    expect(find.text('Cyclones & Squalls'), findsOneWidget);

    // Verify news articles render with fallback/mock data
    expect(find.textContaining('Cyclone Alert'), findsWidgets);
    expect(find.textContaining('Sowing Advisory'), findsWidgets);

    // Verify citation authorities
    expect(find.textContaining('India Meteorological Department (IMD)'), findsWidgets);
  });

  testWidgets('NewsScreen filters articles when category chip is selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NewsScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on 'Disaster Alerts' category chip
    final alertsChip = find.text('Disaster Alerts');
    expect(alertsChip, findsOneWidget);

    await tester.tap(alertsChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify filtered alert card
    expect(find.textContaining('Disaster Response Teams'), findsOneWidget);
  });

  testWidgets('NewsScreen filters articles when multi-source chip is selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NewsScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on 'Global (BBC/Reuters)' source chip
    final globalSourceChip = find.text('Global (BBC/Reuters)');
    expect(globalSourceChip, findsOneWidget);

    await tester.tap(globalSourceChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify global wire article is displayed
    expect(find.textContaining('BBC Climate Watch'), findsOneWidget);
    expect(find.text('🌍 Global'), findsOneWidget);
  });
}
