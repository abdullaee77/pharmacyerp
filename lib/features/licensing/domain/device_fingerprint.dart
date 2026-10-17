// lib/features/licensing/domain/device_fingerprint.dart

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class DeviceFingerprint {
  DeviceFingerprint._();

  /// Generates a stable 32-character uppercase hardware fingerprint using:
  /// SHA256( Platform.localHostname | Platform.operatingSystem | Platform.operatingSystemVersion | Platform.numberOfProcessors )
  static String generate() {
    final raw = '${Platform.localHostname}|${Platform.operatingSystem}|${Platform.operatingSystemVersion}|${Platform.numberOfProcessors}';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32).toUpperCase();
  }
}