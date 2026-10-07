import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

/// Real SQLite authentication against the `users` + `roles` tables.
class SqliteAuthRepository implements AuthRepository {
  final DatabaseHelper _dbHelper;
  User? _currentUser;

  SqliteAuthRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  @override
  Future<Result<User>> login(String username, String password) async {
    try {
      final db = await _db;
      final hash = hashPassword(password.trim());

      final rows = await db.rawQuery('''
        SELECT u.*, r.name AS role_name
        FROM users u
        LEFT JOIN roles r ON u.role_id = r.id
        WHERE LOWER(u.username) = LOWER(?)
        LIMIT 1
      ''', [username.trim()]);

      if (rows.isEmpty) {
        return const Failure(
          AuthenticationFailure(message: 'Invalid username or password.'),
        );
      }

      final row = rows.first;
      final status = row['status'] as String? ?? 'active';
      final storedHash = row['password_hash'] as String? ?? '';

      if (status == 'inactive') {
        return const Failure(
          AuthenticationFailure(message: 'This account is inactive. Contact an administrator.'),
        );
      }
      if (status == 'locked') {
        return const Failure(
          AuthenticationFailure(message: 'This account is locked. Contact an administrator.'),
        );
      }

      if (storedHash != hash) {
        return const Failure(
          AuthenticationFailure(message: 'Invalid username or password.'),
        );
      }

      // Update last login
      await db.update(
        'users',
        {
          'last_login_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );

      final roleName = (row['role_name'] as String? ?? 'Cashier').toLowerCase();
      final role = _mapRole(roleName);

      final user = User(
        id: UserId(row['id'] as String),
        username: row['username'] as String,
        fullName: row['full_name'] as String,
        email: '',
        role: role,
        roleId: row['role_id'] as String? ?? '',
        roleName: row['role_name'] as String? ?? role.label,
      );

      _currentUser = user;
      return Success(user);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Login failed: $e'),
      );
    }
  }

  UserRole _mapRole(String roleName) {
    if (roleName.contains('admin')) return UserRole.admin;
    if (roleName.contains('manager')) return UserRole.manager;
    if (roleName.contains('pharmacist')) return UserRole.pharmacist;
    return UserRole.cashier;
  }

  @override
  Future<Result<void>> logout() async {
    _currentUser = null;
    return const Success(null);
  }

  @override
  Future<Result<User?>> getCurrentSession() async {
    return Success(_currentUser);
  }
}