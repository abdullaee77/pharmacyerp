import '../error/failures.dart';

/// A discriminated union representing either a successful value
/// or a typed failure.
///
/// Use this as the standard return type for repository methods,
/// use cases, and application services instead of throwing exceptions
/// for expected error conditions.
///
/// Example:
/// ```dart
/// Result<Medicine> result = await getMedicine(id);
/// result.fold(
///   onSuccess: (medicine) => showMedicine(medicine),
///   onFailure: (failure) => showError(failure.message),
/// );
/// ```
sealed class Result<T> {
  const Result();

  /// Returns `true` if this result is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns `true` if this result is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Returns the value if [Success], or `null` if [Failure].
  T? get valueOrNull => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => null,
  };

  /// Returns the failure if [Failure], or `null` if [Success].
  AppFailure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(failure: final f) => f,
  };

  /// Pattern-matches on the result, calling [onSuccess] or [onFailure].
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => onSuccess(v),
      Failure<T>(failure: final f) => onFailure(f),
    };
  }

  /// Transforms the success value using [transform].
  /// If this is a [Failure], the failure is passed through unchanged.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(value: final v) => Success(transform(v)),
      Failure<T>(failure: final f) => Failure(f),
    };
  }

  /// Chains another operation that returns a [Result].
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    return switch (this) {
      Success<T>(value: final v) => transform(v),
      Failure<T>(failure: final f) => Failure(f),
    };
  }
}

/// Represents a successful result containing a [value].
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result containing an [AppFailure].
class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);

  @override
  String toString() => 'Failure($failure)';
}