import '../../../core/domain/entity.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';

/// Categories of inventory transactions.
enum MovementType {
  purchase(label: 'Purchase Receipt'),
  sale(label: 'Sale Dispensing'),
  saleReturn(label: 'Sales Return'),
  purchaseReturn(label: 'Purchase Return'),
  adjustment(label: 'Stock Adjustment'),
  expiry(label: 'Expiry Quarantine');

  final String label;
  const MovementType({required this.label});
}

/// Permitted business justifications for manual stock adjustments.
enum AdjustmentReason {
  damaged(label: 'Damaged Stock'),
  expired(label: 'Expired Product'),
  physicalCountCorrection(label: 'Physical Count Correction'),
  lost(label: 'Lost Item'),
  found(label: 'Found Item'),
  manualCorrection(label: 'Manual Correction'),
  other(label: 'Other Reason');

  final String label;
  const AdjustmentReason({required this.label});
}

/// Represents the current physical stock balance for a medicine.
class InventoryStock extends Entity<MedicineId> {
  final Medicine medicine;
  final Quantity currentStock;

  const InventoryStock({
    required super.id,
    required this.medicine,
    required this.currentStock,
  });

  bool get isOutOfStock => currentStock.value == 0;
  bool get isLowStock =>
      currentStock.value > 0 &&
          currentStock.value <= medicine.minStockLevel.value;
  bool get isInStock => currentStock.value > medicine.minStockLevel.value;
}

/// Immutable historical ledger of a stock movement transaction.
class InventoryMovement {
  final String id;
  final MedicineId medicineId;
  final String? batchId;
  final MovementType type;
  final int quantityChanged;
  final AdjustmentReason? reason;
  final String? reference;
  final String operatorName;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.medicineId,
    this.batchId,
    required this.type,
    required this.quantityChanged,
    this.reason,
    this.reference,
    required this.operatorName,
    required this.createdAt,
  });
}