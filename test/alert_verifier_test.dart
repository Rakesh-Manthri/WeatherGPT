import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_gpt/core/notifications/geofence_service.dart';
import 'package:weather_gpt/core/security/alert_verifier.dart';

void main() {
  group('AlertVerifier Cryptographic Tests', () {
    final validAlert = {
      'alert_id': 'TEST-ALERT-001',
      'authority': 'WeatherGPT Disaster Warning System',
      'severity': 'CRITICAL',
      'hazard_type': 'CYCLONE',
      'title': 'Severe Cyclone Storm',
      'description': 'High wind alert.',
      'geofence': {
        'latitude': 17.6868,
        'longitude': 83.2185,
        'radius_km': 100.0,
      },
      'issued_at': 1700000000,
      'expires_at': 2000000000, // distant future
      'safety_instructions': ['Evacuate low lying areas.'],
    };

    test('validates authentically signed alert', () {
      // Create valid HMAC using canonical serialization
      final canonical = AlertVerifier.canonicalSerialize(validAlert);
      expect(canonical.contains('"alert_id":"TEST-ALERT-001"'), isTrue);

      // Generate HMAC
      final payload = Map<String, dynamic>.from(validAlert);
      final rawHmac = AlertVerifier.verifyAlert({
        ...payload,
        'signature_hmac': 'invalid',
      });
      expect(rawHmac.isTampered, isTrue);

      // Use AlertVerifier with deterministic calculation
      final computedResult = AlertVerifier.verifyAlert({
        ...payload,
        'signature_hmac': _computeTestHmac(payload),
      });

      expect(computedResult.isValid, isTrue);
      expect(computedResult.status, AlertVerificationStatus.valid);
    });

    test('rejects tampered alert when fields are modified', () {
      final payload = Map<String, dynamic>.from(validAlert);
      final validSig = _computeTestHmac(payload);

      // Malicious modification of severity from WARNING to CRITICAL
      final tampered = {
        ...payload,
        'severity': 'ADVISORY',
        'signature_hmac': validSig,
      };

      final result = AlertVerifier.verifyAlert(tampered);
      expect(result.isValid, isFalse);
      expect(result.isTampered, isTrue);
    });

    test('flags expired alerts', () {
      final expiredAlert = Map<String, dynamic>.from(validAlert);
      expiredAlert['expires_at'] = 1600000000; // Past epoch
      final sig = _computeTestHmac(expiredAlert);
      expiredAlert['signature_hmac'] = sig;

      final result = AlertVerifier.verifyAlert(
        expiredAlert,
        currentTime: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );

      expect(result.isValid, isFalse);
      expect(result.isExpired, isTrue);
    });
  });

  group('GeofenceService Microclimate Tests', () {
    final geofenceService = GeofenceService.instance;

    setUp(() {
      geofenceService.clear();
    });

    test('haversine distance computes accurately', () {
      // Distance between Hyderabad (17.3850, 78.4867) and Secunderabad (17.4399, 78.4983)
      final dist = GeofenceService.haversineDistanceKm(
        17.3850,
        78.4867,
        17.4399,
        78.4983,
      );
      expect(dist, greaterThan(5.0));
      expect(dist, lessThan(10.0));
    });

    test('triggers breach event when user is inside hazard perimeter', () {
      final validCellData = {
        'alert_id': 'TEST-CELL-01',
        'authority': 'WeatherGPT Disaster Warning System',
        'severity': 'CRITICAL',
        'hazard_type': 'CYCLONE',
        'title': 'Visakhapatnam Cyclone Cell',
        'description': 'Storm surge warning',
        'geofence': {
          'latitude': 17.6868,
          'longitude': 83.2185,
          'radius_km': 50.0,
        },
        'issued_at': 1700000000,
        'expires_at': 2000000000,
        'safety_instructions': ['Stay indoors'],
      };

      validCellData['signature_hmac'] = _computeTestHmac(validCellData);

      geofenceService.updateRiskCells([validCellData]);
      expect(geofenceService.monitoredCells.length, 1);

      // User location 10 km away from center (within 50 km radius)
      final breaches = geofenceService.evaluateUserLocation(17.7000, 83.2200);
      expect(breaches.length, 1);
      expect(breaches.first.cell.alertId, 'TEST-CELL-01');
      expect(breaches.first.userDistanceKm, lessThan(10.0));

      // User location in Hyderabad (~500 km away)
      final farBreaches = geofenceService.evaluateUserLocation(17.3850, 78.4867);
      expect(farBreaches.isEmpty, isTrue);
    });
  });
}

String _computeTestHmac(Map<String, dynamic> payload) {
  final canonical = AlertVerifier.canonicalSerialize(payload);
  final secret = utf8.encode(AlertVerifier.defaultSecret);
  final hmacSha256 = Hmac(sha256, secret);
  return hmacSha256.convert(utf8.encode(canonical)).toString();
}
