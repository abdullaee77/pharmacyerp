import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../users/domain/role.dart';

class UserId extends ValueObject {
  final String value;
  const UserId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum UserRole {
  admin(label: 'Administrator', canManageUsers: true, canAdjustStock: true),
  manager(label: 'Manager', canManageUsers: true, canAdjustStock: true),
  pharmacist(label: 'Pharmacist', canManageUsers: false, canAdjustStock: true),
  cashier(label: 'Cashier / POS Operator', canManageUsers: false, canAdjustStock: false);

  final String label;
  final bool canManageUsers;
  final bool canAdjustStock;

  const UserRole({
    required this.label,
    required this.canManageUsers,
    required this.canAdjustStock,
  });

  /// Maps by role ID (never by name). Custom roles fall back to cashier and
  /// rely entirely on their stored permissions.
  static UserRole fromRoleId(String roleId) {
    switch (roleId) {
      case 'role_admin':
        return UserRole.admin;
      case 'role_manager':
        return UserRole.manager;
      case 'role_pharmacist':
        return UserRole.pharmacist;
      default:
        return UserRole.cashier;
    }
  }
}

class User extends Entity<UserId> {
  final String username;
  final String fullName;
  final UserRole role;
  final String email;
  final String roleId;
  final String roleName;
  final Set<Permission> permissions;

  const User({
    required super.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.email = '',
    this.roleId = '',
    this.roleName = '',
    this.permissions = const {},
  });

  /// Admin always has everything, so an admin can never lock themselves out.
  bool can(PermissionCategory cat, PermissionAction act) =>
      role == UserRole.admin || permissions.contains(Permission(cat, act));

  bool hasAnyIn(PermissionCategory cat) =>
      role == UserRole.admin || permissions.any((p) => p.category == cat);

  bool get canManageUsers => can(PermissionCategory.users, PermissionAction.manage);
  bool get canAdjustStock => can(PermissionCategory.inventory, PermissionAction.adjust);

  @override
  String toString() => 'User($username, Role: ${roleName.isEmpty ? role.name : roleName})';
}