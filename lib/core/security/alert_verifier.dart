import 'dart:convert';
import 'package:crypto/crypto.dart';

enum AlertVerificationStatus {
  valid,
  tampered,
  expired,
  missingSignature,
}

class AlertVerificationResult {
  final AlertVerificationStatus status;
  final bool isValid;
  final String? alertId;
  final String? failureReason;

  const AlertVerificationResult({
    required this.status,
    required this.isValid,
    this.alertId,
    this.failureReason,
  });

  bool get isTampered => status == AlertVerificationStatus.tampered;
  bool get isExpired => status == AlertVerificationStatus.expired;
}

/// Cryptographic verifier for severe weather disaster alerts.
/// Ensures all emergency warnings displayed in WeatherGPT originate authentically from
/// the WeatherGPT Disaster Authority and have not been modified or spoofed.
class AlertVerifier {
  static const String defaultSecret =
      'WeatherGPT-Disaster-Alert-Authority-Key-2026-NIST-P256';

  static const Set<String> _ignoredKeys = {
    'signature',
    'signature_type',
    'signature_hmac',
    'signature_ecdsa',
    'algorithm',
    'verified',
    'user_distance_km',
    'is_within_geofence',
  };

  /// Deterministically serializes JSON payload for canonical HMAC verification.
  /// Keys are sorted alphabetically and variable routing/signature keys are ignored.
  static String canonicalSerialize(Map<String, dynamic> payload) {
    final clean = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (!_ignoredKeys.contains(entry.key)) {
        clean[entry.key] = entry.value;
      }
    }
    final sortedKeys = clean.keys.toList()..sort();
    final buffer = StringBuffer('{');
    for (var i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final val = clean[key];
      buffer.write(jsonEncode(key));
      buffer.write(':');
      buffer.write(jsonEncode(val));
      if (i < sortedKeys.length - 1) {
        buffer.write(',');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Verifies an alert using HMAC-SHA256 signature and validates expiration timestamp.
  static AlertVerificationResult verifyAlert(
    Map<String, dynamic> alertPayload, {
    String? secretKey,
    DateTime? currentTime,
  }) {
    final alertId = alertPayload['alert_id']?.toString();
    final hmacSig = alertPayload['signature_hmac']?.toString();

    if (hmacSig == null || hmacSig.isEmpty) {
      return AlertVerificationResult(
        status: AlertVerificationStatus.missingSignature,
        isValid: false,
        alertId: alertId,
        failureReason: 'Alert lacks cryptographic HMAC signature.',
      );
    }

    // Check expiration timestamp
    final expiresAtEpoch = alertPayload['expires_at'];
    if (expiresAtEpoch is num) {
      final nowEpoch = (currentTime ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      if (nowEpoch > expiresAtEpoch) {
        return AlertVerificationResult(
          status: AlertVerificationStatus.expired,
          isValid: false,
          alertId: alertId,
          failureReason: 'Alert expired at epoch $expiresAtEpoch (current: $nowEpoch).',
        );
      }
    }

    // Compute expected HMAC-SHA256
    final secret = utf8.encode(secretKey ?? defaultSecret);
    final canonicalString = canonicalSerialize(alertPayload);
    final hmacSha256 = Hmac(sha256, secret);
    final digest = hmacSha256.convert(utf8.encode(canonicalString));
    final expectedHex = digest.toString().toLowerCase();

    if (expectedHex == hmacSig.toLowerCase()) {
      return AlertVerificationResult(
        status: AlertVerificationStatus.valid,
        isValid: true,
        alertId: alertId,
      );
    } else {
      return AlertVerificationResult(
        status: AlertVerificationStatus.tampered,
        isValid: false,
        alertId: alertId,
        failureReason: 'Cryptographic signature mismatch: payload may have been tampered with.',
      );
    }
  }
}
