import 'package:flutter/material.dart';
import '../../domain/user.dart';
import '../../domain/auth_repository.dart';
import '../../application/login_use_case.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;
  final LoginUseCase _loginUseCase;

  AuthController({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        _loginUseCase = LoginUseCase(authRepository);

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True when the user may manage users/roles (permission driven).
  bool get isAdmin => _currentUser?.canManageUsers ?? false;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _loginUseCase.execute(username, password);

    _isLoading = false;
    return result.fold(
      onSuccess: (user) {
        _currentUser = user;
        notifyListeners();
        return true;
      },
      onFailure: (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
    );
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authRepository.logout();

    _currentUser = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}