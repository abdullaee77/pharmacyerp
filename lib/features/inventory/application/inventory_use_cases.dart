import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/inventory_movement.dart';
import '../domain/inventory_repository.dart';

/// Fetches stock balance lists with optional search triggers.
class GetStockLevelsUseCase {
  final InventoryRepository _repository;
  const GetStockLevelsUseCase(this._repository);

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

/// Coordinates transactional stock adjustment operations.
class AdjustStockUseCase {
  final InventoryRepository _repository;
  const AdjustStockUseCase(this._repository);

  Future<Result<void>> execute({
    required MedicineId medicineId,
    required int quantityChange,
    required AdjustmentReason reason,
    String? reference,
    required String operatorName,
  }) async {
    if (quantityChange == 0) {
      return const Failure(
        ValidationFailure(message: 'Adjustment quantity cannot be zero.'),
      );
    }

    final currentStockResult = await _repository.getStockForMedicine(
      medicineId,
    );
    if (currentStockResult.isFailure) {
      return Failure(currentStockResult.failureOrNull!);
    }

    final currentVal = currentStockResult.valueOrNull!.currentStock.value;
    if (currentVal + quantityChange < 0) {
      return const Failure(
        ValidationFailure(
          message: 'Adjustment cannot result in negative stock levels.',
        ),
      );
    }

    return _repository.adjustStock(
      medicineId: medicineId,
      quantityChange: quantityChange,
      reason: reason,
      reference: reference,
      operatorName: operatorName,
    );
  }
}

/// Retrieves chronological audit logs for a specific product.
class GetMovementsUseCase {
  final InventoryRepository _repository;
  const GetMovementsUseCase(this._repository);

  Future<Result<List<InventoryMovement>>> execute(MedicineId medicineId) {
    return _repository.getMovementsForMedicine(medicineId);
  }
}
