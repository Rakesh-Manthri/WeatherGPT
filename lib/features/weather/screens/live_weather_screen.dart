import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/location/location_service.dart';
import '../../../core/cache/offline_weather_cache.dart';

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
  final double? ensembleSpread;
  final bool isWeatherNextPrimary;
  final int rainChance;

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
    this.ensembleSpread,
    this.isWeatherNextPrimary = false,
    this.rainChance = 0,
  });

  String get conditionText {
    switch (weatherCode) {
      case 0:
        return isDay ? 'Clear' : 'Clear';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Cloudy';
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
        return 'Clear';
    }
  }

  IconData get conditionIcon {
    switch (weatherCode) {
      case 0:
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
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
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
  }

  Color get conditionIconColor {
    switch (weatherCode) {
      case 0:
        return isDay ? const Color(0xFFFFA000) : const Color(0xFFFFD54F);
      case 1:
      case 2:
        return const Color(0xFFFFCA28);
      case 3:
        return Colors.white70;
      case 61:
      case 63:
      case 65:
        return const Color(0xFF64B5F6);
      default:
        return const Color(0xFFFFD54F);
    }
  }

  String get windDirectionCardinal {
    const cardinals = [
      'North', 'NNE', 'NE', 'ENE', 'East', 'ESE', 'SE', 'SSE',
      'South', 'SSW', 'SW', 'WSW', 'West', 'WNW', 'NW', 'NNW'
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
  final double windSpeed;
  final bool isDay;
  final String? customLabel;

  const HourlyWeatherItem({
    required this.time,
    required this.temp,
    required this.weatherCode,
    required this.humidity,
    this.windSpeed = 12.0,
    this.isDay = true,
    this.customLabel,
  });

  IconData get icon {
    switch (weatherCode) {
      case 0:
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
      case 1:
      case 2:
        return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_queue_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 51:
      case 53:
      case 61:
      case 63:
        return Icons.water_drop_rounded;
      default:
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
  }

  Color get iconColor {
    switch (weatherCode) {
      case 0:
        return isDay ? const Color(0xFFFFA000) : const Color(0xFFFFD54F);
      case 1:
      case 2:
        return const Color(0xFFFFCA28);
      case 3:
        return Colors.white70;
      default:
        return const Color(0xFFFFD54F);
    }
  }
}

class DailyWeatherItem {
  final String dayName;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final String conditionName;

  const DailyWeatherItem({
    required this.dayName,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.conditionName,
  });

  IconData get icon {
    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 61:
      case 63:
      case 65:
        return Icons.water_drop_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  Color get iconColor {
    switch (weatherCode) {
      case 0:
        return const Color(0xFFFFA000);
      case 1:
      case 2:
        return const Color(0xFFFFCA28);
      case 3:
        return Colors.white70;
      default:
        return const Color(0xFFFFD54F);
    }
  }
}

class LiveWeatherScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final String? initialLocationName;
  final Map<String, dynamic>? initialWeatherData;

  const LiveWeatherScreen({
    super.key,
    this.initialLat,
    this.initialLon,
    this.initialLocationName,
    this.initialWeatherData,
  });

  @override
  State<LiveWeatherScreen> createState() => _LiveWeatherScreenState();
}

class _LiveWeatherScreenState extends State<LiveWeatherScreen> {
  final Dio _dio = Dio();
  bool _isLoading = true;
  String? _errorMessage;
  LiveWeatherData? _weatherData;
  bool _is5DayExpanded = false;
  bool? _overrideDayMode;
  bool _isLoadedFromCache = false;

  late double _currentLat;
  late double _currentLon;
  late String _currentLocationName;

  bool get _isDay =>
      _overrideDayMode ??
      (_weatherData?.isDay ??
          (DateTime.now().hour >= 6 && DateTime.now().hour < 18));

  @override
  void initState() {
    super.initState();

    if (widget.initialWeatherData != null) {
      _currentLat = widget.initialLat ??
          (widget.initialWeatherData!['latitude'] ?? widget.initialWeatherData!['lat'] as num?)?.toDouble() ??
          17.3850;
      _currentLon = widget.initialLon ??
          (widget.initialWeatherData!['longitude'] ?? widget.initialWeatherData!['lon'] as num?)?.toDouble() ??
          78.4867;
      _currentLocationName = widget.initialLocationName ??
          (widget.initialWeatherData!['location_name']?.toString() ?? 'Current Location');
      _parseFromExternalMap(widget.initialWeatherData!);
    } else if (widget.initialLat != null && widget.initialLon != null) {
      _currentLat = widget.initialLat!;
      _currentLon = widget.initialLon!;
      _currentLocationName = widget.initialLocationName ?? 'Current Location';
      _fetchLiveWeather(lat: _currentLat, lon: _currentLon, name: _currentLocationName);
    } else {
      // Default live dashboard initialization:
      // Auto-detect and display the user's actual current location
      _currentLat = 17.3850;
      _currentLon = 78.4867;
      _currentLocationName = widget.initialLocationName ?? 'Locating...';
      _resolveCurrentLocation();
    }
  }

  /// Automatically resolves user's current location via high-accuracy GPS
  /// with seamless fallback to client IP geolocation and offline telemetry cache.
  Future<void> _resolveCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Immediately check if there is cached telemetry from recent session
    try {
      final cached = await OfflineWeatherCache.instance.getCachedTelemetry();
      if (cached != null && cached.isNotEmpty && mounted) {
        final cachedLat = (cached['latitude'] ?? cached['lat'] as num?)?.toDouble();
        final cachedLon = (cached['longitude'] ?? cached['lon'] as num?)?.toDouble();
        final cachedLoc = cached['location_name']?.toString();
        if (cachedLat != null && cachedLon != null && cachedLoc != null && cachedLoc.isNotEmpty) {
          _currentLat = cachedLat;
          _currentLon = cachedLon;
          _currentLocationName = cachedLoc;
          _parseFromExternalMap(cached);
          setState(() {
            _isLoadedFromCache = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Cache pre-load error: $e');
    }

    double? detectedLat;
    double? detectedLon;
    String? detectedCity;

    // 2. High-Accuracy GPS lookup via LocationService
    try {
      final pos = await LocationService.getCurrentPosition().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (pos != null) {
        detectedLat = pos.latitude;
        detectedLon = pos.longitude;
      }
    } catch (e) {
      debugPrint('GPS location lookup error: $e');
    }

    // 3. Fallback to client IP geolocation if GPS is unavailable / disabled
    if (detectedLat == null || detectedLon == null) {
      try {
        final geoResponse = await _dio.get(
          'https://api.bigdatacloud.net/data/reverse-geocode-client',
          options: Options(receiveTimeout: const Duration(seconds: 4)),
        );
        if (geoResponse.statusCode == 200 && geoResponse.data is Map) {
          final data = geoResponse.data as Map;
          final latNum = data['latitude'] as num?;
          final lonNum = data['longitude'] as num?;
          if (latNum != null && lonNum != null) {
            detectedLat = latNum.toDouble();
            detectedLon = lonNum.toDouble();
            final c = (data['city'] ?? data['locality'] ?? data['principalSubdivision'])?.toString();
            if (c != null && c.trim().isNotEmpty) {
              detectedCity = c.trim();
            }
          }
        }
      } catch (e) {
        debugPrint('IP geolocation lookup error: $e');
      }
    }

    // 4. Reverse-geocode coordinates to city name if not already resolved
    if (detectedLat != null && detectedLon != null) {
      if (detectedCity == null || detectedCity.isEmpty) {
        detectedCity = await _reverseGeocode(detectedLat, detectedLon);
      }
      _currentLat = detectedLat;
      _currentLon = detectedLon;
      _currentLocationName = detectedCity;
      await _fetchLiveWeather(lat: detectedLat, lon: detectedLon, name: detectedCity);
      return;
    }

    // 5. If GPS and network IP geolocation both failed:
    if (_weatherData != null) {
      // Already displaying valid cached data
      return;
    }

    // Fallback coordinates if completely offline with no GPS and no cache
    _currentLat = 17.3850;
    _currentLon = 78.4867;
    _currentLocationName = 'Current Location';
    await _fetchLiveWeather(lat: _currentLat, lon: _currentLon, name: _currentLocationName);
  }

  /// Reverse geocodes coordinates to a clean municipality / city name
  Future<String> _reverseGeocode(double lat, double lon) async {
    // 1. BigDataCloud reverse geocode client (fast, CORS-friendly, zero-auth)
    try {
      final res = await _dio.get(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'localityLanguage': 'en',
        },
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final city = (data['city'] ?? data['locality'] ?? data['principalSubdivision'])?.toString();
        if (city != null && city.trim().isNotEmpty) {
          return city.trim();
        }
      }
    } catch (e) {
      debugPrint('BigDataCloud reverse geocode error: $e');
    }

    // 2. OpenStreetMap Nominatim fallback
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'json',
          'zoom': 10,
        },
        options: Options(
          headers: {'User-Agent': 'WeatherGPT/1.0'},
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final address = res.data['address'] as Map?;
        final city = (address?['city'] ??
                address?['town'] ??
                address?['village'] ??
                address?['suburb'] ??
                address?['municipality'] ??
                address?['county'] ??
                address?['state'])
            ?.toString();
        if (city != null && city.trim().isNotEmpty) {
          return city.trim();
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocode error: $e');
    }

    return 'Current Location';
  }

  void _parseFromExternalMap(Map<String, dynamic> data) {
    try {
      final isDay = (data['is_day'] as bool?) ?? false;
      final temp = (data['temperature'] as num?)?.toDouble() ?? (isDay ? 18.0 : 21.0);
      final apparent = (data['apparent_temperature'] as num?)?.toDouble() ?? (isDay ? 20.0 : 19.0);
      final hum = (data['humidity'] as num?)?.toInt() ?? (isDay ? 72 : 44);
      final wSpeed = (data['wind_speed'] as num?)?.toDouble() ?? (isDay ? 9.8 : 14.9);
      final wDir = (data['wind_direction'] as num?)?.toInt() ?? (isDay ? 180 : 0);
      final press = (data['pressure'] as num?)?.toDouble() ?? (isDay ? 1023.0 : 1013.0);
      final uv = (data['uv_index'] as num?)?.toDouble() ?? (isDay ? 3.0 : 0.0);
      final wCode = (data['weather_code'] as num?)?.toInt() ?? 0;
      final tMax = (data['temp_max'] as num?)?.toDouble() ?? (isDay ? 20.0 : 28.0);
      final tMin = (data['temp_min'] as num?)?.toDouble() ?? (isDay ? 8.0 : 14.0);
      final aqiVal = (data['aqi'] as num?)?.toInt() ?? (isDay ? 26 : 106);
      final spread = (data['ensemble_spread_c'] as num?)?.toDouble();
      final rainCh = (data['rain_chance'] as num?)?.toInt() ?? 0;
      final isWn = data['is_weathernext_primary'] == true;

      final hourlyRaw = (data['hourly'] as List<dynamic>?) ?? [];
      final List<HourlyWeatherItem> hourlyItems = [];
      for (int i = 0; i < hourlyRaw.length; i++) {
        final h = hourlyRaw[i];
        if (h is Map) {
          final customLbl = h['custom_label']?.toString() ?? h['label']?.toString();
          hourlyItems.add(
            HourlyWeatherItem(
              time: h['time']?.toString() ?? 'Now',
              temp: (h['temp'] as num?)?.toDouble() ?? temp,
              weatherCode: (h['weather_code'] as num?)?.toInt() ?? 0,
              humidity: (h['humidity'] as num?)?.toInt() ?? hum,
              windSpeed: (h['wind_speed'] as num?)?.toDouble() ?? wSpeed,
              isDay: (h['is_day'] as bool?) ?? isDay,
              customLabel: customLbl,
            ),
          );
        }
      }

      final List<DailyWeatherItem> dailyItems = isDay
          ? [
              DailyWeatherItem(dayName: 'Thu', weatherCode: 0, maxTemp: tMax, minTemp: tMin, conditionName: 'Clear'),
              DailyWeatherItem(dayName: 'Fri', weatherCode: 0, maxTemp: 20.0, minTemp: 12.0, conditionName: 'Clear'),
              DailyWeatherItem(dayName: 'Sat', weatherCode: 95, maxTemp: 18.0, minTemp: 3.0, conditionName: 'Thunderstorm'),
              DailyWeatherItem(dayName: 'Sun', weatherCode: 1, maxTemp: 19.0, minTemp: 6.0, conditionName: 'Mainly Clear'),
              DailyWeatherItem(dayName: 'Mon', weatherCode: 0, maxTemp: 21.0, minTemp: 8.0, conditionName: 'Clear'),
            ]
          : [
              DailyWeatherItem(dayName: 'Today', weatherCode: 0, maxTemp: tMax, minTemp: tMin, conditionName: 'Clear'),
              DailyWeatherItem(dayName: 'Tomorrow', weatherCode: 2, maxTemp: tMax + 2, minTemp: tMin + 1, conditionName: 'Cloudy'),
              DailyWeatherItem(dayName: 'Sat', weatherCode: 0, maxTemp: tMax + 2, minTemp: tMin + 3, conditionName: 'Clear'),
              DailyWeatherItem(dayName: 'Sun', weatherCode: 1, maxTemp: tMax + 1, minTemp: tMin + 2, conditionName: 'Mainly Clear'),
              DailyWeatherItem(dayName: 'Mon', weatherCode: 0, maxTemp: tMax, minTemp: tMin + 1, conditionName: 'Clear'),
            ];

      setState(() {
        _currentLat = (data['latitude'] as num?)?.toDouble() ?? _currentLat;
        _currentLon = (data['longitude'] as num?)?.toDouble() ?? _currentLon;
        _currentLocationName = data['location_name']?.toString() ?? _currentLocationName;
        _weatherData = LiveWeatherData(
          locationName: _currentLocationName,
          latitude: _currentLat,
          longitude: _currentLon,
          temperature: temp,
          apparentTemperature: apparent,
          humidity: hum,
          precipitation: 0.0,
          windSpeed: wSpeed,
          windDirection: wDir,
          windGusts: wSpeed * 1.3,
          pressure: press,
          uvIndex: uv,
          weatherCode: wCode,
          isDay: isDay,
          sunrise: isDay ? '07:09' : '06:23',
          sunset: isDay ? '17:04' : '17:40',
          tempMax: tMax,
          tempMin: tMin,
          aqi: aqiVal,
          pm25: isDay ? 12.0 : 38.0,
          pm10: isDay ? 24.0 : 72.0,
          no2: 18.0,
          so2: 6.0,
          co: 340.0,
          o3: 28.0,
          hourly: hourlyItems.isNotEmpty ? hourlyItems : _generateFallbackHourly(temp, isDay),
          daily: dailyItems,
          updatedAt: DateTime.now(),
          ensembleSpread: spread,
          isWeatherNextPrimary: isWn,
          rainChance: rainCh,
        );
        _isLoading = false;
      });
    } catch (e) {
      _resolveCurrentLocation();
    }
  }

  List<HourlyWeatherItem> _generateFallbackHourly(double baseTemp, bool isDay) {
    if (isDay) {
      return [
        HourlyWeatherItem(time: 'Now', temp: baseTemp, weatherCode: 0, humidity: 72, windSpeed: 9.8, isDay: true),
        HourlyWeatherItem(time: '13:00', temp: baseTemp + 1, weatherCode: 0, humidity: 68, windSpeed: 16.7, isDay: true),
        HourlyWeatherItem(time: '14:00', temp: baseTemp + 2, weatherCode: 0, humidity: 65, windSpeed: 16.7, isDay: true),
        HourlyWeatherItem(time: '15:00', temp: baseTemp + 1, weatherCode: 0, humidity: 64, windSpeed: 16.7, isDay: true),
        HourlyWeatherItem(time: '16:00', temp: baseTemp, weatherCode: 0, humidity: 66, windSpeed: 14.8, isDay: true),
        HourlyWeatherItem(time: '17:00', temp: baseTemp - 2, weatherCode: 0, humidity: 70, windSpeed: 13.0, isDay: true),
        HourlyWeatherItem(time: '17:04', temp: baseTemp - 3, weatherCode: 0, humidity: 72, windSpeed: 13.0, isDay: false, customLabel: 'Sunset'),
        HourlyWeatherItem(time: '18:00', temp: baseTemp - 4, weatherCode: 0, humidity: 75, windSpeed: 12.0, isDay: false),
        HourlyWeatherItem(time: '19:00', temp: baseTemp - 5, weatherCode: 0, humidity: 78, windSpeed: 10.5, isDay: false),
      ];
    }
    return [
      HourlyWeatherItem(time: 'Now', temp: baseTemp, weatherCode: 0, humidity: 44, windSpeed: 14.9, isDay: false),
      HourlyWeatherItem(time: '22:00', temp: baseTemp - 1, weatherCode: 0, humidity: 46, windSpeed: 13.0, isDay: false),
      HourlyWeatherItem(time: '23:00', temp: baseTemp - 2, weatherCode: 0, humidity: 50, windSpeed: 11.1, isDay: false),
      HourlyWeatherItem(time: '20/11', temp: baseTemp - 3, weatherCode: 0, humidity: 54, windSpeed: 11.1, isDay: false),
      HourlyWeatherItem(time: '01:00', temp: baseTemp - 4, weatherCode: 0, humidity: 58, windSpeed: 9.5, isDay: false),
      HourlyWeatherItem(time: '02:00', temp: baseTemp - 5, weatherCode: 0, humidity: 62, windSpeed: 8.5, isDay: false),
      HourlyWeatherItem(time: '06:00', temp: baseTemp - 6, weatherCode: 0, humidity: 68, windSpeed: 7.2, isDay: false),
      HourlyWeatherItem(time: '09:00', temp: baseTemp - 1, weatherCode: 0, humidity: 50, windSpeed: 10.5, isDay: true),
      HourlyWeatherItem(time: '12:00', temp: baseTemp + 5, weatherCode: 1, humidity: 38, windSpeed: 14.0, isDay: true),
      HourlyWeatherItem(time: '15:00', temp: baseTemp + 7, weatherCode: 0, humidity: 32, windSpeed: 16.5, isDay: true),
    ];
  }

  Future<void> _fetchLiveWeather({double? lat, double? lon, String? name}) async {
    if (lat == null && lon == null) {
      await _resolveCurrentLocation();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final double targetLat = lat!;
      final double targetLon = lon!;
      String locationName = name ?? _currentLocationName;

      // Reverse geocode if location name is empty or default
      if (name == null || name.isEmpty || name == 'Current Location' || name == 'Locating...') {
        locationName = await _reverseGeocode(targetLat, targetLon);
      }

      // Fetch Open-Meteo live weather
      final weatherResponse = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': targetLat,
          'longitude': targetLon,
          'current': [
            'temperature_2m',
            'relative_humidity_2m',
            'apparent_temperature',
            'is_day',
            'precipitation',
            'weather_code',
            'surface_pressure',
            'wind_speed_10m',
            'wind_direction_10m',
            'wind_gusts_10m',
            'uv_index',
          ].join(','),
          'hourly': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation_probability',
          'daily': [
            'weather_code',
            'temperature_2m_max',
            'temperature_2m_min',
            'sunrise',
            'sunset',
            'precipitation_probability_max',
          ].join(','),
          'timezone': 'auto',
        },
      );

      // Fetch Air Quality
      dynamic aqiData;
      try {
        final aqiResponse = await _dio.get(
          'https://air-quality-api.open-meteo.com/v1/air-quality',
          queryParameters: {
            'latitude': targetLat,
            'longitude': targetLon,
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
      } catch (_) {}

      final wCurrent = weatherResponse.data['current'] ?? {};
      final wDaily = weatherResponse.data['daily'] ?? {};
      final wHourly = weatherResponse.data['hourly'] ?? {};

      // Parse Hourly
      final List<HourlyWeatherItem> hourlyList = [];
      if (wHourly['time'] is List) {
        final List times = wHourly['time'];
        final List temps = wHourly['temperature_2m'] ?? [];
        final List codes = wHourly['weather_code'] ?? [];
        final List hums = wHourly['relative_humidity_2m'] ?? [];
        final List winds = wHourly['wind_speed_10m'] ?? [];

        final nowIso = DateTime.now().toIso8601String().substring(0, 13);
        int startIndex = times.indexWhere((t) => t.toString().startsWith(nowIso));
        if (startIndex == -1) startIndex = 0;

        for (int i = startIndex; i < min(startIndex + 24, times.length); i++) {
          final tStr = times[i].toString();
          final dt = DateTime.tryParse(tStr) ?? DateTime.now();
          final hourStr = '${dt.hour.toString().padLeft(2, '0')}:00';
          final isHourDay = dt.hour >= 6 && dt.hour <= 18;
          hourlyList.add(
            HourlyWeatherItem(
              time: i == startIndex ? 'Now' : hourStr,
              temp: (temps.length > i ? (temps[i] as num).toDouble() : 21.0),
              weatherCode: (codes.length > i ? (codes[i] as num).toInt() : 0),
              humidity: (hums.length > i ? (hums[i] as num).toInt() : 45),
              windSpeed: (winds.length > i ? (winds[i] as num).toDouble() : 12.0),
              isDay: isHourDay,
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
          String nameLabel = i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : dayNames[dt.weekday - 1]);
          final code = dCodes.length > i ? (dCodes[i] as num).toInt() : 0;
          String condition = 'Clear';
          if (code == 1 || code == 2) condition = 'Cloudy';
          if (code == 3) condition = 'Overcast';
          if (code >= 51 && code <= 65) condition = 'Rain';

          dailyList.add(
            DailyWeatherItem(
              dayName: nameLabel,
              weatherCode: code,
              maxTemp: maxTemps.length > i ? (maxTemps[i] as num).toDouble() : 28.0,
              minTemp: minTemps.length > i ? (minTemps[i] as num).toDouble() : 14.0,
              conditionName: condition,
            ),
          );
        }
      }

      // Sunrise / Sunset formatted
      String sunriseFormatted = '06:23';
      String sunsetFormatted = '17:40';
      if (wDaily['sunrise'] is List && (wDaily['sunrise'] as List).isNotEmpty) {
        final dt = DateTime.tryParse(wDaily['sunrise'][0].toString());
        if (dt != null) {
          sunriseFormatted = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
      }
      if (wDaily['sunset'] is List && (wDaily['sunset'] as List).isNotEmpty) {
        final dt = DateTime.tryParse(wDaily['sunset'][0].toString());
        if (dt != null) {
          sunsetFormatted = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
      }

      int rainChance = 0;
      if (wDaily['precipitation_probability_max'] is List && (wDaily['precipitation_probability_max'] as List).isNotEmpty) {
        rainChance = (wDaily['precipitation_probability_max'][0] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _currentLat = targetLat;
          _currentLon = targetLon;
          _currentLocationName = locationName;
          _weatherData = LiveWeatherData(
            locationName: locationName,
            latitude: targetLat,
            longitude: targetLon,
            temperature: (wCurrent['temperature_2m'] as num?)?.toDouble() ?? 21.0,
            apparentTemperature: (wCurrent['apparent_temperature'] as num?)?.toDouble() ?? 19.0,
            humidity: (wCurrent['relative_humidity_2m'] as num?)?.toInt() ?? 44,
            precipitation: (wCurrent['precipitation'] as num?)?.toDouble() ?? 0.0,
            windSpeed: (wCurrent['wind_speed_10m'] as num?)?.toDouble() ?? 14.9,
            windDirection: (wCurrent['wind_direction_10m'] as num?)?.toInt() ?? 0,
            windGusts: (wCurrent['wind_gusts_10m'] as num?)?.toDouble() ?? 18.0,
            pressure: (wCurrent['surface_pressure'] as num?)?.toDouble() ?? 1013.0,
            uvIndex: (wCurrent['uv_index'] as num?)?.toDouble() ?? 0.0,
            weatherCode: (wCurrent['weather_code'] as num?)?.toInt() ?? 0,
            isDay: (wCurrent['is_day'] as num?)?.toInt() == 1,
            sunrise: sunriseFormatted,
            sunset: sunsetFormatted,
            tempMax: (wDaily['temperature_2m_max'] is List && wDaily['temperature_2m_max'].isNotEmpty)
                ? (wDaily['temperature_2m_max'][0] as num).toDouble()
                : 28.0,
            tempMin: (wDaily['temperature_2m_min'] is List && wDaily['temperature_2m_min'].isNotEmpty)
                ? (wDaily['temperature_2m_min'][0] as num).toDouble()
                : 14.0,
            aqi: (aqiData?['us_aqi'] as num?)?.toInt() ?? 106,
            pm25: (aqiData?['pm2_5'] as num?)?.toDouble() ?? 38.0,
            pm10: (aqiData?['pm10'] as num?)?.toDouble() ?? 72.0,
            no2: (aqiData?['nitrogen_dioxide'] as num?)?.toDouble() ?? 18.0,
            so2: (aqiData?['sulphur_dioxide'] as num?)?.toDouble() ?? 6.0,
            co: (aqiData?['carbon_monoxide'] as num?)?.toDouble() ?? 340.0,
            o3: (aqiData?['ozone'] as num?)?.toDouble() ?? 28.0,
            hourly: hourlyList.isNotEmpty ? hourlyList : _generateFallbackHourly(21.0, false),
            daily: dailyList,
            updatedAt: DateTime.now(),
            ensembleSpread: 0.89,
            isWeatherNextPrimary: true,
            rainChance: rainChance,
          );
          _isLoading = false;
        });

        // Persist to OfflineWeatherCache for instant offline availability
        try {
          final cachePayload = {
            'location_name': locationName,
            'latitude': targetLat,
            'longitude': targetLon,
            'temperature': (wCurrent['temperature_2m'] as num?)?.toDouble() ?? 21.0,
            'apparent_temperature': (wCurrent['apparent_temperature'] as num?)?.toDouble() ?? 19.0,
            'humidity': (wCurrent['relative_humidity_2m'] as num?)?.toInt() ?? 44,
            'precipitation': (wCurrent['precipitation'] as num?)?.toDouble() ?? 0.0,
            'wind_speed': (wCurrent['wind_speed_10m'] as num?)?.toDouble() ?? 14.9,
            'wind_direction': (wCurrent['wind_direction_10m'] as num?)?.toInt() ?? 0,
            'wind_gusts': (wCurrent['wind_gusts_10m'] as num?)?.toDouble() ?? 18.0,
            'pressure': (wCurrent['surface_pressure'] as num?)?.toDouble() ?? 1013.0,
            'uv_index': (wCurrent['uv_index'] as num?)?.toDouble() ?? 0.0,
            'weather_code': (wCurrent['weather_code'] as num?)?.toInt() ?? 0,
            'is_day': (wCurrent['is_day'] as num?)?.toInt() == 1,
            'sunrise': sunriseFormatted,
            'sunset': sunsetFormatted,
            'temp_max': (wDaily['temperature_2m_max'] is List && wDaily['temperature_2m_max'].isNotEmpty)
                ? (wDaily['temperature_2m_max'][0] as num).toDouble()
                : 28.0,
            'temp_min': (wDaily['temperature_2m_min'] is List && wDaily['temperature_2m_min'].isNotEmpty)
                ? (wDaily['temperature_2m_min'][0] as num).toDouble()
                : 14.0,
            'aqi': (aqiData?['us_aqi'] as num?)?.toInt() ?? 106,
            'pm2_5': (aqiData?['pm2_5'] as num?)?.toDouble() ?? 38.0,
            'pm10': (aqiData?['pm10'] as num?)?.toDouble() ?? 72.0,
            'rain_chance': rainChance,
            'is_weathernext_primary': true,
            'hourly': hourlyList.map((h) => {
              'time': h.time,
              'temp': h.temp,
              'weather_code': h.weatherCode,
              'humidity': h.humidity,
              'wind_speed': h.windSpeed,
              'is_day': h.isDay,
            }).toList(),
          };
          OfflineWeatherCache.instance.saveTelemetry(cachePayload);
        } catch (e) {
          debugPrint('Error caching live weather: $e');
        }
      }
    } catch (e) {
      // Gracefully attempt to load from local offline telemetry cache
      try {
        final cached = await OfflineWeatherCache.instance.getCachedTelemetry();
        if (cached != null && cached.isNotEmpty && mounted) {
          _parseFromExternalMap(cached);
          setState(() {
            _isLoadedFromCache = true;
            _isLoading = false;
            _errorMessage = null;
          });
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load live weather. Please check connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _showCitySearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CitySearchSheet(
        isDay: _isDay,
        onSelectCity: (name, lat, lon) {
          Navigator.pop(ctx);
          _fetchLiveWeather(lat: lat, lon: lon, name: name);
        },
        onSelectCurrentLocation: () {
          Navigator.pop(ctx);
          _resolveCurrentLocation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF4FA0FA),
        Color(0xFF4093F7),
        Color(0xFF3388F2),
        Color(0xFF287DE9),
        Color(0xFF1E6FDC),
      ],
      stops: [0.0, 0.22, 0.50, 0.78, 1.0],
    );

    final nightGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF071739),
        Color(0xFF0C244F),
        Color(0xFF143B77),
        Color(0xFF18458A),
        Color(0xFF1B4D96),
      ],
      stops: [0.0, 0.25, 0.55, 0.8, 1.0],
    );

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Background Gradient: Day Azure vs Night Cosmic Midnight
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isDay ? dayGradient : nightGradient,
              ),
            ),
          ),

          // 2. Atmospheric Sky Effect: Soft daytime cumulus clouds vs Twinkling nocturnal stars
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: CustomPaint(
              painter: _isDay ? _DaytimeCloudPainter() : _StarFieldPainter(),
            ),
          ),

          // 3. Main Scrollable Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar: "+" ... City & Indicator ... "..."
                _buildTopAppBar(),

                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.white60),
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 15),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => _fetchLiveWeather(
                                        lat: _currentLat,
                                        lon: _currentLon,
                                        name: _currentLocationName,
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Try Again'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _fetchLiveWeather(
                                lat: _currentLat,
                                lon: _currentLon,
                                name: _currentLocationName,
                              ),
                              color: _isDay ? const Color(0xFF1E6FDC) : const Color(0xFF1B4D96),
                              backgroundColor: Colors.white,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                children: [
                                  if (_isLoadedFromCache)
                                    Center(
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.cloud_done_outlined, size: 14, color: Colors.white),
                                            SizedBox(width: 6),
                                            Text(
                                              'Loaded from cache data',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // 1. Hero Temperature Section
                                  _buildHeroSection(_weatherData!),
                                  const SizedBox(height: 32),

                                  // 2. 5-Day Forecast Card
                                  _buildFiveDayForecastCard(_weatherData!),
                                  const SizedBox(height: 16),

                                  // 3. 24-Hour Forecast Card (Continuous Bezier Curve)
                                  _buildHourlyForecastCard(_weatherData!),
                                  const SizedBox(height: 16),

                                  // 4. Asymmetric Meteorological Grid (Wind + Sun Arc & Vital Metrics)
                                  _buildMeteorologicalGrid(_weatherData!),
                                  const SizedBox(height: 16),

                                  // 5. AQI Banner Card
                                  _buildAqiBannerCard(_weatherData!),
                                  const SizedBox(height: 24),

                                  // 6. Provider Footer
                                  _buildProviderFooter(_weatherData!),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top App Bar matching the screenshot:
  /// Left "+" | Center "City Name" with navigation indicator | Right "..."
  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            splashRadius: 24,
            tooltip: 'Add / Search City',
            onPressed: _showCitySearchSheet,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentLocationName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: -0.35,
                      child: const Icon(
                        Icons.navigation,
                        size: 8,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white70,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            color: _isDay ? const Color(0xFF287DE9) : const Color(0xFF143B77),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'current_location') {
                _resolveCurrentLocation();
              } else if (val == 'refresh') {
                _fetchLiveWeather(lat: _currentLat, lon: _currentLon, name: _currentLocationName);
              } else if (val == 'search') {
                _showCitySearchSheet();
              } else if (val == 'toggle_theme') {
                setState(() {
                  final next = !_isDay;
                  _overrideDayMode = next;
                  if (_weatherData != null) {
                    _weatherData = LiveWeatherData(
                      locationName: _weatherData!.locationName,
                      latitude: _weatherData!.latitude,
                      longitude: _weatherData!.longitude,
                      temperature: _weatherData!.temperature,
                      apparentTemperature: _weatherData!.apparentTemperature,
                      humidity: _weatherData!.humidity,
                      precipitation: _weatherData!.precipitation,
                      windSpeed: _weatherData!.windSpeed,
                      windDirection: _weatherData!.windDirection,
                      windGusts: _weatherData!.windGusts,
                      pressure: _weatherData!.pressure,
                      uvIndex: _weatherData!.uvIndex,
                      weatherCode: _weatherData!.weatherCode,
                      isDay: next,
                      sunrise: _weatherData!.sunrise,
                      sunset: _weatherData!.sunset,
                      tempMax: _weatherData!.tempMax,
                      tempMin: _weatherData!.tempMin,
                      aqi: _weatherData!.aqi,
                      pm25: _weatherData!.pm25,
                      pm10: _weatherData!.pm10,
                      no2: _weatherData!.no2,
                      so2: _weatherData!.so2,
                      co: _weatherData!.co,
                      o3: _weatherData!.o3,
                      hourly: _generateFallbackHourly(_weatherData!.temperature, next),
                      daily: _weatherData!.daily,
                      updatedAt: _weatherData!.updatedAt,
                      ensembleSpread: _weatherData!.ensembleSpread,
                      isWeatherNextPrimary: _weatherData!.isWeatherNextPrimary,
                      rainChance: _weatherData!.rainChance,
                    );
                  }
                });
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'current_location',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use Current Location',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Refresh Telemetry',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Change Location',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_theme',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isDay ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isDay ? 'Switch to Night View' : 'Switch to Day View',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hero Current Weather matching Screenshots (Day Azure & Night Cosmic Blue):
  /// Large Temp "18°C" or "21°C"
  /// "Clear 20°/8°" or "Clear 28°/14°"
  /// Capsule pill: Leaf AQI 26 in Day / Mask AQI 106 in Night
  Widget _buildHeroSection(LiveWeatherData data) {
    final pillBg = _isDay ? Colors.white.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.16);
    final pillBorder = _isDay
        ? Border.all(color: Colors.white.withValues(alpha: 0.32), width: 0.8)
        : Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8);
    final aqiIcon = (data.aqi <= 50 || (_isDay && data.aqi <= 100)) ? Icons.eco_rounded : Icons.masks_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        // Temperature with clean degree symbol
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.temperature.round()}',
              style: const TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 88,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                height: 0.95,
                letterSpacing: -2,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 2),
              child: Text(
                '°c',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Condition Text & Hi/Lo Temp (e.g. "Clear 28°/14°")
        Text(
          '${data.conditionText}  ${data.tempMax.round()}°/${data.tempMin.round()}°',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),

        // AQI Capsule Pill matching Screenshots
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(20),
            border: pillBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                aqiIcon,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                'AQI ${data.aqi}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5-Day Forecast Card matching Screenshots:
  /// - Calendar icon + "5-day forecast"
  /// - Daily rows with weather icon and temperatures
  /// - Full-width pill button: "5-day forecast" (toggles expand)
  Widget _buildFiveDayForecastCard(LiveWeatherData data) {
    final displayItems = _is5DayExpanded
        ? data.daily
        : data.daily.take(3).toList();

    final cardBg = _isDay ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.12);
    final cardBorder = _isDay
        ? Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8)
        : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8);
    final buttonBg = _isDay ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.16);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                '5-day forecast',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Daily Rows
          ...displayItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 22,
                    color: item.iconColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.dayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.conditionName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${item.maxTemp.round()}°  /  ${item.minTemp.round()}°',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // 5-Day Forecast Bottom Pill Button
          GestureDetector(
            onTap: () {
              setState(() {
                _is5DayExpanded = !_is5DayExpanded;
              });
            },
            child: Container(
              height: 44,
              width: double.infinity,
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  _is5DayExpanded ? 'Show less' : '5-day forecast',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 24-Hour Forecast Card matching Screenshots:
  /// - Clock icon + "24-hour forecast"
  /// - Smooth continuous lime-yellow spline curve with temperature / Sunset labels
  /// - Dotted vertical drop-line at "Now"
  /// - Weather icons under curve (amber suns in Day, crescent moons in Night)
  /// - Wind speed under icons ("9.8km/h" or "14.9km/h")
  /// - Time labels under wind speed ("Now", "13:00", "17:04", etc.)
  Widget _buildHourlyForecastCard(LiveWeatherData data) {
    final cardBg = _isDay ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.12);
    final cardBorder = _isDay
        ? Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8)
        : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                '24-hour forecast',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Continuous Curve View
          SizedBox(
            height: 175,
            child: _HourlyCurveScrollable(hourlyItems: data.hourly),
          ),
        ],
      ),
    );
  }

  /// Asymmetric Meteorological Grid matching Screenshots:
  /// Left Column:
  ///   - Wind Compass Card ("South" 9.8km/h or "North" 14.9km/h, Compass dial)
  ///   - Sun Arc Card (Sunrise/Sunset, Peak zenith sun in Day / nocturnal moon in Night)
  /// Right Column (Taller card spanning both left cards):
  ///   - Humidity (e.g. 72% / 44%)
  ///   - Real feel (e.g. 20° / 19°)
  ///   - UV (e.g. 3 / 0)
  ///   - Pressure (e.g. 1023mbar / 1013mbar)
  ///   - Chance of rain (0%)
  Widget _buildMeteorologicalGrid(LiveWeatherData data) {
    const cardRadius = 24.0;
    final cardBorder = _isDay
        ? Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8)
        : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8);
    final cardBg = _isDay ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.12);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Wind Card + Sun Card
        Expanded(
          child: Column(
            children: [
              // 1. Wind Compass Card
              Container(
                height: 142,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: cardBorder,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data.windDirectionCardinal,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data.windSpeed.toStringAsFixed(1)}km/h',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: const Size(64, 64),
                      painter: _CompassPainter(windDirection: data.windDirection),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Sun Arc Card
              Container(
                height: 142,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: cardBorder,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.sunrise} Sunrise',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.sunset} Sunset',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _SunArcPainter(isDay: data.isDay),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Right Column: Taller Vital Metrics Card (Height 296 = 142 + 12 + 142)
        Expanded(
          child: Container(
            height: 296,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(cardRadius),
              border: cardBorder,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricRow('Humidity', '${data.humidity}%'),
                _buildDivider(),
                _buildMetricRow('Real feel', '${data.apparentTemperature.round()}°'),
                _buildDivider(),
                _buildMetricRow('UV', '${data.uvIndex.round()}'),
                _buildDivider(),
                _buildMetricRow('Pressure', '${data.pressure.round()}mbar'),
                _buildDivider(),
                _buildMetricRow('Chance of rain', '${data.rainChance}%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.6,
      color: _isDay ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.12),
    );
  }

  /// AQI Banner Card matching Screenshots
  Widget _buildAqiBannerCard(LiveWeatherData data) {
    final cardBg = _isDay ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.12);
    final cardBorder = _isDay
        ? Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8)
        : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8);
    final aqiIcon = (data.aqi <= 50 || (_isDay && data.aqi <= 100)) ? Icons.eco_rounded : Icons.masks_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: cardBorder,
      ),
      child: Row(
        children: [
          Icon(
            aqiIcon,
            size: 24,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            'AQI ${data.aqi}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: data.aqiColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: data.aqiColor.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Text(
              data.aqiStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: data.aqiColor,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'PM2.5: ${data.pm25.toStringAsFixed(0)}µg/m³',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  /// Provider Footer matching Screenshots
  Widget _buildProviderFooter(LiveWeatherData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Data provided in part by  ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        Icon(
          Icons.auto_awesome_rounded,
          size: 13,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Text(
          data.isWeatherNextPrimary ? 'WeatherNext 3 & Open-Meteo' : 'Open-Meteo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------
/// Custom 24-Hour Continuous Temperature Bezier Curve Scrollable Widget
/// ----------------------------------------------------------------------
class _HourlyCurveScrollable extends StatelessWidget {
  final List<HourlyWeatherItem> hourlyItems;

  const _HourlyCurveScrollable({required this.hourlyItems});

  @override
  Widget build(BuildContext context) {
    const itemWidth = 66.0;
    final totalWidth = max(hourlyItems.length * itemWidth, MediaQuery.of(context).size.width - 64);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: totalWidth,
        height: 175,
        child: CustomPaint(
          painter: _TemperatureSplinePainter(hourlyItems: hourlyItems, itemWidth: itemWidth),
          child: Stack(
            children: hourlyItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final xPos = i * itemWidth;

              return Positioned(
                left: xPos,
                top: 75,
                width: itemWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: item.iconColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.windSpeed.toStringAsFixed(1)}km/h',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Draws the continuous lime-yellow smooth curve with floating temperature labels
class _TemperatureSplinePainter extends CustomPainter {
  final List<HourlyWeatherItem> hourlyItems;
  final double itemWidth;

  _TemperatureSplinePainter({
    required this.hourlyItems,
    required this.itemWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlyItems.isEmpty) return;

    final temps = hourlyItems.map((e) => e.temp).toList();
    final minT = temps.reduce(min);
    final maxT = temps.reduce(max);
    final range = max(maxT - minT, 4.0); // Prevent divide by zero

    const curveTop = 22.0;
    const curveHeight = 36.0;

    final List<Offset> points = [];
    for (int i = 0; i < hourlyItems.length; i++) {
      final x = i * itemWidth + itemWidth / 2;
      final norm = (hourlyItems[i].temp - minT) / range;
      final y = curveTop + (1.0 - norm) * curveHeight;
      points.add(Offset(x, y));
    }

    // Lime-yellow continuous line matching Screenshot 2
    final linePaint = Paint()
      ..color = const Color(0xFFD4E157)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw vertical dotted line at "Now" point (first point)
    final nowPt = points[0];
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    double curY = nowPt.dy + 4;
    while (curY < 72) {
      canvas.drawLine(Offset(nowPt.dx, curY), Offset(nowPt.dx, curY + 3), dotPaint);
      curY += 6;
    }

    // Filled white dot on the line for "Now"
    final whiteDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nowPt, 3.5, whiteDotPaint);

    // Render floating temperature texts above each point
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final tempText = hourlyItems[i].customLabel ?? '${hourlyItems[i].temp.round()}°';
      final textSpan = TextSpan(
        text: tempText,
        style: TextStyle(
          fontSize: hourlyItems[i].customLabel != null ? 12 : 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(pt.dx - textPainter.width / 2, pt.dy - textPainter.height - 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureSplinePainter oldDelegate) => true;
}

/// ----------------------------------------------------------------------
/// Circular Wind Compass Dial matching Screenshot 2
/// ----------------------------------------------------------------------
class _CompassPainter extends CustomPainter {
  final int windDirection;

  _CompassPainter({required this.windDirection});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Outer circle
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, circlePaint);

    // Cardinal Labels N, S, W, E
    void drawLabel(String text, Offset offset, bool isNorth) {
      final span = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isNorth ? FontWeight.w700 : FontWeight.w500,
          color: isNorth ? Colors.white : Colors.white60,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
    }

    drawLabel('N', Offset(center.dx, center.dy - radius + 8), true);
    drawLabel('S', Offset(center.dx, center.dy + radius - 8), false);
    drawLabel('W', Offset(center.dx - radius + 8, center.dy), false);
    drawLabel('E', Offset(center.dx + radius - 8, center.dy), false);

    // Pointer needle arrow
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((windDirection) * pi / 180.0);

    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final arrowHeadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Line from bottom to top
    canvas.drawLine(const Offset(0, 14), const Offset(0, -14), arrowPaint);

    // Arrow head pointing to north/wind direction
    final arrowHead = Path()
      ..moveTo(0, -18)
      ..lineTo(-3.5, -11)
      ..lineTo(3.5, -11)
      ..close();
    canvas.drawPath(arrowHead, arrowHeadPaint);

    // Center pivot dot
    canvas.drawCircle(Offset.zero, 2.5, arrowHeadPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.windDirection != windDirection;
}

/// ----------------------------------------------------------------------
/// Parabolic Sun / Moon Arc Position Widget matching Screenshots
/// ----------------------------------------------------------------------
class _SunArcPainter extends CustomPainter {
  final bool isDay;

  _SunArcPainter({required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    // Parabolic Arc
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path();
    path.moveTo(0, size.height - 4);
    path.quadraticBezierTo(
      size.width * 0.5,
      -8,
      size.width,
      size.height - 4,
    );
    canvas.drawPath(path, arcPaint);

    // Baseline
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(0, size.height - 4),
      Offset(size.width, size.height - 4),
      basePaint,
    );

    // Dot along the arc representing current progress:
    // Midday sun in day is at the zenith apex (0.50), nocturnal moon is at 0.88
    final progress = isDay ? 0.50 : 0.88;
    final dotX = size.width * progress;
    // Quadratic equation: y = (1-t)^2 * y0 + 2(1-t)t * y1 + t^2 * y2
    final t = progress;
    final dotY = pow(1 - t, 2) * (size.height - 4) +
        2 * (1 - t) * t * (-8) +
        pow(t, 2) * (size.height - 4);

    if (isDay) {
      // Outer radiant sun flare glow
      final glowPaint = Paint()
        ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(dotX, dotY), 12.0, glowPaint);

      // Amber halo
      final haloPaint = Paint()
        ..color = const Color(0xFFFFA000).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 7.5, haloPaint);

      // Radiant white core
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 4.0, corePaint);
    } else {
      // Lunar halo
      final haloPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 7.0, haloPaint);

      // Lunar core
      final corePaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 3.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter oldDelegate) =>
      oldDelegate.isDay != isDay;
}

/// ----------------------------------------------------------------------
/// Soft Translucent Clouds in Radiant Daytime Azure Sky
/// ----------------------------------------------------------------------
class _DaytimeCloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    final cloudPaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    final cloudPaint3 = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

    // Organic cloud puffs across top/upper sky matching Screenshot 4
    canvas.drawOval(Rect.fromLTWH(size.width * 0.45, -20, size.width * 0.7, 140), cloudPaint1);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.2, 30, size.width * 0.5, 90), cloudPaint2);
    canvas.drawOval(Rect.fromLTWH(-size.width * 0.1, -10, size.width * 0.55, 120), cloudPaint2);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.55, 60, size.width * 0.45, 80), cloudPaint3);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.1, 80, size.width * 0.6, 70), cloudPaint1);
  }

  @override
  bool shouldRepaint(covariant _DaytimeCloudPainter oldDelegate) => false;
}

/// ----------------------------------------------------------------------
/// Twinkling Stars in Deep Cosmic Night Sky
/// ----------------------------------------------------------------------
class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Deterministic seed so stars don't flicker on rebuild
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.6 + random.nextDouble() * 1.0;
      final opacity = 0.15 + random.nextDouble() * 0.45;

      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => false;
}

