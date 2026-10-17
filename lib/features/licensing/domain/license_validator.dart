// // lib/features/licensing/domain/license_validator.dart
//
// import 'dart:convert';
// import 'package:crypto/crypto.dart';
// import 'package:cryptography/cryptography.dart';
// import 'package:flutter/foundation.dart';
// import '../../../core/error/failures.dart';
// import '../../../core/result/result.dart';
// import 'device_fingerprint.dart';
// import 'license_payload.dart';
//
// class LicenseValidatorImpl {
//   /// Default Product ID
//   static const String appProductId = 'POS_SYSTEM_V1';
//
//   /// Allowed Product IDs accepted by this app from your central Admin License Generator
//   static const Set<String> allowedProductIds = {
//     'POS_SYSTEM_V1',
//     'PHARMASUITE-ERP',
//     'MY_APP_PRODUCT_ID',
//   };
//
//   /// Base64 Encoded Ed25519 Master Public Key from Admin App.
//   /// ⚠️  MUST match the public key derived from the generator's private key seed.
//   ///     Run get_public_key.dart in pos_license_manager to get the correct value.
//   static const String masterPublicKeyBase64 =
//       'IoyoH3oW46M3c1k21efG0AIxUOKDZtao25ykn8e7wY0=';
//
//   Future<Result<LicensePayload>> validate(String rawInput) async {
//     final sanitized = rawInput.trim();
//     if (sanitized.isEmpty) {
//       return const Failure(ValidationFailure(message: 'License payload cannot be empty.'));
//     }
//
//     Map<String, dynamic> jsonMap;
//     try {
//       if (sanitized.startsWith('{')) {
//         jsonMap = jsonDecode(sanitized) as Map<String, dynamic>;
//       } else {
//         final decoded = utf8.decode(base64Decode(sanitized));
//         jsonMap = jsonDecode(decoded) as Map<String, dynamic>;
//       }
//     } catch (_) {
//       return const Failure(ValidationFailure(
//         message: 'Invalid license format. Must be valid JSON or Base64-encoded JSON.',
//       ));
//     }
//
//     final payload = LicensePayload.fromJson(jsonMap);
//
//     // Accept POS_SYSTEM_V1, PHARMASUITE-ERP or any allowed Product ID
//     if (!allowedProductIds.contains(payload.productId)) {
//       return Failure(ValidationFailure(
//         message: 'Product mismatch: License is for "${payload.productId}", expected "$appProductId".',
//       ));
//     }
//
//     final currentMachineId = DeviceFingerprint.generate();
//     if (payload.machineId.toUpperCase() != currentMachineId.toUpperCase()) {
//       return Failure(ValidationFailure(
//         message: 'Device mismatch: License is registered to machine ID "${payload.machineId}". This machine ID is "$currentMachineId".',
//       ));
//     }
//
//     if (payload.status.toLowerCase() != 'active') {
//       return Failure(ValidationFailure(
//         message: 'License status is "${payload.status}". Only active licenses are accepted.',
//       ));
//     }
//
//     if (payload.licenseType == 'time_limited') {
//       if (payload.expiresAt == null || payload.expiresAt!.isEmpty) {
//         return const Failure(ValidationFailure(
//           message: 'Time-limited license is missing an expiration date.',
//         ));
//       }
//       final expiryDate = DateTime.tryParse(payload.expiresAt!);
//       if (expiryDate == null) {
//         return const Failure(ValidationFailure(
//           message: 'Invalid expiration date format in license payload.',
//         ));
//       }
//       if (DateTime.now().toUtc().isAfter(expiryDate.toUtc())) {
//         return Failure(ValidationFailure(
//           message: 'License expired on ${expiryDate.toLocal().toIso8601String().split('T').first}.',
//         ));
//       }
//     }
//
//     if (payload.signature.isEmpty) {
//       return const Failure(ValidationFailure(
//         message: 'Digital signature is missing from license payload.',
//       ));
//     }
//
//     final isSignatureValid = await _verifyEd25519Signature(
//       payload.toSigningPayload(),
//       payload.signature,
//     );
//
//     if (!isSignatureValid) {
//       return const Failure(ValidationFailure(
//         message: 'Security warning: Digital signature verification failed! License payload may be tampered with or invalid.',
//       ));
//     }
//
//     return Success(payload);
//   }
//
//   Future<bool> _verifyEd25519Signature(String message, String signatureBase64) async {
//     try {
//       final algorithm = Ed25519();
//       final signatureBytes = base64Decode(signatureBase64.trim());
//
//       var publicKeyBytes = base64Decode(masterPublicKeyBase64.trim());
//
//       // Extract raw 32-byte Ed25519 key if ASN.1 / X.509 header is present
//       if (publicKeyBytes.length > 32) {
//         publicKeyBytes = publicKeyBytes.sublist(publicKeyBytes.length - 32);
//       }
//
//       if (publicKeyBytes.length != 32) {
//         debugPrint('License Error: Public key must be 32 bytes, got ${publicKeyBytes.length}');
//         return false;
//       }
//
//       final publicKey = SimplePublicKey(
//         publicKeyBytes,
//         type: KeyPairType.ed25519,
//       );
//
//       final signature = Signature(
//         signatureBytes,
//         publicKey: publicKey,
//       );
//
//       // Normalize line endings to LF
//       final normalized = message.replaceAll('\r\n', '\n');
//
//       // Test payload variants (the generator uses trailing \n on every line)
//       final candidates = <String>[
//         normalized,                        // As-is from toSigningPayload()
//         normalized.replaceAll('\n', '\r\n'), // CRLF variant
//       ];
//
//       for (final str in candidates) {
//         final bytes = utf8.encode(str);
//         final isValid = await algorithm.verify(bytes, signature: signature);
//         if (isValid) {
//           debugPrint('✅ License Ed25519 signature verified successfully!');
//           return true;
//         }
//       }
//
//       // ── DIAGNOSTICS (only shown on failure) ──
//       debugPrint('=== LICENSE SIGNATURE MISMATCH DIAGNOSTICS ===');
//       debugPrint('Public key (base64): $masterPublicKeyBase64');
//       debugPrint('Public key SHA-256: ${sha256.convert(publicKeyBytes)}');
//       debugPrint('Signature length: ${signatureBytes.length} bytes');
//       debugPrint('Payload byte length: ${utf8.encode(normalized).length}');
//       debugPrint('Payload SHA-256: ${sha256.convert(utf8.encode(normalized))}');
//       debugPrint('Payload string:\n$normalized');
//       debugPrint('==============================================');
//
//       return false;
//     } catch (e, stack) {
//       debugPrint('Ed25519 Verification Exception: $e\n$stack');
//       return false;
//     }
//   }
// }
// lib/features/licensing/domain/license_validator.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import 'device_fingerprint.dart';
import 'license_payload.dart';

