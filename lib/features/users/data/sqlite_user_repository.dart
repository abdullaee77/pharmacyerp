import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/app_user.dart';
import '../domain/role.dart';
import '../domain/user_repository.dart';

class SqliteUserRepository implements UserRepository {
  final DatabaseHelper _dbHelper;

  SqliteUserRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

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
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'full_name LIKE ? OR username LIKE ? OR phone LIKE ?';
        final q = '%$searchQuery%';
        args = [q, q, q];
      }

      final rows = await db.rawQuery('''
        SELECT u.*, r.name AS role_name
        FROM users u
        LEFT JOIN roles r ON u.role_id = r.id
        ${where != null ? 'WHERE $where' : ''}
        ORDER BY u.full_name ASC
      ''', args ?? []);

      return Success(rows.map(_rowToUser).toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load users: $e'));
    }
  }

  @override
  Future<Result<AppUser>> getUserById(AppUserId id) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        '''
        SELECT u.*, r.name AS role_name
        FROM users u
        LEFT JOIN roles r ON u.role_id = r.id
        WHERE u.id = ?
      ''',
        [id.value],
      );
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'User not found.'));
      }
      return Success(_rowToUser(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load user: $e'));
    }
  }

  @override
  Future<Result<AppUser>> createUser(AppUser u) async {
    try {
      final db = await _db;
      await db.insert('users', {
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
      return Success(u);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create user: $e'));
    }
  }

  @override
  Future<Result<AppUser>> updateUser(AppUser u) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'users',
        {
          'full_name': u.fullName,
          'username': u.username,
          'phone': u.phone,
          'role_id': u.roleId,
          'status': u.status.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [u.id.value],
      );
      if (rows == 0) {
        return const Failure(NotFoundFailure(message: 'User not found.'));
      }
      return Success(u);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update user: $e'));
    }
  }

  @override
  Future<Result<void>> updateUserStatus(AppUserId id, UserStatus status) async {
    try {
      final db = await _db;
      await db.update(
        'users',
        {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id.value],
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update status: $e'));
    }
  }

  @override
  Future<Result<void>> updatePassword(
    AppUserId id,
    String newPasswordHash,
  ) async {
    try {
      final db = await _db;
      await db.update(
        'users',
        {
          'password_hash': newPasswordHash,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id.value],
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update password: $e'));
    }
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

  Future<Set<Permission>> _loadPermissions(Database db, String roleId) async {
    final rows = await db.query(
      'role_permissions',
      where: 'role_id = ?',
      whereArgs: [roleId],
    );
    return rows.map((r) {
      final cat = PermissionCategory.values.firstWhere(
        (e) => e.name == r['category'],
        orElse: () => PermissionCategory.dashboard,
      );
      final act = PermissionAction.values.firstWhere(
        (e) => e.name == r['action'],
        orElse: () => PermissionAction.view,
      );
      return Permission(cat, act);
    }).toSet();
  }

  @override
  Future<Result<List<Role>>> getRoles() async {
    try {
      final db = await _db;
      final rows = await db.query('roles', orderBy: 'name ASC');
      final roles = <Role>[];
      for (final r in rows) {
        final perms = await _loadPermissions(db, r['id'] as String);
        roles.add(_rowToRole(r, perms));
      }
      return Success(roles);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load roles: $e'));
    }
  }

  @override
  Future<Result<Role>> getRoleById(RoleId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'roles',
        where: 'id = ?',
        whereArgs: [id.value],
      );
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Role not found.'));
      }
      final perms = await _loadPermissions(db, id.value);
      return Success(_rowToRole(rows.first, perms));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load role: $e'));
    }
  }

  @override
  Future<Result<Role>> createRole(Role role) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.insert('roles', {
          'id': role.id.value,
          'name': role.name,
          'description': role.description,
          'is_built_in': role.isBuiltIn ? 1 : 0,
          'created_at': role.createdAt.toIso8601String(),
        });
        for (final p in role.permissions) {
          await txn.insert('role_permissions', {
            'role_id': role.id.value,
            'category': p.category.name,
            'action': p.action.name,
          });
        }
      });
      return Success(role);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create role: $e'));
    }
  }

  @override
  Future<Result<Role>> updateRole(Role role) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.update(
          'roles',
          {'name': role.name, 'description': role.description},
          where: 'id = ?',
          whereArgs: [role.id.value],
        );
        await txn.delete(
          'role_permissions',
          where: 'role_id = ?',
          whereArgs: [role.id.value],
        );
        for (final p in role.permissions) {
          await txn.insert('role_permissions', {
            'role_id': role.id.value,
            'category': p.category.name,
            'action': p.action.name,
          });
        }
      });
      return Success(role);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update role: $e'));
    }
  }

  @override
  Future<Result<void>> deleteRole(RoleId id) async {
    try {
      final db = await _db;
      final roleRows = await db.query(
        'roles',
        where: 'id = ?',
        whereArgs: [id.value],
      );
      if (roleRows.isNotEmpty &&
          (roleRows.first['is_built_in'] as int? ?? 0) == 1) {
        return const Failure(
          ValidationFailure(message: 'Cannot delete a built-in role.'),
        );
      }
      await db.transaction((txn) async {
        await txn.delete(
          'role_permissions',
          where: 'role_id = ?',
          whereArgs: [id.value],
        );
        await txn.delete('roles', where: 'id = ?', whereArgs: [id.value]);
      });
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete role: $e'));
    }
  }
}