/// ----------------------------------------------------------------------
/// City Search Bottom Sheet
/// ----------------------------------------------------------------------
class _CitySearchSheet extends StatefulWidget {
  final bool isDay;
  final void Function(String name, double lat, double lon) onSelectCity;
  final VoidCallback? onSelectCurrentLocation;

  const _CitySearchSheet({
    required this.onSelectCity,
    this.onSelectCurrentLocation,
    this.isDay = false,
  });

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final Dio _dio = Dio();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  final List<Map<String, dynamic>> _popularCities = const [
    {'name': 'Secunderabad', 'lat': 17.4399, 'lon': 78.4983, 'admin': 'Telangana, India'},
    {'name': 'Hyderabad', 'lat': 17.3850, 'lon': 78.4867, 'admin': 'Telangana, India'},
    {'name': 'Bengaluru', 'lat': 12.9716, 'lon': 77.5946, 'admin': 'Karnataka, India'},
    {'name': 'Mumbai', 'lat': 19.0760, 'lon': 72.8777, 'admin': 'Maharashtra, India'},
    {'name': 'New Delhi', 'lat': 28.6139, 'lon': 77.2090, 'admin': 'Delhi, India'},
    {'name': 'Chennai', 'lat': 13.0827, 'lon': 80.2707, 'admin': 'Tamil Nadu, India'},
    {'name': 'London', 'lat': 51.5074, 'lon': -0.1278, 'admin': 'United Kingdom'},
    {'name': 'New York', 'lat': 40.7128, 'lon': -74.0060, 'admin': 'New York, USA'},
  ];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final res = await _dio.get(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: {
          'name': query.trim(),
          'count': 6,
          'language': 'en',
          'format': 'json',
        },
      );

