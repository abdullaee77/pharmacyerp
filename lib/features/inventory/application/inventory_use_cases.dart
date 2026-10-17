import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/inventory_movement.dart';
import '../domain/inventory_repository.dart';

class GetStockLevelsUseCase {
  final InventoryRepository _repository;
  GetStockLevelsUseCase(this._repository);

  Future<Result<List<InventoryStock>>> execute({
    String? searchQuery,
    String? statusFilter,
  }) {
    return _repository.getStockLevels(
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
  }
}

class AdjustStockUseCase {
  final InventoryRepository _repository;
  AdjustStockUseCase(this._repository);

  Future<Result<void>> execute({
    required MedicineId medicineId,
    required int quantityChange,
    required AdjustmentReason reason,
    String? reference,
    required String operatorName,
    String? batchId, // ← Added
  }) {
    return _repository.adjustStock(
      medicineId: medicineId,
      quantityChange: quantityChange,
      reason: reason,
      reference: reference,
      operatorName: operatorName,
      batchId: batchId, // ← Passed to repo
    );
  }
}

class GetMovementsUseCase {
  final InventoryRepository _repository;
  GetMovementsUseCase(this._repository);

  Future<Result<List<InventoryMovement>>> execute(MedicineId medicineId) {
    return _repository.getMovementsForMedicine(medicineId);
  }
}