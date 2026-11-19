import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_gpt/features/weather/screens/live_weather_screen.dart';

void main() {
  group('LiveWeatherScreen UI & Aesthetic Tests', () {
    testWidgets('renders Midnight Blue dashboard with Secunderabad telemetry matching screenshots', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockWeatherData = {
        'location_name': 'Secunderabad',
        'latitude': 17.4399,
        'longitude': 78.4983,
        'temperature': 21.0,
        'apparent_temperature': 19.0,
        'condition': 'Clear',
        'weather_code': 0,
        'temp_max': 28.0,
        'temp_min': 14.0,
        'humidity': 44,
        'wind_speed': 14.9,
        'wind_direction': 0,
        'pressure': 1013.0,
        'uv_index': 0.0,
        'rain_chance': 0,
        'aqi': 106,
        'is_day': false,
        'is_weathernext_primary': true,
        'ensemble_spread_c': 0.89,
        'hourly': [
          {'time': 'Now', 'temp': 21, 'weather_code': 0, 'wind_speed': 14.9},
          {'time': '22:00', 'temp': 20, 'weather_code': 0, 'wind_speed': 13.0},
          {'time': '23:00', 'temp': 19, 'weather_code': 0, 'wind_speed': 11.1},
          {'time': '00:00', 'temp': 18, 'weather_code': 0, 'wind_speed': 11.1},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: LiveWeatherScreen(
            initialLocationName: 'Secunderabad',
            initialWeatherData: mockWeatherData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Top App Bar
      expect(find.text('Secunderabad'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Verify Hero Temperature & Condition
      expect(find.text('21'), findsOneWidget);
      expect(find.text('Clear  28°/14°'), findsOneWidget);
      expect(find.text('AQI 106'), findsWidgets);

      // Verify 5-Day Forecast Card
      expect(find.text('5-day forecast'), findsWidgets);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);

      // Verify 24-Hour Forecast Card
      expect(find.text('24-hour forecast'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);

      // Verify Asymmetric Metric Grid
      expect(find.text('North'), findsOneWidget);
      expect(find.text('14.9km/h'), findsWidgets);
      expect(find.text('06:23 Sunrise'), findsOneWidget);
      expect(find.text('17:40 Sunset'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('44%'), findsOneWidget);
      expect(find.text('Real feel'), findsOneWidget);
      expect(find.text('19°'), findsOneWidget);
      expect(find.text('1013mbar'), findsOneWidget);

      // Test expanding 5-day forecast
      final expandButton = find.text('5-day forecast').last;
      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
    });

    testWidgets('renders Daytime Azure dashboard with Oskaloosa telemetry and allows theme toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockDaytimeData = {
        'location_name': 'Oskaloosa',
        'latitude': 41.2964,
        'longitude': -92.6444,
        'temperature': 18.0,
        'apparent_temperature': 20.0,
        'condition': 'Clear',
        'weather_code': 0,
        'temp_max': 20.0,
        'temp_min': 8.0,
        'humidity': 72,
        'wind_speed': 9.8,
        'wind_direction': 180,
        'pressure': 1023.0,
        'uv_index': 3.0,
        'rain_chance': 0,
        'aqi': 26,
        'is_day': true,
        'is_weathernext_primary': true,
        'ensemble_spread_c': 0.82,
        'hourly': [
          {'time': 'Now', 'temp': 18, 'weather_code': 0, 'wind_speed': 9.8, 'is_day': true},
          {'time': '13:00', 'temp': 19, 'weather_code': 0, 'wind_speed': 16.7, 'is_day': true},
          {'time': '14:00', 'temp': 20, 'weather_code': 0, 'wind_speed': 16.7, 'is_day': true},
          {'time': '15:00', 'temp': 19, 'weather_code': 0, 'wind_speed': 16.7, 'is_day': true},
          {'time': '16:00', 'temp': 18, 'weather_code': 0, 'wind_speed': 14.8, 'is_day': true},
          {'time': '17:00', 'temp': 16, 'weather_code': 0, 'wind_speed': 13.0, 'is_day': true},
          {'time': '17:04', 'temp': 15, 'weather_code': 0, 'wind_speed': 13.0, 'is_day': false, 'custom_label': 'Sunset'},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: LiveWeatherScreen(
            initialLocationName: 'Oskaloosa',
            initialWeatherData: mockDaytimeData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Top App Bar with Oskaloosa and navigation indicator
      expect(find.text('Oskaloosa'), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsOneWidget);

      // Verify Hero Section (Daytime Azure: 18°C, Clear 20°/8°, Leaf icon AQI 26)
      expect(find.text('18'), findsWidgets);
      expect(find.text('Clear  20°/8°'), findsOneWidget);
      expect(find.text('AQI 26'), findsWidgets);
      expect(find.byIcon(Icons.eco_rounded), findsWidgets);

      // Verify 24-Hour Forecast Curve and Sunset time point
      expect(find.text('24-hour forecast'), findsOneWidget);
      expect(find.text('17:04'), findsOneWidget);

      // Verify Compass and Vital Metrics for Daytime Oskaloosa
      expect(find.text('South'), findsOneWidget);
      expect(find.text('9.8km/h'), findsWidgets);
      expect(find.text('07:09 Sunrise'), findsOneWidget);
      expect(find.text('17:04 Sunset'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('20°'), findsWidgets);
      expect(find.text('1023mbar'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // UV 3

      // Verify Interactive Theme Toggle in PopupMenuButton
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Switch to Night View'), findsOneWidget);
      await tester.tap(find.text('Switch to Night View'));
      await tester.pumpAndSettle();

      // Check popup menu again to verify switched state
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Switch to Day View'), findsOneWidget);
    });
  });
}
