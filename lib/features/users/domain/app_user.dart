import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';

class AppUserId extends ValueObject {
  final String value;
  const AppUserId(this.value);

  factory AppUserId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return AppUserId('usr_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum UserStatus {
  active(label: 'Active'),
  inactive(label: 'Inactive'),
  locked(label: 'Locked');

  final String label;
  const UserStatus({required this.label});
}

/// Administrative user entity for the Users management module.
///
/// Separate from the auth domain User to avoid circular dependencies.
class AppUser extends Entity<AppUserId> {
  final String fullName;
  final String username;
  final String phone;
  final String roleId;
  final String roleName;
  final UserStatus status;
  final String passwordHash;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required super.id,
    required this.fullName,
    required this.username,
    this.phone = '',
    required this.roleId,
    this.roleName = '',
    this.status = UserStatus.active,
    this.passwordHash = '',
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  AppUser copyWith({
    String? fullName,
    String? username,
    String? phone,
    String? roleId,
    String? roleName,
    UserStatus? status,
    String? passwordHash,
    DateTime? lastLoginAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      status: status ?? this.status,
      passwordHash: passwordHash ?? this.passwordHash,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
