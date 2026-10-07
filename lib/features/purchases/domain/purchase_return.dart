import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import 'purchase.dart';

class PurchaseReturnId extends ValueObject {
  final String value;
  const PurchaseReturnId(this.value);

  factory PurchaseReturnId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return PurchaseReturnId('pret_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PurchaseReturnId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum PurchaseReturnReason {
  damaged(label: 'Damaged / Defective'),
  shortExpiry(label: 'Short Expiry'),
  overStocked(label: 'Overstocked'),
  wrongDelivery(label: 'Wrong Delivery'),
  other(label: 'Other');

  final String label;
  const PurchaseReturnReason({required this.label});
}

class PurchaseReturnItem {
  final String id;
  final String originalPurchaseItemId;
  final MedicineId medicineId;
  final String medicineName;
  final String batchNumber;
  final int quantity;
  final Money refundAmount;

  const PurchaseReturnItem({
    required this.id,
    required this.originalPurchaseItemId,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.quantity,
    required this.refundAmount,
  });
}

class PurchaseReturn extends Entity<PurchaseReturnId> {
  final PurchaseId originalPurchaseId;
  final String originalInvoiceNumber;
  final String supplierName;
  final List<PurchaseReturnItem> items;
  final PurchaseReturnReason reason;
  final String? notes;
  final Money totalRefund;
  final String operatorName;
  final DateTime createdAt;

  const PurchaseReturn({
    required super.id,
    required this.originalPurchaseId,
    required this.originalInvoiceNumber,
    required this.supplierName,
    required this.items,
    required this.reason,
    this.notes,
    required this.totalRefund,
    required this.operatorName,
    required this.createdAt,
  });
}