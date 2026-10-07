import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/app_user.dart';
import '../domain/role.dart';
import '../domain/user_repository.dart';

/// Hashes a plaintext password using SHA-256.
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

class CreateUserUseCase {
  final UserRepository _repo;
  const CreateUserUseCase(this._repo);

  Future<Result<AppUser>> execute(AppUser user, String plainPassword) async {
    if (user.fullName.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Full name is required.'),
      );
    }
    if (user.username.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Username is required.'));
    }
    if (plainPassword.length < 4) {
      return const Failure(
        ValidationFailure(message: 'Password must be at least 4 characters.'),
      );
    }

    final hashed = hashPassword(plainPassword);
    final finalUser = user.copyWith(passwordHash: hashed);
    return _repo.createUser(finalUser);
  }
}

class UpdateUserUseCase {
  final UserRepository _repo;
  const UpdateUserUseCase(this._repo);

  Future<Result<AppUser>> execute(AppUser user) async {
    if (user.fullName.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Full name is required.'),
      );
    }
    return _repo.updateUser(user);
  }
}

class ChangeUserStatusUseCase {
  final UserRepository _repo;
  const ChangeUserStatusUseCase(this._repo);

  Future<Result<void>> execute(AppUserId id, UserStatus status) {
    return _repo.updateUserStatus(id, status);
  }
}

class ResetPasswordUseCase {
  final UserRepository _repo;
  const ResetPasswordUseCase(this._repo);

  Future<Result<void>> execute(AppUserId id, String newPassword) async {
    if (newPassword.length < 4) {
      return const Failure(
        ValidationFailure(message: 'Password must be at least 4 characters.'),
      );
    }
    return _repo.updatePassword(id, hashPassword(newPassword));
  }
}

class GetUsersUseCase {
  final UserRepository _repo;
  const GetUsersUseCase(this._repo);

  Future<Result<List<AppUser>>> execute({String? searchQuery}) =>
      _repo.getUsers(searchQuery: searchQuery);
}

class GetRolesUseCase {
  final UserRepository _repo;
  const GetRolesUseCase(this._repo);

  Future<Result<List<Role>>> execute() => _repo.getRoles();
}

class SaveRoleUseCase {
  final UserRepository _repo;
  const SaveRoleUseCase(this._repo);

  Future<Result<Role>> execute(Role role, {bool isNew = true}) async {
    if (role.name.trim().isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Role name is required.'),
      );
    }
    return isNew ? _repo.createRole(role) : _repo.updateRole(role);
  }
}

class DeleteRoleUseCase {
  final UserRepository _repo;
  const DeleteRoleUseCase(this._repo);

  Future<Result<void>> execute(RoleId id) => _repo.deleteRole(id);
}
