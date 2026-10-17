// lib/features/licensing/domain/license_repository.dart

import '../../../core/result/result.dart';
import 'license.dart';

abstract class LicenseRepository {
  Future<Result<LicenseInfo>> getLicenseInfo();
  Future<Result<LicenseInfo>> activateLicense(String rawPayloadJson);
  Future<Result<bool>> validateLicense();
  String getMachineId();
  Future<Result<void>> deactivateLicense();
}