class LicenseValidatorImpl {
  /// Default Product ID
  static const String appProductId = 'POS_SYSTEM_V1';

  static const Set<String> allowedProductIds = {
    'POS_SYSTEM_V1',
    'PHARMASUITE-ERP',
    'MY_APP_PRODUCT_ID',
  };

  /// Base64 Ed25519 master public key from the Admin generator app.
  static const String masterPublicKeyBase64 =
      'IoyoH3oW46M3c1k21efG0AIxUOKDZtao25ykn8e7wY0=';

  /// Tolerant base64 / base64url decoder (ignores whitespace and line breaks).
  static List<int> _b64(String s) {
    final clean = s
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    return base64.decode(base64.normalize(clean));
  }

  Future<Result<LicensePayload>> validate(String rawInput) async {
    final sanitized = rawInput.trim();
    if (sanitized.isEmpty) {
      return const Failure(ValidationFailure(message: 'License payload cannot be empty.'));
    }

    Map<String, dynamic> jsonMap;
    try {
      if (sanitized.startsWith('{')) {
        jsonMap = jsonDecode(sanitized) as Map<String, dynamic>;
      } else {
        final decoded = utf8.decode(_b64(sanitized));
        jsonMap = jsonDecode(decoded) as Map<String, dynamic>;
      }
    } catch (_) {
      return const Failure(ValidationFailure(
        message: 'Invalid license format. Must be valid JSON or Base64-encoded JSON.',
      ));
    }

    final payload = LicensePayload.fromJson(jsonMap);

    if (!allowedProductIds.contains(payload.productId)) {
      return Failure(ValidationFailure(
        message: 'Product mismatch: License is for "${payload.productId}", expected "$appProductId".',
      ));
    }

    final currentMachineId = DeviceFingerprint.generate();
    if (payload.machineId.trim().toUpperCase() != currentMachineId.toUpperCase()) {
      return Failure(ValidationFailure(
        message: 'Device mismatch: License is registered to machine ID "${payload.machineId}". This machine ID is "$currentMachineId".',
      ));
    }

    if (payload.status.toLowerCase() != 'active') {
      return Failure(ValidationFailure(
        message: 'License status is "${payload.status}". Only active licenses are accepted.',
      ));
    }

    if (payload.licenseType == 'time_limited') {
      if (payload.expiresAt == null || payload.expiresAt!.isEmpty) {
        return const Failure(ValidationFailure(
          message: 'Time-limited license is missing an expiration date.',
        ));
      }
      final expiryDate = DateTime.tryParse(payload.expiresAt!);
      if (expiryDate == null) {
        return const Failure(ValidationFailure(
          message: 'Invalid expiration date format in license payload.',
        ));
      }
      if (DateTime.now().toUtc().isAfter(expiryDate.toUtc())) {
        return Failure(ValidationFailure(
          message: 'License expired on ${expiryDate.toLocal().toIso8601String().split('T').first}.',
        ));
      }
    }

    if (payload.signature.isEmpty) {
      return const Failure(ValidationFailure(
        message: 'Digital signature is missing from license payload.',
      ));
    }

    final isSignatureValid = await _verifyEd25519Signature(payload);

    if (!isSignatureValid) {
      return const Failure(ValidationFailure(
        message: 'Security warning: Digital signature verification failed! License payload may be tampered with or invalid.',
      ));
    }

    return Success(payload);
  }

