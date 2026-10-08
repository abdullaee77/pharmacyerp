// lib/features/authentication/data/http_auth_repository.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_config.dart';
import '../../../core/result/result.dart';
import '../../users/domain/role.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'sqlite_auth_repository.dart';

/// Login for LAN client PCs.
///
/// Credentials are verified by the SERVER (`/api/login`), which returns a
/// session token plus the user's role and permissions. The client no longer
/// reads the `users` table, and a wrong password is never "retried" against
/// the client's own local database.
///
/// The only exception: if the server cannot be reached at all, the local
/// built-in administrator may sign in so network settings can be fixed.
class HttpAuthRepository implements AuthRepository {
  final ApiClient _api;
  final SqliteAuthRepository _localFallback;
  User? _currentUser;

  HttpAuthRepository({
    ApiClient? api,
    SqliteAuthRepository? localFallback,
  })  : _api = api ?? ApiClient.instance,
        _localFallback = localFallback ?? SqliteAuthRepository();

  static String _hashPassword(String password) {
    // Trim strictly before encoding to prevent whitespace mismatches
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  @override
  Future<Result<User>> login(String username, String password) async {
    final serverIp = NetworkConfig.instance.serverIp.trim();

    // ── LOCAL FALLBACK ──
    if (serverIp.isEmpty) {
      print('ℹ️ [HttpAuth] Server IP is empty. Authenticating against local SQLite...');
      _api.setToken(null);
      final localRes = await _localFallback.login(username, password);

      return localRes.fold(
        onSuccess: (u) {
          _currentUser = u;
          return Success(u);
        },
        onFailure: (f) {
          return Failure(AuthenticationFailure(
            message: '[Local Standalone] ${f.message}',
          ));
        },
      );
    }

    // ── REMOTE LAN LOGIN ──
    print('📡 [HttpAuth] Connecting to LAN Server: ${NetworkConfig.instance.baseUrl}');

    final result = await _api.login(
      username: username.trim(),
      passwordHash: _hashPassword(password),
    );

    return await result.fold(
      onSuccess: (data) => _handleServerLogin(data),
      onFailure: (f) => _handleServerFailure(f, username, password),
    );
  }

  Future<Result<User>> _handleServerLogin(Map<String, dynamic> data) async {
    try {
      final u = Map<String, dynamic>.from(data['user'] as Map);
      final roleId = u['roleId'] as String? ?? '';
      final role = UserRole.fromRoleId(roleId);

      final keys = (data['permissions'] as List? ?? const []).map((e) => e.toString());
      final perms = permissionsFromRows(
        keys.map((k) {
          final parts = k.split('.');
          return <String, dynamic>{
            'category': parts.first,
            'action': parts.length > 1 ? parts[1] : '',
          };
        }),
      );

      final user = User(
        id: UserId(u['id'] as String),
        username: u['username'] as String,
        fullName: u['fullName'] as String,
        email: '',
        role: role,
        roleId: roleId,
        roleName: (u['roleName'] as String?) ?? role.label,
        permissions: perms,
      );

      _currentUser = user;
      print('✅ [HttpAuth] User session authorized by server: ${user.fullName} (${user.roleName})');
      return Success(user);
    } catch (e) {
      _api.setToken(null);
      return const Failure(
        ServerFailure(message: 'Unexpected data structure returned from server.'),
      );
    }
  }

  Future<Result<User>> _handleServerFailure(
      dynamic failure,
      String username,
      String password,
      ) async {
    if (failure is AuthenticationFailure) {
      print('❌ [HttpAuth] Server rejected login credentials.');
      return Failure(AuthenticationFailure(
        message: '[LAN Server] ${failure.message}',
      ));
    }

    print('⚠️ [HttpAuth] Server unreachable. Checking local Administrator fallback...');
    _api.setToken(null);
    final localRes = await _localFallback.login(username, password);
    if (localRes.isSuccess) {
      final local = localRes.valueOrNull;
      if (local != null && local.role == UserRole.admin) {
        _currentUser = local;
        print('🔧 [HttpAuth] Local Administrator authorized for offline configuration.');
        return localRes;
      }
      await _localFallback.logout();
    }
    return const Failure(
      ServerFailure(
        message: 'Cannot reach the server. Check the Server IP, or sign in '
            'as the administrator to change network settings.',
      ),
    );
  }

  @override
  Future<Result<void>> logout() async {
    _currentUser = null;
    await _api.logout();
    await _localFallback.logout();
    return const Success(null);
  }

  @override
  Future<Result<User?>> getCurrentSession() async {
    if (_currentUser != null) return Success(_currentUser);
    return await _localFallback.getCurrentSession();
  }
}