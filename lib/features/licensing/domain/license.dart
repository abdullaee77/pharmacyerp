// // lib/features/licensing/domain/license.dart
//
// import '../../../core/domain/value_object.dart';
// import 'license_payload.dart';
//
// enum LicenseStatus {
//   trial(label: 'Trial', color: 'info'),
//   active(label: 'Active', color: 'success'),
//   expiringSoon(label: 'Expiring Soon', color: 'warning'),
//   expired(label: 'Expired', color: 'error'),
//   activationRequired(label: 'Activation Required', color: 'error'),
//   invalid(label: 'Invalid', color: 'error'),
//   offlineGrace(label: 'Offline Grace Period', color: 'warning');
//
//   final String label;
//   final String color;
//   const LicenseStatus({required this.label, required this.color});
// }
//
// class LicenseInfo extends ValueObject {
//   final String productId;
//   final String edition;
//   final LicenseStatus status;
//   final String licenseKey; // Holds raw JSON or License ID
//   final DateTime? activationDate;
//   final DateTime? expiryDate;
//   final String customerName;
//   final String businessName;
//   final String machineId;
//   final String licenseType;
//   final int daysRemaining;
//   final LicensePayload? payload;
//
//   const LicenseInfo({
//     required this.productId,
//     required this.edition,
//     required this.status,
//     this.licenseKey = '',
//     this.activationDate,
//     this.expiryDate,
//     this.customerName = '',
//     this.businessName = '',
//     this.machineId = '',
//     this.licenseType = 'lifetime',
//     this.daysRemaining = 0,
//     this.payload,
//   });
//
//   String get licensedTo => businessName.isNotEmpty ? businessName : customerName;
//
//   bool get isValid =>
//       status == LicenseStatus.active ||
//           status == LicenseStatus.trial ||
//           status == LicenseStatus.expiringSoon ||
//           status == LicenseStatus.offlineGrace;
//
//   bool get requiresAction =>
//       status == LicenseStatus.expired ||
//           status == LicenseStatus.activationRequired ||
//           status == LicenseStatus.invalid;
// }
// lib/features/licensing/domain/license.dart

import '../../../core/domain/value_object.dart';
import 'license_payload.dart';

enum LicenseStatus {
  trial(label: 'Trial', color: 'info'),
  active(label: 'Active', color: 'success'),
  expiringSoon(label: 'Expiring Soon', color: 'warning'),
  expired(label: 'Expired', color: 'error'),
  activationRequired(label: 'Activation Required', color: 'error'),
  invalid(label: 'Invalid', color: 'error'),
  offlineGrace(label: 'Offline Grace Period', color: 'warning');

  final String label;
  final String color;
  const LicenseStatus({required this.label, required this.color});
}

class LicenseInfo extends ValueObject {
  final String productId;
  final String edition;
  final LicenseStatus status;
  final String licenseKey; // Holds raw JSON or License ID
  final DateTime? activationDate;
  final DateTime? expiryDate;
  final String customerName;
  final String businessName;
  final String machineId;
  final String licenseType;
  final int daysRemaining;
  final LicensePayload? payload;
  final String statusMessage; // Why the license is expired/invalid

  const LicenseInfo({
    required this.productId,
    required this.edition,
    required this.status,
    this.licenseKey = '',
    this.activationDate,
    this.expiryDate,
    this.customerName = '',
    this.businessName = '',
    this.machineId = '',
    this.licenseType = 'lifetime',
    this.daysRemaining = 0,
    this.payload,
    this.statusMessage = '',
  });

  String get licensedTo => businessName.isNotEmpty ? businessName : customerName;

  bool get isValid =>
      status == LicenseStatus.active ||
          status == LicenseStatus.trial ||
          status == LicenseStatus.expiringSoon ||
          status == LicenseStatus.offlineGrace;

  bool get requiresAction =>
      status == LicenseStatus.expired ||
          status == LicenseStatus.activationRequired ||
          status == LicenseStatus.invalid;
}