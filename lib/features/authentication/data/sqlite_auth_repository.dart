// lib/features/authentication/data/sqlite_auth_repository.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../users/domain/role.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

/// Real SQLite authentication against local users + roles tables.
class SqliteAuthRepository implements AuthRepository {
  final DatabaseHelper _dbHelper;
  User? _currentUser;

  SqliteAuthRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  static String hashPassword(String password) {
    // Trim strictly before encoding to stay unified with HttpAuthRepository
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  @override
  Future<Result<User>> login(String username, String password) async {
    try {
      final db = await _db;
      final hash = hashPassword(password);

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

      if (status.toLowerCase() == 'inactive') {
        return const Failure(
          AuthenticationFailure(message: 'This account is inactive. Contact an administrator.'),
        );
      }
      if (status.toLowerCase() == 'locked') {
        return const Failure(
          AuthenticationFailure(message: 'This account is locked. Contact an administrator.'),
        );
      }

      if (storedHash != hash) {
        return const Failure(
          AuthenticationFailure(message: 'Invalid username or password.'),
        );
      }

      await db.update(
        'users',
        {
          'last_login_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );

      final roleId = row['role_id'] as String? ?? '';
      final role = UserRole.fromRoleId(roleId);

      final permRows = await db.query(
        'role_permissions',
        where: 'role_id = ?',
        whereArgs: [roleId],
      );

      final user = User(
        id: UserId(row['id'] as String),
        username: row['username'] as String,
        fullName: row['full_name'] as String,
        email: '',
        role: role,
        roleId: roleId,
        roleName: row['role_name'] as String? ?? role.label,
        permissions: permissionsFromRows(permRows),
      );

      _currentUser = user;
      return Success(user);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Login failed: $e'),
      );
    }
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