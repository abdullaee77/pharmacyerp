/// Base class for all application failures.
///
/// Failures represent expected error conditions returned through
/// the [Result] type. They are NOT exceptions — they are domain-aware
/// error descriptions that the Presentation layer can pattern-match on.
sealed class AppFailure {
  final String message;
  final String? code;

  const AppFailure({required this.message, this.code});

  @override
  String toString() => 'AppFailure($runtimeType): $message';
}

/// A failure originating from the local database or persistence layer.
class DatabaseFailure extends AppFailure {
  const DatabaseFailure({
    super.message = 'A database error occurred.',
    super.code,
  });
}

/// A failure caused by invalid input or broken business rules.
class ValidationFailure extends AppFailure {
  const ValidationFailure({
    super.message = 'Validation failed.',
    super.code,
  });
}

/// The requested entity or resource was not found.
class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message = 'The requested item was not found.',
    super.code,
  });
}

/// Authentication credentials are missing or invalid.
class AuthenticationFailure extends AppFailure {
  const AuthenticationFailure({
    super.message = 'Authentication failed.',
    super.code,
  });
}

/// The user is authenticated but lacks permission.
class AuthorizationFailure extends AppFailure {
  const AuthorizationFailure({
    super.message = 'You are not authorized to perform this action.',
    super.code,
  });
}

/// A failure originating from a remote server or network call.
/// Reserved for future LAN/server integration.
class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message = 'A server error occurred.',
    super.code,
  });
}

/// A failure related to license validation.
/// Reserved for future licensing feature.
class LicenseFailure extends AppFailure {
  const LicenseFailure({
    super.message = 'License validation failed.',
    super.code,
  });
}

/// Catch-all for unexpected errors.
class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred.',
    super.code,
  });
}