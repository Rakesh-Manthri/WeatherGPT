import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/location/location_service.dart';

/// Live Weather Data Model
class LiveWeatherData {
  final String locationName;
  final double latitude;
  final double longitude;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double precipitation;
  final double windSpeed;
  final int windDirection;
  final double windGusts;
  final double pressure;
  final double uvIndex;
  final int weatherCode;
  final bool isDay;
  final String sunrise;
  final String sunset;
  final double tempMax;
  final double tempMin;
  final int aqi;
  final double pm25;
  final double pm10;
  final double no2;
  final double so2;
  final double co;
  final double o3;
  final List<HourlyWeatherItem> hourly;
  final List<DailyWeatherItem> daily;
  final DateTime updatedAt;

  const LiveWeatherData({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.pressure,
    required this.uvIndex,
    required this.weatherCode,
    required this.isDay,
    required this.sunrise,
    required this.sunset,
    required this.tempMax,
    required this.tempMin,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.no2,
    required this.so2,
    required this.co,
    required this.o3,
    required this.hourly,
    required this.daily,
    required this.updatedAt,
  });

  String get conditionText {
    switch (weatherCode) {
      case 0:
        return isDay ? 'Clear Sky' : 'Clear Night';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Partly Cloudy';
    }
  }

  IconData get conditionIcon {
    switch (weatherCode) {
      case 0:
        return isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;
      case 1:
      case 2:
        return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_queue_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop_rounded;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  String get windDirectionCardinal {
    const cardinals = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    final index = ((windDirection + 11.25) / 22.5).floor() % 16;
    return cardinals[index];
  }

  String get aqiStatus {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  Color get aqiColor {
    if (aqi <= 50) return const Color(0xFF34A853);
    if (aqi <= 100) return const Color(0xFFFBBC04);
    if (aqi <= 150) return const Color(0xFFFA7B17);
    if (aqi <= 200) return const Color(0xFFEA4335);
    if (aqi <= 300) return const Color(0xFF8E24AA);
    return const Color(0xFF7E0023);
  }
}

class HourlyWeatherItem {
  final String time;
  final double temp;
  final int weatherCode;
  final int humidity;

  const HourlyWeatherItem({
    required this.time,
    required this.temp,
    required this.weatherCode,
    required this.humidity,
  });
}

class DailyWeatherItem {
  final String dayName;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;

  const DailyWeatherItem({
    required this.dayName,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
  });
}

class LiveWeatherScreen extends StatefulWidget {
  const LiveWeatherScreen({super.key});

  @override
  State<LiveWeatherScreen> createState() => _LiveWeatherScreenState();
}

class _LiveWeatherScreenState extends State<LiveWeatherScreen> {
  final Dio _dio = Dio();
  bool _isLoading = true;
  String? _errorMessage;
  LiveWeatherData? _weatherData;

  @override
  void initState() {
    super.initState();
    _fetchLiveWeather();
  }

  Future<void> _fetchLiveWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Determine Position
      double lat = 28.6139;
      double lon = 77.2090;
      String locationName = 'New Delhi, India';

      try {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          lat = pos.latitude;
          lon = pos.longitude;
        }
      } catch (e) {
        debugPrint('Location lookup fallback: $e');
      }

      // 2. Reverse Geocode (Async attempt)
      try {
        final geoResponse = await _dio.get(
          'https://api.bigdatacloud.net/data/reverse-geocode-client',
          queryParameters: {
            'latitude': lat,
            'longitude': lon,
            'localityLanguage': 'en',
          },
          options: Options(receiveTimeout: const Duration(seconds: 4)),
        );
        if (geoResponse.statusCode == 200 && geoResponse.data is Map) {
          final data = geoResponse.data as Map;
          final city = data['city'] ?? data['locality'] ?? data['principalSubdivision'] ?? '';
          final country = data['countryName'] ?? '';
          if (city.isNotEmpty && country.isNotEmpty) {
            locationName = '$city, $country';
          } else if (city.isNotEmpty) {
            locationName = city;
          }
        }
      } catch (_) {}

      // 3. Fetch Open-Meteo Forecast & Current Weather
      final weatherResponse = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': [
            'temperature_2m',
            'relative_humidity_2m',
            'apparent_temperature',
            'is_day',
            'precipitation',
            'rain',
            'weather_code',
            'surface_pressure',
            'wind_speed_10m',
            'wind_direction_10m',
            'wind_gusts_10m',
            'uv_index',
          ].join(','),
          'hourly': 'temperature_2m,relative_humidity_2m,weather_code',
          'daily': [
            'weather_code',
            'temperature_2m_max',
            'temperature_2m_min',
            'sunrise',
            'sunset',
            'uv_index_max',
          ].join(','),
          'timezone': 'auto',
        },
      );

      // 4. Fetch Air Quality Data
      dynamic aqiData;
      try {
        final aqiResponse = await _dio.get(
          'https://air-quality-api.open-meteo.com/v1/air-quality',
          queryParameters: {
            'latitude': lat,
            'longitude': lon,
            'current': [
              'us_aqi',
              'pm2_5',
              'pm10',
              'carbon_monoxide',
              'nitrogen_dioxide',
              'sulphur_dioxide',
              'ozone',
            ].join(','),
            'timezone': 'auto',
          },
          options: Options(receiveTimeout: const Duration(seconds: 4)),
        );
        if (aqiResponse.statusCode == 200) {
          aqiData = aqiResponse.data['current'];
        }
      } catch (e) {
        debugPrint('AQI lookup fallback: $e');
      }

      final wCurrent = weatherResponse.data['current'] ?? {};
      final wDaily = weatherResponse.data['daily'] ?? {};
      final wHourly = weatherResponse.data['hourly'] ?? {};

      // Parse Hourly (Next 24 hours)
      final List<HourlyWeatherItem> hourlyList = [];
      if (wHourly['time'] is List) {
        final List times = wHourly['time'];
        final List temps = wHourly['temperature_2m'] ?? [];
        final List codes = wHourly['weather_code'] ?? [];
        final List hums = wHourly['relative_humidity_2m'] ?? [];

        final nowIso = DateTime.now().toIso8601String().substring(0, 13);
        int startIndex = times.indexWhere((t) => t.toString().startsWith(nowIso));
        if (startIndex == -1) startIndex = 0;

        for (int i = startIndex; i < min(startIndex + 24, times.length); i++) {
          final tStr = times[i].toString();
          final dt = DateTime.tryParse(tStr) ?? DateTime.now();
          final hourStr = '${dt.hour.toString().padLeft(2, '0')}:00';
          hourlyList.add(
            HourlyWeatherItem(
              time: i == startIndex ? 'Now' : hourStr,
              temp: (temps.length > i ? (temps[i] as num).toDouble() : 25.0),
              weatherCode: (codes.length > i ? (codes[i] as num).toInt() : 0),
              humidity: (hums.length > i ? (hums[i] as num).toInt() : 50),
            ),
          );
        }
      }

      // Parse Daily (Next 7 days)
      final List<DailyWeatherItem> dailyList = [];
      if (wDaily['time'] is List) {
        final List dTimes = wDaily['time'];
        final List maxTemps = wDaily['temperature_2m_max'] ?? [];
        final List minTemps = wDaily['temperature_2m_min'] ?? [];
        final List dCodes = wDaily['weather_code'] ?? [];

        const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        for (int i = 0; i < min(7, dTimes.length); i++) {
          final dt = DateTime.tryParse(dTimes[i].toString()) ?? DateTime.now().add(Duration(days: i));
          final name = i == 0 ? 'Today' : dayNames[dt.weekday - 1];
          dailyList.add(
            DailyWeatherItem(
              dayName: name,
              weatherCode: dCodes.length > i ? (dCodes[i] as num).toInt() : 0,
              maxTemp: maxTemps.length > i ? (maxTemps[i] as num).toDouble() : 30.0,
              minTemp: minTemps.length > i ? (minTemps[i] as num).toDouble() : 20.0,
            ),
          );
        }
      }

      // Sunrise & Sunset formatting
      String sunriseFormatted = '06:00 AM';
      String sunsetFormatted = '06:30 PM';
      if (wDaily['sunrise'] is List && (wDaily['sunrise'] as List).isNotEmpty) {
        final raw = wDaily['sunrise'][0].toString();
        final dt = DateTime.tryParse(raw);
        if (dt != null) {
          final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          sunriseFormatted = '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
        }
      }
      if (wDaily['sunset'] is List && (wDaily['sunset'] as List).isNotEmpty) {
        final raw = wDaily['sunset'][0].toString();
        final dt = DateTime.tryParse(raw);
        if (dt != null) {
          final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          sunsetFormatted = '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
        }
      }

      if (mounted) {
        setState(() {
          _weatherData = LiveWeatherData(
            locationName: locationName,
            latitude: lat,
            longitude: lon,
            temperature: (wCurrent['temperature_2m'] as num?)?.toDouble() ?? 28.0,
            apparentTemperature: (wCurrent['apparent_temperature'] as num?)?.toDouble() ?? 30.0,
            humidity: (wCurrent['relative_humidity_2m'] as num?)?.toInt() ?? 65,
            precipitation: (wCurrent['precipitation'] as num?)?.toDouble() ?? 0.0,
            windSpeed: (wCurrent['wind_speed_10m'] as num?)?.toDouble() ?? 12.0,
            windDirection: (wCurrent['wind_direction_10m'] as num?)?.toInt() ?? 180,
            windGusts: (wCurrent['wind_gusts_10m'] as num?)?.toDouble() ?? 16.0,
            pressure: (wCurrent['surface_pressure'] as num?)?.toDouble() ?? 1013.0,
            uvIndex: (wCurrent['uv_index'] as num?)?.toDouble() ?? 5.5,
            weatherCode: (wCurrent['weather_code'] as num?)?.toInt() ?? 1,
            isDay: (wCurrent['is_day'] as num?)?.toInt() == 1,
            sunrise: sunriseFormatted,
            sunset: sunsetFormatted,
            tempMax: (wDaily['temperature_2m_max'] is List && wDaily['temperature_2m_max'].isNotEmpty)
                ? (wDaily['temperature_2m_max'][0] as num).toDouble()
                : 32.0,
            tempMin: (wDaily['temperature_2m_min'] is List && wDaily['temperature_2m_min'].isNotEmpty)
                ? (wDaily['temperature_2m_min'][0] as num).toDouble()
                : 22.0,
            aqi: (aqiData?['us_aqi'] as num?)?.toInt() ?? 72,
            pm25: (aqiData?['pm2_5'] as num?)?.toDouble() ?? 24.5,
            pm10: (aqiData?['pm10'] as num?)?.toDouble() ?? 52.0,
            no2: (aqiData?['nitrogen_dioxide'] as num?)?.toDouble() ?? 18.0,
            so2: (aqiData?['sulphur_dioxide'] as num?)?.toDouble() ?? 6.0,
            co: (aqiData?['carbon_monoxide'] as num?)?.toDouble() ?? 320.0,
            o3: (aqiData?['ozone'] as num?)?.toDouble() ?? 45.0,
            hourly: hourlyList,
            daily: dailyList,
            updatedAt: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load live weather. Please check connection.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar matching the signature pill style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Circular Back Button Pill
                  _WeatherCircularIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Pill Styled Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Live Weather',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  // Circular Refresh Button Pill
                  _WeatherCircularIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: _fetchLiveWeather,
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF1C1C1E),
                            strokeWidth: 2.5,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Fetching live telemetry...',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF999999)),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF555555), fontSize: 15),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchLiveWeather,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1C1C1E),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchLiveWeather,
                          color: const Color(0xFF1C1C1E),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                            children: [
                              // 1. Hero Current Weather Card
                              _buildHeroWeatherCard(_weatherData!),
                              const SizedBox(height: 16),

                              // 2. Air Quality Index (AQI) Banner Card
                              _buildAqiCard(_weatherData!),
                              const SizedBox(height: 16),

                              // 3. Hourly Forecast Horizontal Scroll
                              _buildHourlyForecastSection(_weatherData!),
                              const SizedBox(height: 16),

                              // 4. Primary Metrics Grid (Humidity, Precipitation, Wind, Pressure, UV, Sunset)
                              _buildTelemetryGrid(_weatherData!),
                              const SizedBox(height: 16),

                              // 5. Sun & Solar Tracker Card
                              _buildSunTrackerCard(_weatherData!),
                              const SizedBox(height: 16),

                              // 6. 7-Day Forecast Card
                              _buildDailyForecastSection(_weatherData!),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Hero Weather Card
  Widget _buildHeroWeatherCard(LiveWeatherData data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location header with GPS indicator
          Row(
            children: [
              const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF1A73E8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF2E7D32)),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Big Temp & Condition Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.temperature.round()}°',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 64,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1C1C1E),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.conditionText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Feels like ${data.apparentTemperature.round()}°  •  H: ${data.tempMax.round()}°  L: ${data.tempMin.round()}°',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  data.conditionIcon,
                  size: 40,
                  color: data.isDay ? const Color(0xFFF59E0B) : const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Air Quality Index (AQI) Banner
  Widget _buildAqiCard(LiveWeatherData data) {
    final double norm = min(1.0, data.aqi / 300.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.air_rounded, size: 20, color: data.aqiColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Air Quality Index (AQI)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: data.aqiColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  data.aqiStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: data.aqiColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big AQI value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data.aqi}',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: data.aqiColor,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'US AQI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Colored Gradient Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF34A853),
                        Color(0xFFFBBC04),
                        Color(0xFFFA7B17),
                        Color(0xFFEA4335),
                        Color(0xFF8E24AA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 1.0 - norm,
                  alignment: Alignment.centerRight,
                  child: Container(
                    height: 6,
                    color: const Color(0xFFE0E0E0).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Micro pollutants breakdown (PM2.5, PM10, NO2, O3)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPollutantChip('PM2.5', '${data.pm25.round()} µg/m³'),
              _buildPollutantChip('PM10', '${data.pm10.round()} µg/m³'),
              _buildPollutantChip('NO₂', '${data.no2.round()} µg/m³'),
              _buildPollutantChip('O₃', '${data.o3.round()} µg/m³'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
          ),
        ],
      ),
    );
  }

  /// 3. Hourly Forecast Section (24 Hours Horizontal Strip)
  Widget _buildHourlyForecastSection(LiveWeatherData data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF555555)),
                SizedBox(width: 8),
                Text(
                  '24-Hour Forecast',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: data.hourly.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = data.hourly[index];
                final isNow = index == 0;
                return Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isNow ? const Color(0xFF1C1C1E) : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                          color: isNow ? Colors.white : const Color(0xFF777777),
                        ),
                      ),
                      Icon(
                        _getWeatherIcon(item.weatherCode),
                        size: 20,
                        color: isNow ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                      Text(
                        '${item.temp.round()}°',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isNow ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Primary Telemetry Grid (Humidity, Precipitation, Wind, Pressure)
  Widget _buildTelemetryGrid(LiveWeatherData data) {
    return Column(
      children: [
        Row(
          children: [
            // Humidity Card
            Expanded(
              child: _buildMetricTile(
                icon: Icons.water_drop_outlined,
                iconColor: const Color(0xFF0288D1),
                title: 'Humidity',
                value: '${data.humidity}%',
                subtitle: 'Dew point ${data.apparentTemperature.round()}°',
              ),
            ),
            const SizedBox(width: 14),
            // Precipitation Card
            Expanded(
              child: _buildMetricTile(
                icon: Icons.grain_rounded,
                iconColor: const Color(0xFF3949AB),
                title: 'Precipitation',
                value: '${data.precipitation} mm',
                subtitle: data.precipitation > 0 ? 'Rain active' : 'No rain expected',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Wind Card
            Expanded(
              child: _buildMetricTile(
                icon: Icons.air_rounded,
                iconColor: const Color(0xFF00897B),
                title: 'Wind Status',
                value: '${data.windSpeed.round()} km/h',
                subtitle: '${data.windDirectionCardinal} (${data.windDirection}°) • Gusts ${data.windGusts.round()}',
              ),
            ),
            const SizedBox(width: 14),
            // Pressure & UV Card
            Expanded(
              child: _buildMetricTile(
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFF8E24AA),
                title: 'Pressure',
                value: '${data.pressure.round()} hPa',
                subtitle: 'UV Index: ${data.uvIndex.round()} (${_getUvDescription(data.uvIndex)})',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Sun & Solar Tracker (Sunrise & Sunset)
  Widget _buildSunTrackerCard(LiveWeatherData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_twilight_rounded, size: 20, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text(
                'Solar Ephemeris',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Sunrise Column
              Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, size: 24, color: Color(0xFFF97316)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sunrise',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.sunrise,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                  ),
                ],
              ),

              // Sun Arc Visual Indicator
              Column(
                children: [
                  const Icon(Icons.brightness_medium_rounded, size: 28, color: Color(0xFFF59E0B)),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Daylight active',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                  ),
                ],
              ),

              // Sunset Column
              Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                    ),
                    child: const Icon(Icons.nights_stay_rounded, size: 24, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sunset',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.sunset,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 6. 7-Day Daily Forecast Section
  Widget _buildDailyForecastSection(LiveWeatherData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF555555)),
              SizedBox(width: 8),
              Text(
                '7-Day Forecast',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.daily.length,
            separatorBuilder: (context, index) => const Divider(height: 18, color: Color(0xFFF0F0F0)),
            itemBuilder: (context, index) {
              final day = data.daily[index];
              return Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      day.dayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: index == 0 ? FontWeight.bold : FontWeight.w500,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  Icon(_getWeatherIcon(day.weatherCode), size: 20, color: const Color(0xFF555555)),
                  const SizedBox(width: 16),
                  Text(
                    '${day.minTemp.round()}°',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF60A5FA), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${day.maxTemp.round()}°',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
        return Icons.water_drop_rounded;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  String _getUvDescription(double uv) {
    if (uv <= 2) return 'Low';
    if (uv <= 5) return 'Moderate';
    if (uv <= 7) return 'High';
    if (uv <= 10) return 'Very High';
    return 'Extreme';
  }
}

/// Circular Header Navigation Button for Live Weather Screen
class _WeatherCircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _WeatherCircularIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }
}
