import 'dart:math';
import 'package:flutter/material.dart';

class AqiStation {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int aqi;
  final String category;
  final Color color;
  final double pm25;
  final bool isCenter;

  const AqiStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.aqi,
    required this.category,
    required this.color,
    required this.pm25,
    this.isCenter = false,
  });

  factory AqiStation.fromMap(Map<String, dynamic> map) {
    Color parseColor(String hex) {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    }

    return AqiStation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Station',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
      aqi: (map['aqi'] as num?)?.toInt() ?? 50,
      category: map['category']?.toString() ?? 'Moderate',
      color: map['color'] != null ? parseColor(map['color'].toString()) : const Color(0xFFFFD600),
      pm25: (map['pm25'] as num?)?.toDouble() ?? 25.0,
      isCenter: map['is_center'] == true,
    );
  }
}

class AqiHeatmapLayer extends StatefulWidget {
  final List<AqiStation> stations;
  final int centerAqi;
  final ValueChanged<AqiStation>? onStationSelected;

  const AqiHeatmapLayer({
    super.key,
    required this.stations,
    required this.centerAqi,
    this.onStationSelected,
  });

  @override
  State<AqiHeatmapLayer> createState() => _AqiHeatmapLayerState();
}

class _AqiHeatmapLayerState extends State<AqiHeatmapLayer> {
  AqiStation? _inspectedStation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Dispersion Gradient Canvas Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _AqiDispersionCanvasPainter(stations: widget.stations),
            ),
          ),
        ),

        // 2. Interactive Station Pins
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

              return Stack(
                children: widget.stations.map((st) {
                  // Map dispersion offset relative to center
                  final offset = _computeScreenOffset(st, center, constraints.maxWidth, constraints.maxHeight);

                  return Positioned(
                    left: offset.dx - 22,
                    top: offset.dy - 22,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _inspectedStation = st);
                        widget.onStationSelected?.call(st);
                      },
                      child: _buildStationPin(st),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        // 3. Inspected Station Detail Card Popup
        if (_inspectedStation != null)
          Positioned(
            left: 20,
            right: 20,
            top: 100,
            child: _buildInspectionCard(_inspectedStation!),
          ),

        // 4. Floating AQI Heatmap Gradient Legend
        Positioned(
          left: 18,
          bottom: 24,
          child: _buildAqiLegend(),
        ),
      ],
    );
  }

  Offset _computeScreenOffset(AqiStation st, Offset center, double width, double height) {
    if (st.isCenter) return center;

    // Use station ID or angle to lay out the dispersion pins gracefully around center
    final idNum = int.tryParse(st.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 1;
    final angle = (idNum * 45.0) * (pi / 180.0);
    final distance = (idNum % 2 == 0 ? 110.0 : 70.0);

    return Offset(
      center.dx + cos(angle) * distance,
      center.dy + sin(angle) * distance,
    );
  }

  Widget _buildStationPin(AqiStation st) {
    final isSelected = _inspectedStation?.id == st.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: st.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: st.color.withValues(alpha: 0.5),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Text(
            '${st.aqi}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: st.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildInspectionCard(AqiStation st) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: st.color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: st.color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: st.color, width: 2),
            ),
            child: Center(
              child: Text(
                '${st.aqi}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: st.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  st.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${st.category} • PM2.5: ${st.pm25} µg/m³',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => setState(() => _inspectedStation = null),
          ),
        ],
      ),
    );
  }

  Widget _buildAqiLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Air Quality Heatmap (US AQI)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('0 ', style: TextStyle(fontSize: 8.5, color: Colors.white70)),
              Container(
                width: 110,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00E676), // Good
                      Color(0xFFFFD600), // Moderate
                      Color(0xFFFF9100), // Sensitive
                      Color(0xFFFF1744), // Unhealthy
                      Color(0xFFD500F9), // Very Unhealthy
                      Color(0xFF880E4F), // Hazardous
                    ],
                  ),
                ),
              ),
              const Text(' 300+', style: TextStyle(fontSize: 8.5, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AqiDispersionCanvasPainter extends CustomPainter {
  final List<AqiStation> stations;

  _AqiDispersionCanvasPainter({required this.stations});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final st in stations) {
      final idNum = int.tryParse(st.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 1;
      final angle = (idNum * 45.0) * (pi / 180.0);
      final distance = st.isCenter ? 0.0 : (idNum % 2 == 0 ? 110.0 : 70.0);

      final cellCenter = Offset(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );

      final radius = st.isCenter ? 95.0 : 68.0;

      final gradientPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            st.color.withValues(alpha: 0.38),
            st.color.withValues(alpha: 0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.60, 1.0],
        ).createShader(Rect.fromCircle(center: cellCenter, radius: radius));

      canvas.drawCircle(cellCenter, radius, gradientPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AqiDispersionCanvasPainter oldDelegate) {
    return oldDelegate.stations != stations;
  }
}
