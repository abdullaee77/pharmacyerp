import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

/// Unique batch identifier.
class BatchId extends ValueObject {
  final String value;
  const BatchId(this.value);

  factory BatchId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return BatchId('bat_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BatchId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Batch number value object with validation.
class BatchNumber extends ValueObject {
  final String value;

  const BatchNumber._(this.value);

  static BatchNumber? create(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 40) return null;
    return BatchNumber._(trimmed);
  }

  factory BatchNumber.unsafe(String value) => BatchNumber._(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BatchNumber && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Expiry date value object with pharmacy-specific domain rules.
class ExpiryDate extends ValueObject {
  final DateTime date;

  const ExpiryDate(this.date);

  /// Whether this batch has already expired.
  bool get isExpired => date.isBefore(DateTime.now());

  /// Whether this batch expires within the given threshold (default 90 days).
  bool isExpiringSoon({int daysThreshold = 90}) {
    if (isExpired) return false;
    final daysLeft = date.difference(DateTime.now()).inDays;
    return daysLeft <= daysThreshold;
  }

  /// Days remaining until expiry. Negative if expired.
  int get daysRemaining => date.difference(DateTime.now()).inDays;

  /// Display format: MM/YYYY
  String get display =>
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ExpiryDate &&
              runtimeType == other.runtimeType &&
              date.year == other.date.year &&
              date.month == other.date.month &&
              date.day == other.date.day;

  @override
  int get hashCode => Object.hash(date.year, date.month, date.day);

  @override
  String toString() => display;
}

/// Batch lifecycle status derived from expiry domain rules.
enum BatchStatus {
  normal(label: 'Normal'),
  expiringSoon(label: 'Expiring Soon'),
  expired(label: 'Expired');

  final String label;
  const BatchStatus({required this.label});
}

/// A specific production batch of a medicine.
///
/// Two batches of the same medicine are distinct entities with
/// independent quantities, expiry dates, and pricing.
class Batch extends Entity<BatchId> {
  final MedicineId medicineId;
  final String medicineName;
  final BatchNumber batchNumber;
  final ExpiryDate expiryDate;
  final Quantity quantity;
  final Money purchasePrice;
  final Money sellingPrice;
  final BatchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Batch({
    required super.id,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    this.status = BatchStatus.normal,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Derive status dynamically from expiry date.
  static BatchStatus deriveStatus(ExpiryDate expiry, {int daysThreshold = 90}) {
    if (expiry.isExpired) return BatchStatus.expired;
    if (expiry.isExpiringSoon(daysThreshold: daysThreshold)) return BatchStatus.expiringSoon;
    return BatchStatus.normal;
  }

  /// Total value of this batch at selling price.
  Money get totalValue => Money.fromPaisa(sellingPrice.paisa * quantity.value);

  Batch copyWith({
    BatchNumber? batchNumber,
    ExpiryDate? expiryDate,
    Quantity? quantity,
    Money? purchasePrice,
    Money? sellingPrice,
    BatchStatus? status,
    DateTime? updatedAt,
  }) {
    return Batch(
      id: id,
      medicineId: medicineId,
      medicineName: medicineName,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}