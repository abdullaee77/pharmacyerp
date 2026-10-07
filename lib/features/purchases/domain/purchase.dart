import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

class PurchaseId extends ValueObject {
  final String value;
  const PurchaseId(this.value);

  factory PurchaseId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return PurchaseId('pur_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PurchaseId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class PurchaseInvoiceNumber extends ValueObject {
  final String value;
  const PurchaseInvoiceNumber(this.value);

  factory PurchaseInvoiceNumber.generate() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    return PurchaseInvoiceNumber('PUR-$y$m$d-$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PurchaseInvoiceNumber &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum PurchaseStatus {
  completed(label: 'Completed'),
  partiallyReturned(label: 'Partially Returned'),
  returned(label: 'Returned');

  final String label;
  const PurchaseStatus({required this.label});
}

class PurchaseItem {
  final String id;
  final MedicineId medicineId;
  final String medicineName;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;
  final Money purchasePrice;
  final Money sellingPrice;
  final Money lineTotal;

  const PurchaseItem({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.lineTotal,
  });
}

class Purchase extends Entity<PurchaseId> {
  final PurchaseInvoiceNumber invoiceNumber;
  final String supplierName;
  final List<PurchaseItem> items;
  final Money subtotal;
  final Money discount;
  final Money grandTotal;
  final PurchaseStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Purchase({
    required super.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    this.status = PurchaseStatus.completed,
    required this.createdAt,
    required this.updatedAt,
  });
}