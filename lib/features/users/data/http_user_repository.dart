import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/app_user.dart';
import '../domain/role.dart';
import '../domain/user_repository.dart';

class HttpUserRepository implements UserRepository {
  final ApiClient _api;

  HttpUserRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  AppUser _rowToUser(Map<String, dynamic> r) {
    return AppUser(
      id: AppUserId(r['id'] as String),
      fullName: r['full_name'] as String,
      username: r['username'] as String,
      phone: r['phone'] as String? ?? '',
      roleId: r['role_id'] as String,
      roleName: r['role_name'] as String? ?? '',
      status: UserStatus.values.firstWhere(
            (e) => e.name == r['status'],
        orElse: () => UserStatus.active,
      ),
      // The server never sends password hashes to clients.
      passwordHash: r['password_hash'] as String? ?? '',
      lastLoginAt: r['last_login_at'] != null
          ? DateTime.parse(r['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  @override
  Future<Result<List<AppUser>>> getUsers({String? searchQuery}) async {
    final where = searchQuery != null && searchQuery.isNotEmpty
        ? 'full_name LIKE ? OR username LIKE ? OR phone LIKE ?'
        : null;
    final args = searchQuery != null && searchQuery.isNotEmpty
        ? ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']
        : [];

    final sql = '''
      SELECT u.*, r.name AS role_name
      FROM users u
      LEFT JOIN roles r ON u.role_id = r.id
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY u.full_name ASC
    ''';

    final res = await _api.rawQuery(sql: sql, args: args);
    return res.fold(
      onSuccess: (rows) => Success(rows.map(_rowToUser).toList()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<AppUser>> getUserById(AppUserId id) async {
    final sql = '''
      SELECT u.*, r.name AS role_name
      FROM users u
      LEFT JOIN roles r ON u.role_id = r.id
      WHERE u.id = ?
    ''';
    final res = await _api.rawQuery(sql: sql, args: [id.value]);
    return res.fold(
      onSuccess: (rows) => rows.isEmpty
          ? const Failure(NotFoundFailure(message: 'User not found.'))
          : Success(_rowToUser(rows.first)),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<AppUser>> createUser(AppUser u) async {
    final res = await _api.insert(table: 'users', data: {
      'id': u.id.value,
      'full_name': u.fullName,
      'username': u.username,
      'phone': u.phone,
      'role_id': u.roleId,
      'status': u.status.name,
      'password_hash': u.passwordHash,
      'last_login_at': u.lastLoginAt?.toIso8601String(),
      'created_at': u.createdAt.toIso8601String(),
      'updated_at': u.updatedAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => Success(u), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<AppUser>> updateUser(AppUser u) async {
    final res = await _api.update(
      table: 'users',
      data: {
        'full_name': u.fullName,
        'username': u.username,
        'phone': u.phone,
        'role_id': u.roleId,
        'status': u.status.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      args: [u.id.value],
    );
    return res.fold(
      onSuccess: (c) => c == 0
          ? const Failure(NotFoundFailure(message: 'User not found.'))
          : Success(u),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> updateUserStatus(AppUserId id, UserStatus status) async {
    final res = await _api.update(
      table: 'users',
      data: {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      args: [id.value],
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> updatePassword(AppUserId id, String newPasswordHash) async {
    final res = await _api.update(
      table: 'users',
      data: {
        'password_hash': newPasswordHash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      args: [id.value],
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  // ─── ROLES ──────────────────────────────────────────────────

  Role _rowToRole(Map<String, dynamic> r, Set<Permission> perms) {
    return Role(
      id: RoleId(r['id'] as String),
      name: r['name'] as String,
      description: r['description'] as String? ?? '',
      isBuiltIn: (r['is_built_in'] as int? ?? 0) == 1,
      permissions: perms,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }

  /// Loads every role's permissions with ONE request (instead of one per role).
  /// A failure is returned as a failure - never as "a role with no permissions",
  /// which could wipe a role's permissions if an admin then pressed Save.
  Future<Result<List<Role>>> _attachPermissions(
      List<Map<String, dynamic>> roleRows,
      ) async {
    final permRes = await _api.query(table: 'role_permissions');
    return permRes.fold(
      onSuccess: (permRows) {
        final byRole = <String, List<Map<String, dynamic>>>{};
        for (final p in permRows) {
          byRole.putIfAbsent(p['role_id'] as String, () => []).add(p);
        }
        final roles = roleRows
            .map(
              (r) => _rowToRole(
            r,
            permissionsFromRows(byRole[r['id'] as String] ?? const []),
          ),
        )
            .toList();
        return Success(roles);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<Role>>> getRoles() async {
    final res = await _api.query(table: 'roles', orderBy: 'name ASC');
    return await res.fold(
      onSuccess: (rows) => _attachPermissions(rows),
      onFailure: (f) async => Failure(f),
    );
  }

  @override
  Future<Result<Role>> getRoleById(RoleId id) async {
    final res = await _api.query(table: 'roles', where: 'id = ?', args: [id.value]);
    return await res.fold(
      onSuccess: (rows) async {
        if (rows.isEmpty) {
          return const Failure(NotFoundFailure(message: 'Role not found.'));
        }
        final permRes = await _api.query(
          table: 'role_permissions',
          where: 'role_id = ?',
          args: [id.value],
        );
        return permRes.fold(
          onSuccess: (permRows) =>
              Success(_rowToRole(rows.first, permissionsFromRows(permRows))),
          onFailure: (f) => Failure(f),
        );
      },
      onFailure: (f) async => Failure(f),
    );
  }

  List<Map<String, dynamic>> _permissionInserts(Role role) => [
    for (final p in role.permissions)
      {
        'type': 'insert',
        'table': 'role_permissions',
        'data': {
          'role_id': role.id.value,
          'category': p.category.name,
          'action': p.action.name,
        },
      },
  ];

  /// The role row and all of its permissions are saved in ONE server
  /// transaction: either everything is saved or nothing is.
  @override
  Future<Result<Role>> createRole(Role role) async {
    final res = await _api.batch([
      {
        'type': 'insert',
        'table': 'roles',
        'data': {
          'id': role.id.value,
          'name': role.name,
          'description': role.description,
          'is_built_in': role.isBuiltIn ? 1 : 0,
          'created_at': role.createdAt.toIso8601String(),
        },
      },
      ..._permissionInserts(role),
    ]);
    return res.fold(onSuccess: (_) => Success(role), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<Role>> updateRole(Role role) async {
    final res = await _api.batch([
      {
        'type': 'update',
        'table': 'roles',
        'data': {'name': role.name, 'description': role.description},
        'where': 'id = ?',
        'args': [role.id.value],
      },
      {
        'type': 'delete',
        'table': 'role_permissions',
        'where': 'role_id = ?',
        'args': [role.id.value],
      },
      ..._permissionInserts(role),
    ]);
    return res.fold(onSuccess: (_) => Success(role), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<void>> deleteRole(RoleId id) async {
    final existing = await getRoleById(id);
    if (existing.isSuccess && existing.valueOrNull!.isBuiltIn) {
      return const Failure(
        ValidationFailure(message: 'Cannot delete a built-in role.'),
      );
    }
    final res = await _api.batch([
      {
        'type': 'delete',
        'table': 'role_permissions',
        'where': 'role_id = ?',
        'args': [id.value],
      },
      {
        'type': 'delete',
        'table': 'roles',
        'where': 'id = ?',
        'args': [id.value],
      },
    ]);
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }
}