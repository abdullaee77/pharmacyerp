import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

class PurchaseId extends ValueObject {
  final String value;
  const PurchaseId(this.value);

  factory PurchaseId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return PurchaseId('pur_$ts');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PurchaseId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class PurchaseInvoiceNumber extends ValueObject {
  final String value;
  const PurchaseInvoiceNumber(this.value);

  factory PurchaseInvoiceNumber.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return PurchaseInvoiceNumber('INV-$ts');
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
  returned(label: 'Returned'),
  cancelled(label: 'Cancelled');

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
  final Money purchasePrice; // Trade Price / Unit Cost
  final Money mrp;           // Maximum Retail Price (printed box price)
  final Money sellingPrice;  // Store Selling Price (defaults to MRP)
  final Money lineTotal;     // quantity * purchasePrice

  const PurchaseItem({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.purchasePrice,
    Money? mrp,
    required this.sellingPrice,
    required this.lineTotal,
  }) : mrp = mrp ?? sellingPrice;

  PurchaseItem copyWith({
    String? id,
    MedicineId? medicineId,
    String? medicineName,
    String? batchNumber,
    DateTime? expiryDate,
    int? quantity,
    Money? purchasePrice,
    Money? mrp,
    Money? sellingPrice,
    Money? lineTotal,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
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

  Purchase copyWith({
    PurchaseInvoiceNumber? invoiceNumber,
    String? supplierName,
    List<PurchaseItem>? items,
    Money? subtotal,
    Money? discount,
    Money? grandTotal,
    PurchaseStatus? status,
    DateTime? updatedAt,
  }) {
    return Purchase(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}