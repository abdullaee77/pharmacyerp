import '../../../core/result/result.dart';
import 'license.dart';

abstract class LicenseRepository {
  Future<Result<LicenseInfo>> getLicenseInfo();
  Future<Result<LicenseInfo>> activateLicense(String key);
  Future<Result<bool>> validateLicense();
}