  Future<bool> _verifyEd25519Signature(LicensePayload payload) async {
    try {
      final algorithm = Ed25519();
      final signatureBytes = _b64(payload.signature);

      var publicKeyBytes = _b64(masterPublicKeyBase64);

      // Extract raw 32-byte key if an ASN.1 / X.509 header is present
      if (publicKeyBytes.length > 32) {
        publicKeyBytes = publicKeyBytes.sublist(publicKeyBytes.length - 32);
      }
      if (publicKeyBytes.length != 32) {
        debugPrint('License Error: Public key must be 32 bytes, got ${publicKeyBytes.length}');
        return false;
      }
      if (signatureBytes.length != 64) {
        debugPrint('License Error: Ed25519 signature must be 64 bytes, got ${signatureBytes.length}');
        return false;
      }

      final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: publicKey);

      final candidates = payload.signingCandidates();

      for (final entry in candidates.entries) {
        final ok = await algorithm.verify(utf8.encode(entry.key), signature: signature);
        if (ok) {
          debugPrint('✅ License signature verified. Matched format -> ${entry.value}');
          return true;
        }
      }

      // ── DIAGNOSTICS (only on failure) ──
      final canonical = payload.toSigningPayload();
      debugPrint('❌ No signing format matched (${candidates.length} variants tried).');
      debugPrint('Most likely cause: the generator signs with a DIFFERENT private key,');
      debugPrint('or signs a completely different string than the fields above.');
      debugPrint('Public key (base64): $masterPublicKeyBase64');
      debugPrint('Public key SHA-256: ${sha256.convert(publicKeyBytes)}');
      debugPrint('Signature length: ${signatureBytes.length} bytes');
      debugPrint('Payload byte length: ${utf8.encode(canonical).length}');
      debugPrint('Payload SHA-256: ${sha256.convert(utf8.encode(canonical))}');
      debugPrint('Payload string:\n$canonical');

      return false;
    } catch (e, stack) {
      debugPrint('Ed25519 Verification Exception: $e\n$stack');
      return false;
    }
  }
}