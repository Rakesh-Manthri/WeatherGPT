import 'dart:convert';
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

  /// Retrieve the cached weather telemetry, or null if empty.
  Future<Map<String, dynamic>?> getCachedTelemetry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return null;
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (e) {
      debugPrint('Error reading offline weather cache: $e');
      return null;
    }
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
}