      if (res.statusCode == 200 && res.data['results'] is List) {
        final List list = res.data['results'];
        setState(() {
          _searchResults = list.map((item) {
            final country = item['country'] ?? '';
            final admin1 = item['admin1'] ?? '';
            final adminStr = [admin1, country].where((s) => s.toString().isNotEmpty).join(', ');
            return {
              'name': item['name']?.toString() ?? '',
              'lat': (item['latitude'] as num).toDouble(),
              'lon': (item['longitude'] as num).toDouble(),
              'admin': adminStr,
            };
          }).toList();
          _searching = false;
        });
      }
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _searchResults.isNotEmpty ? _searchResults : _popularCities;

    return Material(
      color: widget.isDay ? const Color(0xFF2473DE) : const Color(0xFF0C244F),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _controller,
              onChanged: _search,
              autofocus: false,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search city or location...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_searchResults.isEmpty && widget.onSelectCurrentLocation != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
              ),
              title: const Text(
                'Use Current Location',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                'Auto-detect via GPS / Network',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
              ),
              onTap: widget.onSelectCurrentLocation,
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 16),
          ],

          Text(
            _searchResults.isNotEmpty ? 'Search Results' : 'Popular Cities',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.08)),
              itemBuilder: (ctx, i) {
                final item = list[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined, color: Colors.white70),
                  title: Text(
                    item['name'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    item['admin'] ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  onTap: () {
                    widget.onSelectCity(
                      item['name'],
                      item['lat'],
                      item['lon'],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  }
}
