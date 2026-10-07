import 'dart:async';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

/// SQLite and system storage mock implementation of the [AuthRepository] contract.
///
/// Simulates latency and verifies credentials using a hardcoded local registry.
class MockAuthRepository implements AuthRepository {
  User? _currentUser;

  // Local user register database mockup
  static final List<Map<String, dynamic>> _userDb = [
    {
      'id': 'usr_001',
      'username': 'admin',
      'password': 'password',
      'fullName': 'Dr. Alexander Dev',
      'email': 'admin@pharmasuite.com',
      'role': UserRole.admin,
    },
    {
      'id': 'usr_002',
      'username': 'pharmacist',
      'password': 'password',
      'fullName': 'Sarah Jenkins, PharmD',
      'email': 'sarah.j@pharmasuite.com',
      'role': UserRole.pharmacist,
    },
    {
      'id': 'usr_003',
      'username': 'cashier',
      'password': 'password',
      'fullName': 'John Smith',
      'email': 'john.s@pharmasuite.com',
      'role': UserRole.cashier,
    },
  ];

  @override
  Future<Result<User>> login(String username, String password) async {
    // Simulate typical SQLite disk/network response delay on desktop
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final userRecord = _userDb.firstWhere(
        (u) =>
            u['username'] == username.toLowerCase() &&
            u['password'] == password,
        orElse: () => throw const AuthenticationFailure(),
      );

      final user = User(
        id: UserId(userRecord['id'] as String),
        username: userRecord['username'] as String,
        fullName: userRecord['fullName'] as String,
        email: userRecord['email'] as String,
        role: userRecord['role'] as UserRole,
      );

      _currentUser = user;
      return Success(user);
    } on AuthenticationFailure {
      return const Failure(
        AuthenticationFailure(message: 'Invalid username or password.'),
      );
    } catch (e) {
      return const Failure(
        UnknownFailure(message: 'An system storage error occurred.'),
      );
    }
  }

  @override
  Future<Result<void>> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
    return const Success(null);
  }

  @override
  Future<Result<User?>> getCurrentSession() async {
    return Success(_currentUser);
  }
}