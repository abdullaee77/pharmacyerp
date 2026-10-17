// // lib/features/licensing/domain/license_payload.dart
//
// import 'dart:convert';
//
// class LicensePayload {
//   final int licenseVersion;
//   final String licenseId;
//   final String productId;
//   final String customerId;
//   final String customerName;
//   final String businessName;
//   final String machineId;
//   final String licenseType; // "lifetime" or "time_limited"
//   final String issuedAt;
//   final String? expiresAt;
//   final String status; // "active"
//   final String? notes;
//   final String? previousLicenseId;
//   final String? reboundAt;
//   final String signature;
//
//   const LicensePayload({
//     required this.licenseVersion,
//     required this.licenseId,
//     required this.productId,
//     required this.customerId,
//     required this.customerName,
//     required this.businessName,
//     required this.machineId,
//     required this.licenseType,
//     required this.issuedAt,
//     this.expiresAt,
//     required this.status,
//     this.notes,
//     this.previousLicenseId,
//     this.reboundAt,
//     required this.signature,
//   });
//
//   factory LicensePayload.fromJson(Map<String, dynamic> json) {
//     return LicensePayload(
//       licenseVersion: (json['licenseVersion'] as num?)?.toInt() ?? 1,
//       licenseId: json['licenseId'] as String? ?? '',
//       productId: json['productId'] as String? ?? '',
//       customerId: json['customerId'] as String? ?? '',
//       customerName: json['customerName'] as String? ?? '',
//       businessName: json['businessName'] as String? ?? '',
//       machineId: json['machineId'] as String? ?? '',
//       licenseType: json['licenseType'] as String? ?? 'lifetime',
//       issuedAt: json['issuedAt'] as String? ?? '',
//       expiresAt: json['expiresAt'] as String?,
//       status: json['status'] as String? ?? 'active',
//       notes: json['notes'] as String?,
//       previousLicenseId: json['previousLicenseId'] as String?,
//       reboundAt: json['reboundAt'] as String?,
//       signature: json['signature'] as String? ?? '',
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'licenseVersion': licenseVersion,
//       'licenseId': licenseId,
//       'productId': productId,
//       'customerId': customerId,
//       'customerName': customerName,
//       'businessName': businessName,
//       'machineId': machineId,
//       'licenseType': licenseType,
//       'issuedAt': issuedAt,
//       'expiresAt': expiresAt,
//       'status': status,
//       'notes': notes,
//       'previousLicenseId': previousLicenseId,
//       'reboundAt': reboundAt,
//       'signature': signature,
//     };
//   }
//
//   /// Reconstructs the EXACT canonical string used by the generator.
//   /// MUST match License.toSigningPayload() in pos_license_manager byte-for-byte.
//   ///
//   /// Key rules:
//   /// - Every line ends with \n (including the last line).
//   /// - previousLicenseId and reboundAt are ONLY included if non-null.
//   /// - Null strings become empty string.
//   String toSigningPayload() {
//     final buffer = StringBuffer();
//     buffer.write('licenseVersion:$licenseVersion\n');
//     buffer.write('licenseId:$licenseId\n');
//     buffer.write('productId:$productId\n');
//     buffer.write('customerId:$customerId\n');
//     buffer.write('customerName:$customerName\n');
//     buffer.write('businessName:$businessName\n');
//     buffer.write('machineId:$machineId\n');
//     buffer.write('licenseType:$licenseType\n');
//     buffer.write('issuedAt:$issuedAt\n');
//     buffer.write('expiresAt:${expiresAt ?? ''}\n');
//     buffer.write('status:$status\n');
//     buffer.write('notes:${notes ?? ''}\n');
//     if (previousLicenseId != null) {
//       buffer.write('previousLicenseId:$previousLicenseId\n');
//     }
//     if (reboundAt != null) {
//       buffer.write('reboundAt:$reboundAt\n');
//     }
//     return buffer.toString();
//   }
// }
// lib/features/licensing/domain/license_payload.dart

class LicensePayload {
  final int licenseVersion;
  final String licenseId;
  final String productId;
  final String customerId;
  final String customerName;
  final String businessName;
  final String machineId;
  final String licenseType; // "lifetime" or "time_limited"
  final String? platform;   // e.g. "pharmacy" (signed by the generator)
  final String issuedAt;
  final String? expiresAt;
  final String status; // "active"
  final String? notes;
  final String? previousLicenseId;
  final String? reboundAt;
  final String signature;

  const LicensePayload({
    required this.licenseVersion,
    required this.licenseId,
    required this.productId,
    required this.customerId,
    required this.customerName,
    required this.businessName,
    required this.machineId,
    required this.licenseType,
    this.platform,
    required this.issuedAt,
    this.expiresAt,
    required this.status,
    this.notes,
    this.previousLicenseId,
    this.reboundAt,
    required this.signature,
  });

  factory LicensePayload.fromJson(Map<String, dynamic> json) {
    return LicensePayload(
      licenseVersion: (json['licenseVersion'] as num?)?.toInt() ?? 1,
      licenseId: json['licenseId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      machineId: (json['machineId'] as String? ?? '').trim(),
      licenseType: json['licenseType'] as String? ?? 'lifetime',
      platform: json['platform'] as String?,
      issuedAt: json['issuedAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      previousLicenseId: json['previousLicenseId'] as String?,
      reboundAt: json['reboundAt'] as String?,
      signature: (json['signature'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'licenseVersion': licenseVersion,
      'licenseId': licenseId,
      'productId': productId,
      'customerId': customerId,
      'customerName': customerName,
      'businessName': businessName,
      'machineId': machineId,
      'licenseType': licenseType,
      'platform': platform,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'status': status,
      'notes': notes,
      'previousLicenseId': previousLicenseId,
      'reboundAt': reboundAt,
      'signature': signature,
    };
  }

  /// EXACT text the generator signs (verified against a real license).
  /// - every line ends with \n
  /// - platform sits between licenseType and issuedAt (only if present)
  /// - previousLicenseId / reboundAt only if non-null
  String toSigningPayload() {
    final buffer = StringBuffer();
    buffer.write('licenseVersion:$licenseVersion\n');
    buffer.write('licenseId:$licenseId\n');
    buffer.write('productId:$productId\n');
    buffer.write('customerId:$customerId\n');
    buffer.write('customerName:$customerName\n');
    buffer.write('businessName:$businessName\n');
    buffer.write('machineId:$machineId\n');
    buffer.write('licenseType:$licenseType\n');
    if (platform != null) {
      buffer.write('platform:$platform\n');
    }
    buffer.write('issuedAt:$issuedAt\n');
    buffer.write('expiresAt:${expiresAt ?? ''}\n');
    buffer.write('status:$status\n');
    buffer.write('notes:${notes ?? ''}\n');
    if (previousLicenseId != null) {
      buffer.write('previousLicenseId:$previousLicenseId\n');
    }
    if (reboundAt != null) {
      buffer.write('reboundAt:$reboundAt\n');
    }
    return buffer.toString();
  }

  /// Kept so license_validator.dart compiles unchanged.
  /// There is only one real format now.
  Map<String, String> signingCandidates() => {toSigningPayload(): 'canonical'};
}