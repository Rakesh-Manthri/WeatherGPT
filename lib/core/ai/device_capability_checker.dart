import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/foundation.dart';

/// Hardware capability result for running on-device SLMs (Qwen2.5-0.5B INT4).
class DeviceCapabilityResult {
  final bool isCapable;
  final String reason;
  final int freeStorageMb;
  final int totalRamMb;
  final String cpuAbi;

  const DeviceCapabilityResult({
    required this.isCapable,
    required this.reason,
    required this.freeStorageMb,
    required this.totalRamMb,
    required this.cpuAbi,
  });

  @override
  String toString() =>
      'DeviceCapabilityResult(capable: $isCapable, reason: "$reason", '
      'storage: ${freeStorageMb}MB, RAM: ${totalRamMb}MB, ABI: $cpuAbi)';
}

/// Validates device storage, RAM, and CPU architecture before downloading
/// or attempting local execution of Qwen2.5-0.5B-Instruct weights.
class DeviceCapabilityChecker {
  static const int minStorageMb = 500;
  static const int minRamMb = 1800; // ~2GB physical RAM (accounting for OS reservations)

  static DeviceCapabilityResult? _cachedResult;

  /// Runs or returns cached capability check. Set [forceRefresh] to re-check.
  static Future<DeviceCapabilityResult> check({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedResult != null) {
      return _cachedResult!;
    }

    int freeStorageMb = 1024;
    int totalRamMb = 4096;
    String cpuAbi = 'arm64-v8a';
    bool is64Bit = true;

    // 1. Storage Check
    try {
      final diskSpace = DiskSpacePlus();
      final freeSpace = await diskSpace.getFreeDiskSpace;
      if (freeSpace != null && freeSpace > 0) {
        freeStorageMb = freeSpace.round();
      }
    } catch (e) {
      debugPrint('Disk space check fallback: $e');
    }

    // 2. Hardware Architecture & RAM Check
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final abis = androidInfo.supportedAbis;
        if (abis.isNotEmpty) {
          cpuAbi = abis.first;
          is64Bit = abis.any(
            (abi) =>
                abi.contains('64') ||
                abi.contains('arm64') ||
                abi.contains('x86_64'),
          );
        }

        // Read physical RAM from /proc/meminfo (standard Linux kernel file on Android)
        try {
          final meminfo = File('/proc/meminfo');
          if (await meminfo.exists()) {
            final lines = await meminfo.readAsLines();
            for (final line in lines) {
              if (line.startsWith('MemTotal:')) {
                final match = RegExp(r'\d+').firstMatch(line);
                if (match != null) {
                  final kb = int.tryParse(match.group(0) ?? '') ?? 0;
                  if (kb > 0) {
                    totalRamMb = kb ~/ 1024;
                  }
                }
                break;
              }
            }
          }
        } catch (_) {}
      } else if (!kIsWeb && Platform.isIOS) {
        cpuAbi = 'arm64';
        is64Bit = true;
        totalRamMb = 3800;
      } else {
        // Desktop / Windows / macOS / Linux dev environments
        cpuAbi = 'x86_64';
        is64Bit = true;
        totalRamMb = 8192;
      }
    } catch (e) {
      debugPrint('Device hardware check fallback: $e');
    }

    // 3. Evaluation against constraints
    bool isCapable = true;
    String reason = 'Device meets all requirements for offline Qwen2.5-0.5B execution.';

    if (freeStorageMb < minStorageMb) {
      isCapable = false;
      reason = 'Insufficient storage: ${freeStorageMb}MB free. Requires at least ${minStorageMb}MB.';
    } else if (totalRamMb < minRamMb) {
      isCapable = false;
      reason = 'Insufficient RAM: ${totalRamMb}MB detected. Requires at least 2GB RAM.';
    } else if (!is64Bit) {
      isCapable = false;
      reason = 'Unsupported 32-bit architecture ($cpuAbi). Requires 64-bit CPU (ARM64/x86_64).';
    }

    final result = DeviceCapabilityResult(
      isCapable: isCapable,
      reason: reason,
      freeStorageMb: freeStorageMb,
      totalRamMb: totalRamMb,
      cpuAbi: cpuAbi,
    );

    _cachedResult = result;
    return result;
  }

  /// Clears cache for testing or runtime re-evaluation
  @visibleForTesting
  static void resetCache() {
    _cachedResult = null;
  }
}
