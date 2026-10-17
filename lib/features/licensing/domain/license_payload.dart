// lib/features/licensing/domain/license_payload.dart

import 'dart:convert';

class LicensePayload {
  final int licenseVersion;
  final String licenseId;
  final String productId;
  final String customerId;
  final String customerName;
  final String businessName;
  final String machineId;
  final String licenseType; // "lifetime" or "time_limited"
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
      machineId: json['machineId'] as String? ?? '',
      licenseType: json['licenseType'] as String? ?? 'lifetime',
      issuedAt: json['issuedAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      previousLicenseId: json['previousLicenseId'] as String?,
      reboundAt: json['reboundAt'] as String?,
      signature: json['signature'] as String? ?? '',
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
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'status': status,
      'notes': notes,
      'previousLicenseId': previousLicenseId,
      'reboundAt': reboundAt,
      'signature': signature,
    };
  }

  /// Reconstructs the exact canonical string format used during signing.
  /// Format:
  /// licenseVersion:[licenseVersion]
  /// licenseId:[licenseId]
  /// productId:[productId]
  /// customerId:[customerId]
  /// customerName:[customerName]
  /// businessName:[businessName]
  /// machineId:[machineId]
  /// licenseType:[licenseType]
  /// issuedAt:[issuedAt]
  /// expiresAt:[expiresAt]
  /// status:[status]
  /// notes:[notes]
  String toSigningPayload() {
    return [
      'licenseVersion:$licenseVersion',
      'licenseId:$licenseId',
      'productId:$productId',
      'customerId:$customerId',
      'customerName:$customerName',
      'businessName:$businessName',
      'machineId:$machineId',
      'licenseType:$licenseType',
      'issuedAt:$issuedAt',
      'expiresAt:${expiresAt ?? ''}',
      'status:$status',
      'notes:${notes ?? ''}',
    ].join('\n');
  }
}