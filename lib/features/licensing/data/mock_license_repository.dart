import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/license.dart';
import '../domain/license_repository.dart';

/// Mock license repository for offline-first operation.
///
/// In production, this would validate against a cryptographic signature
/// or contact a license server. For now, it simulates a valid trial license.
class MockLicenseRepository implements LicenseRepository {
  LicenseInfo _currentLicense = LicenseInfo(
    productId: 'PHARMASUITE-ERP',
    edition: 'Professional',
    status: LicenseStatus.trial,
    licenseKey: 'TRIAL-XXXX-XXXX-XXXX',
    activationDate: DateTime.now().subtract(const Duration(days: 15)),
    expiryDate: DateTime.now().add(const Duration(days: 15)),
    licensedTo: 'Trial User',
    maxUsers: 5,
    maxCounters: 2,
    enabledModules: [
      'Dashboard', 'Medicines', 'Inventory', 'Sales',
      'Purchases', 'Customers', 'Suppliers', 'Accounts',
      'Reports', 'Users', 'Settings',
    ],
    daysRemaining: 15,
  );

  @override
  Future<Result<LicenseInfo>> getLicenseInfo() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Success(_currentLicense);
  }

  @override
  Future<Result<LicenseInfo>> activateLicense(String key) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (key.trim().isEmpty) {
      return const Failure(
          ValidationFailure(message: 'License key cannot be empty.'));
    }

    // Simulate successful activation for any non-empty key
    _currentLicense = LicenseInfo(
      productId: 'PHARMASUITE-ERP',
      edition: 'Professional',
      status: LicenseStatus.active,
      licenseKey: key.trim(),
      activationDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      licensedTo: 'Licensed Pharmacy',
      maxUsers: 20,
      maxCounters: 5,
      enabledModules: [
        'Dashboard', 'Medicines', 'Inventory', 'Sales',
        'Purchases', 'Customers', 'Suppliers', 'Accounts',
        'Reports', 'Users', 'Settings', 'Licensing',
      ],
      daysRemaining: 365,
    );

    return Success(_currentLicense);
  }

  @override
  Future<Result<bool>> validateLicense() async {
    return Success(_currentLicense.isValid);
  }
}