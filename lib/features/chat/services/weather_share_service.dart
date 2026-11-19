import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/weather_share_card.dart';

class WeatherShareService {
  WeatherShareService._internal();
  static final WeatherShareService instance = WeatherShareService._internal();

  /// Shows an interactive preview sheet of the Weather Report Card with one-click sharing
  Future<void> showShareModal(
    BuildContext context, {
    required Map<String, dynamic> weatherData,
    required String locationName,
    required double lat,
    required double lon,
  }) async {
    final GlobalKey boundaryKey = GlobalKey();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSharing = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.share_rounded, color: Color(0xFF00E676), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Share Weather Report',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Styled Weather Report Card wrapped in RepaintBoundary for capture
                    Center(
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: WeatherShareCard(
                          weatherData: weatherData,
                          locationName: locationName,
                          lat: lat,
                          lon: lon,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Action Buttons Row
                    Row(
                      children: [
                        // Share Image Button (PNG Capture)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSharing
                                ? null
                                : () async {
                                    setModalState(() => isSharing = true);
                                    try {
                                      await _captureAndShareImage(
                                        boundaryKey,
                                        locationName: locationName,
                                        temp: weatherData['temperature']?.toString() ?? '25',
                                        cond: weatherData['condition']?.toString() ?? 'Clear',
                                      );
                                    } catch (e) {
                                      debugPrint('Error sharing weather card image: $e');
                                      // Fallback to text share if image capture throws
                                      await _shareTextBulletin(
                                        locationName: locationName,
                                        weatherData: weatherData,
                                        lat: lat,
                                        lon: lon,
                                      );
                                    } finally {
                                      if (ctx.mounted) {
                                        setModalState(() => isSharing = false);
                                        Navigator.pop(ctx);
                                      }
                                    }
                                  },
                            icon: isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                  )
                                : const Icon(Icons.image_rounded, size: 18),
                            label: Text(
                              isSharing ? 'Capturing...' : 'Share Report Card',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Share Text Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.text_snippet_outlined, color: Colors.white, size: 20),
                            tooltip: 'Share Text Bulletin',
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _shareTextBulletin(
                                locationName: locationName,
                                weatherData: weatherData,
                                lat: lat,
                                lon: lon,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _captureAndShareImage(
    GlobalKey boundaryKey, {
    required String locationName,
    required String temp,
    required String cond,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('RepaintBoundary render object not ready');
    }

    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode image to PNG byte buffer');
    }

    final pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/weather_gpt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);

    final xFile = XFile(file.path, mimeType: 'image/png', name: 'Weather_Report_$locationName.png');
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: '🌤️ Hyperlocal Weather Report for $locationName: $temp°C, $cond • Shared via Weather GPT',
        subject: 'Weather GPT Report - $locationName',
      ),
    );
  }

  Future<void> _shareTextBulletin({
    required String locationName,
    required Map<String, dynamic> weatherData,
    required double lat,
    required double lon,
  }) async {
    final temp = weatherData['temperature'] ?? 25;
    final cond = weatherData['condition'] ?? 'Partly Cloudy';
    final hum = weatherData['humidity'] ?? 60;
    final rain = weatherData['rain_chance'] ?? 10;
    final wind = weatherData['wind_speed'] ?? 12;
    final aqi = weatherData['aqi'] ?? 65;

    final text = '📍 *Weather GPT Report • $locationName*\n'
        '• Temperature: $temp°C ($cond)\n'
        '• Rain Probability: $rain%\n'
        '• Humidity: $hum% • Wind: $wind km/h\n'
        '• Air Quality (AQI): $aqi\n'
        '• Coordinates: ${lat.toStringAsFixed(4)}°N, ${lon.toStringAsFixed(4)}°E\n\n'
        'Generated with On-Device AI by Weather GPT';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Weather GPT Bulletin for $locationName',
      ),
    );
  }
}
