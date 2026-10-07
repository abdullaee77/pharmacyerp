import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import 'inventory_movement.dart';

/// Abstract contract governing physical stock allocations and log audits.
abstract class InventoryRepository {
  Future<Result<List<InventoryStock>>> getStockLevels({
    String? searchQuery,
    String? statusFilter,
  });

  Future<Result<InventoryStock>> getStockForMedicine(MedicineId medicineId);

  Future<Result<void>> adjustStock({
    required MedicineId medicineId,
    required int quantityChange,
    required AdjustmentReason reason,
    String? reference,
    required String operatorName,
  });

  Future<Result<List<InventoryMovement>>> getMovementsForMedicine(
      MedicineId medicineId,
      );
}