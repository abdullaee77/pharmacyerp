import '../../../core/result/result.dart';
import 'app_user.dart';
import 'role.dart';

abstract class UserRepository {
  Future<Result<List<AppUser>>> getUsers({String? searchQuery});
  Future<Result<AppUser>> getUserById(AppUserId id);
  Future<Result<AppUser>> createUser(AppUser user);
  Future<Result<AppUser>> updateUser(AppUser user);
  Future<Result<void>> updateUserStatus(AppUserId id, UserStatus status);
  Future<Result<void>> updatePassword(AppUserId id, String newPasswordHash);

  Future<Result<List<Role>>> getRoles();
  Future<Result<Role>> getRoleById(RoleId id);
  Future<Result<Role>> createRole(Role role);
  Future<Result<Role>> updateRole(Role role);
  Future<Result<void>> deleteRole(RoleId id);
}
