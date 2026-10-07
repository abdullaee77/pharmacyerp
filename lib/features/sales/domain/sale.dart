import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

/// Unique sale identifier.
class SaleId extends ValueObject {
  final String value;
  const SaleId(this.value);

  factory SaleId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return SaleId('sale_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SaleId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Invoice number sequence helper (per-day sequential).
class InvoiceNumber extends ValueObject {
  final String value;
  const InvoiceNumber(this.value);

  factory InvoiceNumber.generate() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    return InvoiceNumber('INV-$y$m$d-$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is InvoiceNumber &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Status of a sale.
enum SaleStatus {
  completed(label: 'Completed'),
  held(label: 'Held'),
  cancelled(label: 'Cancelled'),
  partiallyReturned(label: 'Partially Returned'),
  returned(label: 'Returned');

  final String label;
  const SaleStatus({required this.label});
}

/// Immutable snapshot of a sold line.
class SaleItem {
  final String id;
  final MedicineId medicineId;
  final String medicineName;
  final String medicineStrength;
  final BatchId batchId;
  final String batchNumber;
  final int quantity;
  final Money unitPrice;
  final int discountPercent;
  final Money lineTotal;

  const SaleItem({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.medicineStrength,
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    required this.unitPrice,
    required this.discountPercent,
    required this.lineTotal,
  });
}

/// Sale aggregate root.
class Sale extends Entity<SaleId> {
  final InvoiceNumber invoiceNumber;
  final String customerName;
  final String operatorName;
  final List<SaleItem> items;
  final Money subtotal;
  final Money discount;
  final Money grandTotal;
  final Money amountReceived;
  final Money change;
  final SaleStatus status;
  final DateTime createdAt;

  const Sale({
    required super.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.operatorName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.amountReceived,
    required this.change,
    this.status = SaleStatus.completed,
    required this.createdAt,
  });
}