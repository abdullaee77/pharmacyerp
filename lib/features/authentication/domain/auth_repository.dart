import '../../../core/result/result.dart';
import 'user.dart';

/// Pure Domain repository interface defining authentication contracts.
///
/// Implemented inside the infrastructure/data layer. Zero dependencies on UI.
abstract class AuthRepository {
  /// Authenticates a user using credentials.
  Future<Result<User>> login(String username, String password);

  /// Destroys current localized session.
  Future<Result<void>> logout();

  /// Gets currently cached or authenticated user, if any.
  Future<Result<User?>> getCurrentSession();
}