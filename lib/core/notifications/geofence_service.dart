import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../security/alert_verifier.dart';

class GeofenceRiskCell {
  final String alertId;
  final String severity; // CRITICAL, WARNING, ADVISORY
  final String hazardType; // CYCLONE, FLASH_FLOOD, SQUALL, HEATWAVE
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final int issuedAt;
  final int expiresAt;
  final List<String> safetyInstructions;
  final String signatureHmac;
  final bool isVerified;

  const GeofenceRiskCell({
    required this.alertId,
    required this.severity,
    required this.hazardType,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.issuedAt,
    required this.expiresAt,
    required this.safetyInstructions,
    required this.signatureHmac,
    required this.isVerified,
  });

  factory GeofenceRiskCell.fromJson(Map<String, dynamic> json) {
    final geofence = json['geofence'] as Map<String, dynamic>? ?? {};
    final rawInstructions = json['safety_instructions'] as List? ?? [];
    final verification = AlertVerifier.verifyAlert(json);

    return GeofenceRiskCell(
      alertId: json['alert_id']?.toString() ?? 'UNKNOWN',
      severity: json['severity']?.toString().toUpperCase() ?? 'ADVISORY',
      hazardType: json['hazard_type']?.toString().toUpperCase() ?? 'UNKNOWN',
      title: json['title']?.toString() ?? 'Hazard Alert',
      description: json['description']?.toString() ?? '',
      latitude: (geofence['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (geofence['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (geofence['radius_km'] as num?)?.toDouble() ?? 10.0,
      issuedAt: (json['issued_at'] as num?)?.toInt() ?? 0,
      expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
      safetyInstructions: rawInstructions.map((e) => e.toString()).toList(),
      signatureHmac: json['signature_hmac']?.toString() ?? '',
      isVerified: verification.isValid,
    );
  }

  double distanceToKm(double userLat, double userLon) {
    return GeofenceService.haversineDistanceKm(userLat, userLon, latitude, longitude);
  }

  bool isUserInside(double userLat, double userLon) {
    return distanceToKm(userLat, userLon) <= radiusKm;
  }
}

class GeofenceBreachEvent {
  final GeofenceRiskCell cell;
  final double userDistanceKm;
  final DateTime timestamp;

  const GeofenceBreachEvent({
    required this.cell,
    required this.userDistanceKm,
    required this.timestamp,
  });
}

/// Background Geofence & Microclimate Alert Service.
/// Continuously evaluates user location against authenticated disaster risk zones.
class GeofenceService {
  static GeofenceService? _instance;
  static GeofenceService get instance => _instance ??= GeofenceService._();

  GeofenceService._();

  final List<GeofenceRiskCell> _monitoredCells = [];
  final ValueNotifier<List<GeofenceBreachEvent>> activeBreachesNotifier =
      ValueNotifier<List<GeofenceBreachEvent>>([]);

  List<GeofenceRiskCell> get monitoredCells => List.unmodifiable(_monitoredCells);

  static double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Register new risk cells (only cryptographically verified cells are retained)
  void updateRiskCells(List<Map<String, dynamic>> rawCells) {
    _monitoredCells.clear();
    for (final raw in rawCells) {
      final cell = GeofenceRiskCell.fromJson(raw);
      if (cell.isVerified) {
        _monitoredCells.add(cell);
      } else {
        debugPrint('Rejected unverified risk cell: ${cell.alertId}');
      }
    }
  }

  /// Evaluate user coordinates against registered risk cells.
  /// Returns list of active breaches (user is inside hazard radius).
  List<GeofenceBreachEvent> evaluateUserLocation(double lat, double lon) {
    final breaches = <GeofenceBreachEvent>[];
    final now = DateTime.now();

    for (final cell in _monitoredCells) {
      final dist = cell.distanceToKm(lat, lon);
      if (dist <= cell.radiusKm) {
        breaches.add(
          GeofenceBreachEvent(
            cell: cell,
            userDistanceKm: dist,
            timestamp: now,
          ),
        );
      }
    }

    activeBreachesNotifier.value = breaches;
    return breaches;
  }

  void clear() {
    _monitoredCells.clear();
    activeBreachesNotifier.value = [];
  }
}
