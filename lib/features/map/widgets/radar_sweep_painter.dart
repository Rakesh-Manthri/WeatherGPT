import 'dart:math';
import 'package:flutter/material.dart';

class RadarSweepPainter extends CustomPainter {
  final double sweepProgress;
  final int frameIndex;
  final int rainChance;
  final double windSpeed;
  final double windDegrees;

  RadarSweepPainter({
    required this.sweepProgress,
    required this.frameIndex,
    required this.rainChance,
    required this.windSpeed,
    required this.windDegrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2;

    // 1. Concentric Range Rings (5km, 15km, 25km)
    _drawRangeRings(canvas, center, maxRadius);

    // 2. Animated Precipitation Echo Clusters (Shifting with frame index and wind)
    _drawRainReflectivityClusters(canvas, center, size);

    // 3. Rotating Radar Sweep Beam & Phosphor Trailing Glow
    _drawSweepBeam(canvas, center, maxRadius);
  }

  void _drawRangeRings(Canvas canvas, Offset center, double maxRadius) {
    final ringPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final factor in [0.25, 0.50, 0.75, 1.0]) {
      canvas.drawCircle(center, maxRadius * factor, ringPaint);
    }

    // Crosshairs
    final crosshairPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crosshairPaint,
    );
  }

  void _drawSweepBeam(Canvas canvas, Offset center, double maxRadius) {
    final sweepAngle = sweepProgress * 2 * pi;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          const Color(0xFF00E676).withValues(alpha: 0.02),
          const Color(0xFF00E676).withValues(alpha: 0.32),
        ],
        stops: const [0.0, 0.75, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Leading edge beam line
    final linePaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.85)
      ..strokeWidth = 1.8;

    final endX = center.dx + maxRadius * cos(sweepAngle);
    final endY = center.dy + maxRadius * sin(sweepAngle);
    canvas.drawLine(center, Offset(endX, endY), linePaint);
  }

  void _drawRainReflectivityClusters(Canvas canvas, Offset center, Size size) {
    // Only render rain clouds if precipitation probability is noticeable
    if (rainChance < 5) return;

    final windRad = windDegrees * (pi / 180.0);
    // Advection displacement based on frameIndex (0 = 50m ago, 5 = now)
    final advectionStep = (frameIndex - 3) * 12.0;
    final offsetX = cos(windRad) * advectionStep;
    final offsetY = sin(windRad) * advectionStep;

    // Define 4-5 semi-random reflective rain storm cells
    final clusters = [
      {'dx': -60.0, 'dy': -80.0, 'radius': 52.0, 'dbz': rainChance * 0.9},
      {'dx': 80.0, 'dy': -40.0, 'radius': 42.0, 'dbz': rainChance * 0.7},
      {'dx': -30.0, 'dy': 60.0, 'radius': 60.0, 'dbz': rainChance * 1.1},
      {'dx': 40.0, 'dy': 90.0, 'radius': 48.0, 'dbz': rainChance * 0.8},
      {'dx': 110.0, 'dy': 50.0, 'radius': 35.0, 'dbz': rainChance * 0.5},
    ];

    for (final c in clusters) {
      final cellCenter = Offset(
        center.dx + (c['dx'] as double) + offsetX,
        center.dy + (c['dy'] as double) + offsetY,
      );
      final r = (c['radius'] as double);
      final intensity = (c['dbz'] as double).clamp(10.0, 95.0);

      // Color mapping from green -> yellow -> orange -> red based on dBZ
      Color coreColor;
      if (intensity > 65) {
        coreColor = const Color(0xFFD500F9); // Severe convective core
      } else if (intensity > 45) {
        coreColor = const Color(0xFFFF9100); // Heavy
      } else if (intensity > 25) {
        coreColor = const Color(0xFFFFD600); // Moderate
      } else {
        coreColor = const Color(0xFF00E676); // Light
      }

      final cellPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            coreColor.withValues(alpha: 0.50),
            coreColor.withValues(alpha: 0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: cellCenter, radius: r));

      canvas.drawCircle(cellCenter, r, cellPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.frameIndex != frameIndex ||
        oldDelegate.rainChance != rainChance;
  }
}
