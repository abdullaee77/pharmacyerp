import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

class LoginUseCase {
  final AuthRepository _authRepository;

  const LoginUseCase(this._authRepository);

  Future<Result<User>> execute(String username, String password) async {
    final cleanUsername = username.trim();
    final cleanPassword = password;

    if (cleanUsername.isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Username cannot be blank.'),
      );
    }

    if (cleanPassword.isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Password cannot be blank.'),
      );
    }

    if (cleanPassword.length < 4) {
      return const Failure(
        ValidationFailure(message: 'Password must be at least 4 characters.'),
      );
    }

    return _authRepository.login(cleanUsername, cleanPassword);
  }
}