import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart';

enum MapLayerType {
  radarPrecipitation,
  windStreamlines,
  thermalElevation,
}

/// Interactive GIS Map Bubble embedded directly inside Chat reply bubbles.
/// Features live Mappls vector tiles, animated weather radar sweep overlay,
/// wind vector compass, color-coded precipitation probability cells,
/// and hyper-local 1km microclimate elevation profile.
class WeatherMapBubble extends StatefulWidget {
  final Map<String, dynamic> weatherData;
  final void Function(double lat, double lon)? onExpandFullscreen;

  const WeatherMapBubble({
    super.key,
    required this.weatherData,
    this.onExpandFullscreen,
  });

  @override
  State<WeatherMapBubble> createState() => _WeatherMapBubbleState();
}

class _WeatherMapBubbleState extends State<WeatherMapBubble>
    with SingleTickerProviderStateMixin {
  MapplsMapController? _mapController;
  MapLayerType _activeLayer = MapLayerType.radarPrecipitation;
  late final AnimationController _radarAnimController;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapplsMapController controller) {
    _mapController = controller;
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _recenter(double lat, double lon) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lon), 11.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.weatherData;
    final lat = (data['latitude'] as num?)?.toDouble() ?? 28.6139;
    final lon = (data['longitude'] as num?)?.toDouble() ?? 77.2090;
    final locName = (data['location_name'] ?? 'Local Coordinates').toString();
    final tempNum = (data['temperature'] as num?)?.round() ?? 28;
    final temp = '$tempNum';
    final cond = (data['condition'] ?? 'Partly Cloudy').toString();
    final rainChance = (data['rain_chance'] as num?)?.toInt() ?? 20;
    final windSpeed = (data['wind_speed'] as num?)?.toDouble() ?? 12.0;
    final windDir = (data['wind_direction'] as num?)?.toDouble() ?? 180.0;
    final downscaling = data['spatial_downscaling'] as Map<String, dynamic>?;
    final microZone = downscaling?['microclimate_zone'] ?? '1km Grid Cell';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Control Strip: Title, Layer Tabs & Fullscreen CTA
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            color: const Color(0xFF1C1C1E),
            child: Row(
              children: [
                const Icon(
                  Icons.radar_rounded,
                  size: 16,
                  color: Color(0xFF64B5F6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GIS Weather Radar • $locName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      Text(
                        '${lat.toStringAsFixed(4)}°N, ${lon.toStringAsFixed(4)}°E • 1km downscaled',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onExpandFullscreen != null)
                  IconButton(
                    icon: const Icon(
                      Icons.fullscreen_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Fullscreen Map',
                    onPressed: () => widget.onExpandFullscreen!(lat, lon),
                  ),
              ],
            ),
          ),

          // Interactive Map Area with Live Radar & Vector Overlays
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                // Underlying Mappls Vector Map
                Positioned.fill(
                  child: MapplsMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lon),
                      zoom: 11.0,
                    ),
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: false,
                    compassEnabled: false,
                  ),
                ),

                // Animated Radar Sweep & GIS Data Overlay (CustomPaint)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _radarAnimController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: GisRadarOverlayPainter(
                            sweepProgress: _radarAnimController.value,
                            layer: _activeLayer,
                            rainChance: rainChance,
                            windSpeed: windSpeed,
                            windDegrees: windDir,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Center Pin with Microclimate Pulse Ring
                Center(
                  child: IgnorePointer(
                    child: _buildLocationPin(temp, cond),
                  ),
                ),

                // Floating Map Zoom / Recenter Controls
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _buildFloatingActionBtn(
                        icon: Icons.add_rounded,
                        onPressed: _zoomIn,
                        tooltip: 'Zoom In',
                      ),
                      const SizedBox(height: 6),
                      _buildFloatingActionBtn(
                        icon: Icons.remove_rounded,
                        onPressed: _zoomOut,
                        tooltip: 'Zoom Out',
                      ),
                      const SizedBox(height: 6),
                      _buildFloatingActionBtn(
                        icon: Icons.my_location_rounded,
                        onPressed: () => _recenter(lat, lon),
                        tooltip: 'Recenter Pin',
                      ),
                    ],
                  ),
                ),

                // Layer Toggle Selector (Bottom-Left)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLayerPill(
                          label: 'Radar',
                          icon: Icons.water_drop_rounded,
                          layer: MapLayerType.radarPrecipitation,
                        ),
                        const SizedBox(width: 3),
                        _buildLayerPill(
                          label: 'Wind',
                          icon: Icons.air_rounded,
                          layer: MapLayerType.windStreamlines,
                        ),
                        const SizedBox(width: 3),
                        _buildLayerPill(
                          label: '1km UHI',
                          icon: Icons.terrain_rounded,
                          layer: MapLayerType.thermalElevation,
                        ),
                      ],
                    ),
                  ),
                ),

                // Layer Legend Bar (Bottom-Right)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _buildLegend(),
                ),
              ],
            ),
          ),

          // Bottom Telemetry Summary Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildFooterMetric(
                    icon: Icons.thermostat_rounded,
                    color: const Color(0xFFD93025),
                    label: '$temp°C $cond',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildFooterMetric(
                    icon: Icons.grain_rounded,
                    color: const Color(0xFF1976D2),
                    label: '$rainChance% Rain',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildFooterMetric(
                    icon: Icons.navigation_rounded,
                    color: const Color(0xFF00796B),
                    label: '${windSpeed.round()} km/h',
                    rotationDegrees: windDir,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _buildFooterMetric(
                    icon: Icons.terrain_rounded,
                    color: const Color(0xFF5E35B1),
                    label: microZone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPin(String temp, String cond) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$temp°C',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          size: 26,
          color: Color(0xFFD93025),
        ),
      ],
    );
  }

  Widget _buildFloatingActionBtn({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: const Color(0xFF202124)),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerPill({
    required String label,
    required IconData icon,
    required MapLayerType layer,
  }) {
    final isSelected = _activeLayer == layer;
    return GestureDetector(
      onTap: () => setState(() => _activeLayer = layer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A73E8)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    switch (_activeLayer) {
      case MapLayerType.radarPrecipitation:
        return _buildLegendPill(
          title: 'Precip',
          gradientColors: [
            Colors.lightBlue.withValues(alpha: 0.7),
            Colors.green.withValues(alpha: 0.8),
            Colors.amber.withValues(alpha: 0.9),
            Colors.red.withValues(alpha: 0.9),
          ],
          labelLeft: '0%',
          labelRight: '100%',
        );
      case MapLayerType.windStreamlines:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.near_me_rounded, size: 11, color: Color(0xFF4FC3F7)),
              SizedBox(width: 4),
              Text(
                'Wind Vector',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      case MapLayerType.thermalElevation:
        return _buildLegendPill(
          title: '1km UHI',
          gradientColors: [
            const Color(0xFF1565C0), // Cool ridge
            const Color(0xFF43A047), // Vegetation
            const Color(0xFFE65100), // High density UHI
          ],
          labelLeft: '-3°C',
          labelRight: '+2°C',
        );
    }
  }

  Widget _buildLegendPill({
    required String title,
    required List<Color> gradientColors,
    required String labelLeft,
    required String labelRight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: $labelLeft ',
            style: const TextStyle(fontSize: 9, color: Colors.white70),
          ),
          Container(
            width: 36,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(colors: gradientColors),
            ),
          ),
          Text(
            ' $labelRight',
            style: const TextStyle(fontSize: 9, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterMetric({
    required IconData icon,
    required Color color,
    required String label,
    double? rotationDegrees,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rotationDegrees != null)
          Transform.rotate(
            angle: rotationDegrees * (pi / 180.0),
            child: Icon(icon, size: 12, color: color),
          )
        else
          Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dynamic canvas painter for animated radar sweeps, vector wind arrows,
/// and precipitation heat cells overlaid on the Mappls vector tiles.
class GisRadarOverlayPainter extends CustomPainter {
  final double sweepProgress;
  final MapLayerType layer;
  final int rainChance;
  final double windSpeed;
  final double windDegrees;

  GisRadarOverlayPainter({
    required this.sweepProgress,
    required this.layer,
    required this.rainChance,
    required this.windSpeed,
    required this.windDegrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2;

    switch (layer) {
      case MapLayerType.radarPrecipitation:
        _drawRadarCells(canvas, center, size);
        _drawRadarSweep(canvas, center, maxRadius);
        break;
      case MapLayerType.windStreamlines:
        _drawWindVectors(canvas, size);
        break;
      case MapLayerType.thermalElevation:
        _drawThermalContours(canvas, center, size);
        break;
    }
  }

  void _drawRadarSweep(Canvas canvas, Offset center, double maxRadius) {
    final sweepAngle = sweepProgress * 2 * pi;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          const Color(0xFF00E676).withValues(alpha: 0.02),
          const Color(0xFF00E676).withValues(alpha: 0.28),
        ],
        stops: const [0.0, 0.75, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Range rings
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 40, ringPaint);
    canvas.drawCircle(center, 80, ringPaint);
    canvas.drawCircle(center, 120, ringPaint);
  }

  void _drawRadarCells(Canvas canvas, Offset center, Size size) {
    if (rainChance < 15) return;

    final cellPaint = Paint()..style = PaintingStyle.fill;
    final rng = Random(42);

    final cellCount = (rainChance / 12).clamp(3, 8).toInt();
    for (int i = 0; i < cellCount; i++) {
      final angle = (i * (2 * pi / cellCount)) + (rng.nextDouble() * 0.4);
      final dist = 30.0 + rng.nextDouble() * 70.0;
      final cellCenter = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist,
      );

      final radius = 22.0 + rng.nextDouble() * 28.0;

      Color cellColor;
      if (rainChance > 70) {
        cellColor = const Color(0xFFE53935).withValues(alpha: 0.35); // Storm red
      } else if (rainChance > 40) {
        cellColor = const Color(0xFFFDD835).withValues(alpha: 0.38); // Moderate yellow
      } else {
        cellColor = const Color(0xFF43A047).withValues(alpha: 0.32); // Light green
      }

      cellPaint.color = cellColor;
      canvas.drawCircle(cellCenter, radius, cellPaint);
    }
  }

  void _drawWindVectors(Canvas canvas, Size size) {
    final arrowPaint = Paint()
      ..color = const Color(0xFF0288D1).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final rad = windDegrees * (pi / 180.0);
    const step = 45.0;

    for (double x = 25.0; x < size.width; x += step) {
      for (double y = 25.0; y < size.height; y += step) {
        final len = (windSpeed * 0.9).clamp(10.0, 22.0);
        final start = Offset(x, y);
        final end = Offset(x + sin(rad) * len, y - cos(rad) * len);

        canvas.drawLine(start, end, arrowPaint);

        // Arrow tip
        final tipAngle1 = rad + (pi * 0.82);
        final tipAngle2 = rad - (pi * 0.82);
        canvas.drawLine(end, Offset(end.dx + sin(tipAngle1) * 4, end.dy - cos(tipAngle1) * 4), arrowPaint);
        canvas.drawLine(end, Offset(end.dx + sin(tipAngle2) * 4, end.dy - cos(tipAngle2) * 4), arrowPaint);
      }
    }
  }

  void _drawThermalContours(Canvas canvas, Offset center, Size size) {
    final uhiPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Urban heat core (hot orange/red ring)
    uhiPaint.color = const Color(0xFFF4511E).withValues(alpha: 0.45);
    canvas.drawCircle(center, 55, uhiPaint);

    // Suburban transition ring (yellow)
    uhiPaint.color = const Color(0xFFFB8C00).withValues(alpha: 0.35);
    canvas.drawCircle(center, 95, uhiPaint);

    // Rural canopy/ridge boundary (green/blue)
    uhiPaint.color = const Color(0xFF1E88E5).withValues(alpha: 0.30);
    canvas.drawCircle(center, 135, uhiPaint);
  }

  @override
  bool shouldRepaint(covariant GisRadarOverlayPainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.layer != layer ||
        oldDelegate.rainChance != rainChance ||
        oldDelegate.windSpeed != windSpeed;
  }
}
