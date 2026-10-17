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

  /// Allowed Product IDs accepted by this app from your central Admin License Generator
  static const Set<String> allowedProductIds = {
    'POS_SYSTEM_V1',
    'PHARMASUITE-ERP',
    'MY_APP_PRODUCT_ID',
  };

  /// Base64 Encoded Ed25519 Master Public Key from Admin App
  static const String masterPublicKeyBase64 =
      'IoyoH3oW46M3c1k21efG0AIxUOKDZtao25ykn8e7wY0=';

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
        final decoded = utf8.decode(base64Decode(sanitized));
        jsonMap = jsonDecode(decoded) as Map<String, dynamic>;
      }
    } catch (_) {
      return const Failure(ValidationFailure(
        message: 'Invalid license format. Must be valid JSON or Base64-encoded JSON.',
      ));
    }

    final payload = LicensePayload.fromJson(jsonMap);

    // Accept POS_SYSTEM_V1, PHARMASUITE-ERP or any allowed Product ID
    if (!allowedProductIds.contains(payload.productId)) {
      return Failure(ValidationFailure(
        message: 'Product mismatch: License is for "${payload.productId}", expected "$appProductId".',
      ));
    }

    final currentMachineId = DeviceFingerprint.generate();
    if (payload.machineId.toUpperCase() != currentMachineId.toUpperCase()) {
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

    final isSignatureValid = await _verifyEd25519Signature(
      payload.toSigningPayload(),
      payload.signature,
    );

    if (!isSignatureValid) {
      return const Failure(ValidationFailure(
        message: 'Security warning: Digital signature verification failed! License payload may be tampered with or invalid.',
      ));
    }

    return Success(payload);
  }

  Future<bool> _verifyEd25519Signature(String message, String signatureBase64) async {
    try {
      final algorithm = Ed25519();
      final signatureBytes = base64Decode(signatureBase64.trim());

      var publicKeyBytes = base64Decode(masterPublicKeyBase64.trim());

      // Extract raw 32-byte Ed25519 key if ASN.1 / X.509 header is present
      if (publicKeyBytes.length > 32) {
        publicKeyBytes = publicKeyBytes.sublist(publicKeyBytes.length - 32);
      }

      if (publicKeyBytes.length != 32) {
        debugPrint('License Error: Public key must be 32 bytes, got ${publicKeyBytes.length}');
        return false;
      }

      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );

      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );

      final normalizedLf = message.replaceAll('\r\n', '\n');
      final normalizedCrlf = normalizedLf.replaceAll('\n', '\r\n');

      // Test canonical payload variations across Node.js, WebCrypto, Python & C# generators:
      // 1. Standard Unix LF (\n) without trailing newline
      // 2. Standard Unix LF (\n) with trailing newline
      // 3. Windows CRLF (\r\n) without trailing newline
      // 4. Windows CRLF (\r\n) with trailing newline
      final candidateStrings = [
        normalizedLf,
        '$normalizedLf\n',
        normalizedCrlf,
        '$normalizedCrlf\r\n',
      ];

      for (final str in candidateStrings) {
        final bytes = utf8.encode(str);
        final isValid = await algorithm.verify(bytes, signature: signature);
        if (isValid) {
          debugPrint('✅ License Ed25519 signature verified successfully!');
          return true;
        }

        // Check SHA-256 hashed payload variant (used by WebCrypto wrappers)
        final hashedBytes = sha256.convert(bytes).bytes;
        final isValidHash = await algorithm.verify(hashedBytes, signature: signature);
        if (isValidHash) {
          debugPrint('✅ License Ed25519 signature verified successfully (SHA256 variant)!');
          return true;
        }
      }

      debugPrint('=== LICENSE SIGNATURE MISMATCH DIAGNOSTICS ===');
      debugPrint('Signing Payload generated by App:\n$normalizedLf');
      debugPrint('Signature length: ${signatureBytes.length} bytes');
      debugPrint('Public key length: ${publicKeyBytes.length} bytes');
      debugPrint('==============================================');

      return false;
    } catch (e, stack) {
      debugPrint('Ed25519 Verification Exception: $e\n$stack');
      return false;
    }
  }
}