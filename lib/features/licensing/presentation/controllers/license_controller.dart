// lib/features/licensing/presentation/controllers/license_controller.dart

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
  String get machineId => _repository.getMachineId();

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

  Future<String?> activateLicense(String rawPayload) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.activateLicense(rawPayload);
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