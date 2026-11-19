import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RadarFrame {
  final int time;
  final String path;
  final String label;
  final bool isNowcast;

  const RadarFrame({
    required this.time,
    required this.path,
    required this.label,
    this.isNowcast = false,
  });
}

class RainviewerService {
  RainviewerService._internal();
  static final RainviewerService instance = RainviewerService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  static const String _mapsEndpoint = 'https://api.rainviewer.com/public/weather-maps.json';
  List<RadarFrame>? _cachedFrames;
  DateTime? _lastFetchTime;
  String _host = 'https://tilecache.rainviewer.com';

  String get host => _host;

  /// Fetch the latest past & nowcast radar frames from RainViewer
  Future<List<RadarFrame>> getRadarFrames({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedFrames != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 5) {
      return _cachedFrames!;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(_mapsEndpoint);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        _host = (data['host'] as String?) ?? _host;
        final radar = data['radar'] as Map<String, dynamic>?;

        final past = (radar?['past'] as List<dynamic>?) ?? [];
        final nowcast = (radar?['nowcast'] as List<dynamic>?) ?? [];

        final List<RadarFrame> frames = [];
        final combined = [...past, ...nowcast];

        // Take up to the last 6-8 frames for smooth animation
        final slice = combined.length > 7 ? combined.sublist(combined.length - 7) : combined;

        for (int i = 0; i < slice.length; i++) {
          final item = slice[i];
          if (item is Map) {
            final t = (item['time'] as num?)?.toInt() ?? 0;
            final p = (item['path'] as String?) ?? '';
            final isLast = i == slice.length - 1;
            final minutesAgo = ((now.millisecondsSinceEpoch ~/ 1000 - t) / 60).round();

            String lbl;
            if (isLast) {
              lbl = 'NOW';
            } else if (minutesAgo > 0) {
              lbl = '-${minutesAgo}m';
            } else if (minutesAgo < 0) {
              lbl = '+${-minutesAgo}m';
            } else {
              lbl = 'NOW';
            }

            frames.add(RadarFrame(
              time: t,
              path: p,
              label: lbl,
              isNowcast: i >= past.length,
            ));
          }
        }

        if (frames.isNotEmpty) {
          _cachedFrames = frames;
          _lastFetchTime = now;
          return frames;
        }
      }
    } catch (e) {
      debugPrint('RainViewer live radar fetch error (using dynamic fallback timeline): $e');
    }

    // Dynamic fallback frames for offline / rapid radar scrubbing
    final fallback = _generateFallbackFrames();
    _cachedFrames = fallback;
    _lastFetchTime = now;
    return fallback;
  }

  List<RadarFrame> _generateFallbackFrames() {
    final now = DateTime.now();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    const intervals = [-50, -40, -30, -20, -10, 0];

    return intervals.map((m) {
      final t = nowSec + (m * 60);
      final lbl = m == 0 ? 'NOW' : '${m}m';
      return RadarFrame(
        time: t,
        path: '/v2/radar/$t',
        label: lbl,
        isNowcast: m > 0,
      );
    }).toList();
  }
}
