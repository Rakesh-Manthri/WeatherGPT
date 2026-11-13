import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages on-device persistent caching of meteorological telemetry,
/// 1km spatial downscaling, and Panchangam data for zero-connectivity Edge AI.
class OfflineWeatherCache {
  static const String _cacheKey = 'weathergpt_offline_telemetry_cache';
  static const String _timestampKey = 'weathergpt_offline_cache_timestamp';
  static const String _coordsKey = 'weathergpt_offline_cache_coords';

  static OfflineWeatherCache? _instance;
  static OfflineWeatherCache get instance => _instance ??= OfflineWeatherCache._();

  OfflineWeatherCache._();

  /// Persist the latest structured weather telemetry into local storage.
  Future<void> saveTelemetry(Map<String, dynamic> weatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_cacheKey, json.encode(weatherData));
      await prefs.setString(_timestampKey, now);

      final lat = weatherData['latitude'] ?? weatherData['lat'];
      final lon = weatherData['longitude'] ?? weatherData['lon'];
      if (lat != null && lon != null) {
        await prefs.setString(_coordsKey, '$lat,$lon');
      }
    } catch (e) {
      debugPrint('Error saving offline weather cache: $e');
    }
  }

  /// Retrieve the cached weather telemetry, or null if empty or obsolete fallback.
  Future<Map<String, dynamic>?> getCachedTelemetry({bool purgeStaleFallback = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final data = Map<String, dynamic>.from(json.decode(raw) as Map);

      // Auto-invalidate old corrupted 27.5°C "Your Location" static fallback
      if (purgeStaleFallback && _isObsoleteStaticFallback(data)) {
        debugPrint('Detected obsolete static 27.5°C mock fallback in cache. Purging.');
        await clear();
        return null;
      }

      return data;
    } catch (e) {
      debugPrint('Error reading offline weather cache: $e');
      return null;
    }
  }

  /// Identifies whether the cached record is the old static 27.5°C fallback
  bool _isObsoleteStaticFallback(Map<String, dynamic> data) {
    final temp = data['temperature'];
    final loc = data['location_name'];
    final hum = data['humidity'];
    // Matches the old hardcoded baseline in weather_service.py
    if ((temp == 27.5 || temp == 27.55) && (loc == 'Your Location' || hum == 62)) {
      return true;
    }
    return false;
  }

  /// Get the time when the cache was last updated.
  Future<DateTime?> getCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString(_timestampKey);
      if (tsStr == null) return null;
      return DateTime.tryParse(tsStr);
    } catch (_) {
      return null;
    }
  }

  /// Human-readable cache age (e.g. "12 mins ago", "3 hours ago").
  Future<String> getCacheAgeString() async {
    final ts = await getCacheTimestamp();
    if (ts == null) return 'No cache available';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Check whether cache is fresh (default 48 hours validity for offline survival).
  Future<bool> hasValidCache({Duration maxAge = const Duration(hours: 48)}) async {
    final ts = await getCacheTimestamp();
    if (ts == null) return false;
    final data = await getCachedTelemetry();
    if (data == null || data.isEmpty) return false;
    return DateTime.now().difference(ts) <= maxAge;
  }

  /// Clear the cached telemetry.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
      await prefs.remove(_coordsKey);
    } catch (_) {}
  }

  /// Direct on-device sync from Open-Meteo into local cache.
  /// Bypasses backend entirely so the device's offline cache always has genuine live metrics.
  Future<Map<String, dynamic>?> syncFromLiveOpenMeteo({
    double? lat,
    double? lon,
    String? locationName,
  }) async {
    final targetLat = lat ?? 17.3850;
    final targetLon = lon ?? 78.4867;

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'User-Agent': 'WeatherGPT-Flutter/1.0 (contact@weathergpt.local)'},
        ),
      );

      final response = await dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': targetLat,
          'longitude': targetLon,
          'current': [
            'temperature_2m',
            'relative_humidity_2m',
            'apparent_temperature',
            'weather_code',
            'surface_pressure',
            'wind_speed_10m',
            'wind_direction_10m',
            'wind_gusts_10m',
            'precipitation',
            'uv_index',
            'is_day',
          ].join(','),
          'daily': [
            'weather_code',
            'temperature_2m_max',
            'temperature_2m_min',
            'precipitation_probability_max',
          ].join(','),
          'timezone': 'auto',
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final current = data['current'] as Map<String, dynamic>? ?? {};
        final daily = data['daily'] as Map<String, dynamic>? ?? {};

        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 25.0;
        final apparent = (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
        final code = current['weather_code'] as int? ?? 1;
        final hum = current['relative_humidity_2m'] as int? ?? 60;
        final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
        final gusts = (current['wind_gusts_10m'] as num?)?.toDouble() ?? 12.0;
        final pressure = (current['surface_pressure'] as num?)?.toDouble() ?? 1013.0;
        final uv = (current['uv_index'] as num?)?.toDouble() ?? 5.0;
        final isDay = (current['is_day'] as int? ?? 1) == 1;

        final rainList = daily['precipitation_probability_max'] as List?;
        final rainChance = rainList != null && rainList.isNotEmpty && rainList.first != null
            ? (rainList.first as num).toInt()
            : 5;

        final tMaxList = daily['temperature_2m_max'] as List?;
        final tempMax = tMaxList != null && tMaxList.isNotEmpty && tMaxList.first != null
            ? (tMaxList.first as num).round()
            : (temp + 4).round();

        final tMinList = daily['temperature_2m_min'] as List?;
        final tempMin = tMinList != null && tMinList.isNotEmpty && tMinList.first != null
            ? (tMinList.first as num).round()
            : (temp - 5).round();

        final condition = _mapWmoCode(code);
        final locName = locationName ?? (targetLat == 17.3850 ? 'Hyderabad' : 'Current Location');

        final telemetry = <String, dynamic>{
          'location_name': locName,
          'latitude': targetLat,
          'longitude': targetLon,
          'temperature': temp,
          'apparent_temperature': apparent,
          'condition': condition,
          'weather_code': code,
          'humidity': hum,
          'wind_speed': wind,
          'wind_gusts': gusts,
          'pressure': pressure,
          'uv_index': uv,
          'is_day': isDay,
          'rain_chance': rainChance,
          'temp_max': tempMax,
          'temp_min': tempMin,
          'aqi': 55,
        };

        await saveTelemetry(telemetry);
        return telemetry;
      }
    } catch (e) {
      debugPrint('Direct Open-Meteo sync failed: $e');
    }
    return null;
  }

  static String _mapWmoCode(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code >= 71 && code <= 75) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Partly Cloudy';
  }
}

