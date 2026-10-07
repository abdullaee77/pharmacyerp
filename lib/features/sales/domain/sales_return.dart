import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import 'sale.dart';

class SalesReturnId extends ValueObject {
  final String value;
  const SalesReturnId(this.value);

  factory SalesReturnId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return SalesReturnId('ret_$ts');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SalesReturnId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

enum SalesReturnReason {
  damaged(label: 'Damaged / Defective'),
  expired(label: 'Expired Product'),
  customerRequest(label: 'Customer Request'), // Matches expected dialog constant name
  wrongDispense(label: 'Wrong Dispense'),
  other(label: 'Other');

  final String label;
  const SalesReturnReason({required this.label});
}

class SalesReturnItem {
  final String id;
  final String originalSaleItemId;
  final MedicineId medicineId;
  final String medicineName;
  final BatchId batchId;
  final String batchNumber;
  final int quantity;
  final Money refundAmount;

  const SalesReturnItem({
    required this.id,
    required this.originalSaleItemId,
    required this.medicineId,
    required this.medicineName,
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    required this.refundAmount,
  });
}

class SalesReturn extends Entity<SalesReturnId> {
  final SaleId originalSaleId;
  final String originalInvoiceNumber;
  final SalesReturnReason reason;
  final String? notes;
  final Money totalRefund;
  final String operatorName;
  final DateTime createdAt;
  final List<SalesReturnItem> items;

  const SalesReturn({
    required super.id,
    required this.originalSaleId,
    required this.originalInvoiceNumber,
    required this.reason,
    this.notes,
    required this.totalRefund,
    required this.operatorName,
    required this.createdAt,
    required this.items,
  });
}