import 'package:flutter/material.dart';
import '../../application/user_use_cases.dart';
import '../../domain/app_user.dart';
import '../../domain/role.dart';
import '../../domain/user_repository.dart';

class UserController extends ChangeNotifier {
  final GetUsersUseCase _getUsers;
  final CreateUserUseCase _createUser;
  final UpdateUserUseCase _updateUser;
  final ChangeUserStatusUseCase _changeStatus;
  final ResetPasswordUseCase _resetPassword;
  final GetRolesUseCase _getRoles;
  final SaveRoleUseCase _saveRole;
  final DeleteRoleUseCase _deleteRole;

  UserController({required UserRepository repository})
    : _getUsers = GetUsersUseCase(repository),
      _createUser = CreateUserUseCase(repository),
      _updateUser = UpdateUserUseCase(repository),
      _changeStatus = ChangeUserStatusUseCase(repository),
      _resetPassword = ResetPasswordUseCase(repository),
      _getRoles = GetRolesUseCase(repository),
      _saveRole = SaveRoleUseCase(repository),
      _deleteRole = DeleteRoleUseCase(repository);

  List<AppUser> _users = [];
  List<Role> _roles = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<AppUser> get users => _users;
  List<Role> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final r = await _getUsers.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
    r.fold(
      onSuccess: (d) {
        _users = d;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void search(String q) {
    _searchQuery = q;
    loadUsers();
  }

  Future<String?> createUser(AppUser u, String password) async {
    final r = await _createUser.execute(u, password);
    return r.fold(
      onSuccess: (_) {
        loadUsers();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> updateUser(AppUser u) async {
    final r = await _updateUser.execute(u);
    return r.fold(
      onSuccess: (_) {
        loadUsers();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> changeStatus(AppUserId id, UserStatus status) async {
    final r = await _changeStatus.execute(id, status);
    return r.fold(
      onSuccess: (_) {
        loadUsers();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> resetPassword(AppUserId id, String newPassword) async {
    final r = await _resetPassword.execute(id, newPassword);
    return r.fold(onSuccess: (_) => null, onFailure: (f) => f.message);
  }

  Future<void> loadRoles() async {
    _isLoading = true;
    notifyListeners();
    final r = await _getRoles.execute();
    r.fold(
      onSuccess: (d) {
        _roles = d;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<String?> saveRole(Role role, {bool isNew = true}) async {
    final r = await _saveRole.execute(role, isNew: isNew);
    return r.fold(
      onSuccess: (_) {
        loadRoles();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteRole(RoleId id) async {
    final r = await _deleteRole.execute(id);
    return r.fold(
      onSuccess: (_) {
        loadRoles();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }
}
