import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';

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
}

class User extends Entity<UserId> {
  final String username;
  final String fullName;
  final UserRole role;
  final String email;
  final String roleId;
  final String roleName;

  const User({
    required super.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.email = '',
    this.roleId = '',
    this.roleName = '',
  });

  bool get canManageUsers => role.canManageUsers;
  bool get canAdjustStock => role.canAdjustStock;

  @override
  String toString() => 'User($username, Role: ${roleName.isEmpty ? role.name : roleName})';
}