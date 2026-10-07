import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';

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
  final String licenseKey;
  final DateTime? activationDate;
  final DateTime? expiryDate;
  final String licensedTo;
  final int maxUsers;
  final int maxCounters;
  final List<String> enabledModules;
  final int daysRemaining;

  const LicenseInfo({
    required this.productId,
    required this.edition,
    required this.status,
    this.licenseKey = '',
    this.activationDate,
    this.expiryDate,
    this.licensedTo = '',
    this.maxUsers = 1,
    this.maxCounters = 1,
    this.enabledModules = const [],
    this.daysRemaining = 0,
  });

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