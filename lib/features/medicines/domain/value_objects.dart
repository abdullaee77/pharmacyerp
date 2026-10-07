import '../../../core/domain/value_object.dart';

/// Money value object using integer minor units (paisa) to avoid
/// floating-point rounding errors in financial calculations.
///
/// 1 PKR = 100 paisa.
/// PKR 150.50 → paisa 15050.
class Money extends ValueObject {
  /// Amount in minor units (paisa).
  final int paisa;

  const Money({required this.paisa});

  /// Create from a PKR double value. Use only for UI input conversion.
  factory Money.fromPkr(double pkr) => Money(paisa: (pkr * 100).round());

  /// Create directly from integer paisa (preferred for storage/domain).
  factory Money.fromPaisa(int paisa) => Money(paisa: paisa);

  /// Zero amount.
  factory Money.zero() => const Money(paisa: 0);

  /// Convert to PKR double for display only.
  double get pkr => paisa / 100;

  /// Formatted display string.
  String get display => 'PKR ${pkr.toStringAsFixed(2)}';

  bool get isZero => paisa == 0;
  bool get isPositive => paisa > 0;

  Money operator +(Money other) => Money(paisa: paisa + other.paisa);
  Money operator -(Money other) => Money(paisa: paisa - other.paisa);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Money && runtimeType == other.runtimeType && paisa == other.paisa;

  @override
  int get hashCode => paisa.hashCode;

  @override
  String toString() => display;
}

/// Barcode value object with domain validation.
class Barcode extends ValueObject {
  final String value;

  const Barcode._(this.value);

  /// Creates a Barcode after validation.
  /// Returns null if the barcode is empty or invalid.
  static Barcode? create(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 50) return null;
    return Barcode._(trimmed);
  }

  /// Creates a Barcode without validation (for known-good data from DB).
  factory Barcode.unsafe(String value) => Barcode._(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Barcode && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Quantity value object ensuring non-negative inventory counts.
class Quantity extends ValueObject {
  final int value;

  const Quantity._(this.value);

  /// Creates a Quantity, clamping to zero if negative.
  factory Quantity.create(int amount) =>
      Quantity._(amount < 0 ? 0 : amount);

  factory Quantity.zero() => const Quantity._(0);

  bool get isZero => value == 0;
  bool get isLow => value > 0 && value <= 10;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Quantity && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}