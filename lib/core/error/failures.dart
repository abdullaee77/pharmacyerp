sealed class AppFailure {
  final String message;
  final String? code;

  const AppFailure({required this.message, this.code});

  @override
  String toString() => 'AppFailure($runtimeType): $message';
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure({
    super.message = 'A database error occurred.',
    super.code,
  });
}

class ValidationFailure extends AppFailure {
  const ValidationFailure({
    super.message = 'Validation failed.',
    super.code,
  });
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message = 'The requested item was not found.',
    super.code,
  });
}

class AuthenticationFailure extends AppFailure {
  const AuthenticationFailure({
    super.message = 'Authentication failed.',
    super.code,
  });
}

class AuthorizationFailure extends AppFailure {
  const AuthorizationFailure({
    super.message = 'You are not authorized to perform this action.',
    super.code,
  });
}

class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message = 'A server error occurred.',
    super.code,
  });
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'Network connection failed.',
    super.code,
  });
}

class LicenseFailure extends AppFailure {
  const LicenseFailure({
    super.message = 'License validation failed.',
    super.code,
  });
}

class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred.',
    super.code,
  });
}