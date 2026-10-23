import 'package:flutter/material.dart';
import '../../domain/user.dart';
import '../../domain/auth_repository.dart';
import '../../data/sqlite_auth_repository.dart';
import '../../application/login_use_case.dart';
import '../../../licensing/data/sqlite_license_repository.dart';
import '../../../licensing/domain/license.dart';
import '../../../../core/error/failures.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;
  final LoginUseCase _loginUseCase;
  final SqliteLicenseRepository _licenseRepository;

  AuthController({
    required AuthRepository authRepository,
    SqliteLicenseRepository? licenseRepository,
  })  : _authRepository = authRepository,
        _loginUseCase = LoginUseCase(authRepository),
        _licenseRepository = licenseRepository ?? SqliteLicenseRepository();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLicenseError = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True when the last login failed because of license (expired / invalid / missing).
  bool get isLicenseError => _isLicenseError;

  bool get isAdmin => _currentUser?.canManageUsers ?? false;

  Future<bool> hasAnyAdminRegistered() async {
    if (_authRepository is SqliteAuthRepository) {
      return await (_authRepository as SqliteAuthRepository).hasAnyAdmin();
    }
    return true; // Fallback if API/Server client is used
  }

  Future<bool> registerMasterAdmin(
      String fullName,
      String username,
      String password,
      ) async {
    _isLoading = true;
    _errorMessage = null;
    _isLicenseError = false;
    notifyListeners();

    if (_authRepository is SqliteAuthRepository) {
      final res =
      await (_authRepository as SqliteAuthRepository).registerMasterAdmin(
        fullName: fullName,
        username: username,
        password: password,
      );

      return res.fold(
        onSuccess: (user) {
          // Do NOT auto-login. User must sign in explicitly after setup.
          _isLoading = false;
          notifyListeners();
          return true;
        },
        onFailure: (f) {
          _errorMessage = f.message;
          _isLoading = false;
          notifyListeners();
          return false;
        },
      );
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _isLicenseError = false;
    notifyListeners();

    final result = await _loginUseCase.execute(username, password);

    User? authenticatedUser;
    AppFailure? authFailure;

    result.fold(
      onSuccess: (user) => authenticatedUser = user,
      onFailure: (f) => authFailure = f,
    );

    // Credentials failed — stop here, never touch currentUser.
    if (authFailure != null || authenticatedUser == null) {
      _isLoading = false;
      _errorMessage = authFailure?.message ?? 'Invalid username or password.';
      _isLicenseError = authFailure is LicenseFailure;
      notifyListeners();
      return false;
    }

    // Credentials OK — verify license BEFORE completing login.
    final licResult = await _licenseRepository.getLicenseInfo();

    var licenseOk = false;
    String? licenseError;

    licResult.fold(
      onSuccess: (info) {
        if (info.isValid) {
          licenseOk = true;
        } else if (info.status == LicenseStatus.expired) {
          licenseError =
          'Your license has expired. Please renew to continue.';
        } else {
          licenseError =
          'A valid license is required. Please activate your license.';
        }
      },
      onFailure: (f) {
        licenseError = 'Unable to verify license. ${f.message}';
      },
    );

    if (!licenseOk) {
      // Clear any session the auth repo may have opened.
      try {
        await _authRepository.logout();
      } catch (_) {}

      _currentUser = null;
      _isLicenseError = true;
      _errorMessage = licenseError ?? 'License validation failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Credentials + license OK — complete login.
    _currentUser = authenticatedUser;
    _isLoading = false;
    _errorMessage = null;
    _isLicenseError = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authRepository.logout();

    _currentUser = null;
    _isLoading = false;
    _errorMessage = null;
    _isLicenseError = false;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null || _isLicenseError) {
      _errorMessage = null;
      _isLicenseError = false;
      notifyListeners();
    }
  }
}