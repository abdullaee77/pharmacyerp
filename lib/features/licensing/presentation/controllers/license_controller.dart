import 'package:flutter/material.dart';
import '../../domain/license.dart';
import '../../domain/license_repository.dart';

class LicenseController extends ChangeNotifier {
  final LicenseRepository _repository;

  LicenseController({required LicenseRepository repository})
    : _repository = repository;

  LicenseInfo? _license;
  bool _isLoading = false;
  String? _error;

  LicenseInfo? get license => _license;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isValid => _license?.isValid ?? false;

  Future<void> loadLicense() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.getLicenseInfo();
    result.fold(
      onSuccess: (info) {
        _license = info;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<String?> activateLicense(String key) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.activateLicense(key);
    return result.fold(
      onSuccess: (info) {
        _license = info;
        _isLoading = false;
        notifyListeners();
        return null;
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
        return f.message;
      },
    );
  }
}
