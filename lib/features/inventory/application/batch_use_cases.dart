import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/batch.dart';
import '../domain/batch_repository.dart';

/// Creates a new batch with domain validation.
class CreateBatchUseCase {
  final BatchRepository _repository;
  const CreateBatchUseCase(this._repository);

  Future<Result<Batch>> execute(Batch batch) async {
    if (batch.batchNumber.value.isEmpty) {
      return const Failure(ValidationFailure(message: 'Batch number is required.'));
    }
    if (batch.quantity.value < 0) {
      return const Failure(ValidationFailure(message: 'Batch quantity cannot be negative.'));
    }
    if (batch.purchasePrice.paisa < 0) {
      return const Failure(ValidationFailure(message: 'Purchase price cannot be negative.'));
    }
    if (batch.sellingPrice.paisa < 0) {
      return const Failure(ValidationFailure(message: 'Selling price cannot be negative.'));
    }
    return _repository.createBatch(batch);
  }
}

/// Updates an existing batch.
class UpdateBatchUseCase {
  final BatchRepository _repository;
  const UpdateBatchUseCase(this._repository);

  Future<Result<Batch>> execute(Batch batch) async {
    if (batch.quantity.value < 0) {
      return const Failure(ValidationFailure(message: 'Batch quantity cannot be negative.'));
    }
    return _repository.updateBatch(batch);
  }
}

/// Retrieves batches with optional filtering.
class GetBatchesUseCase {
  final BatchRepository _repository;
  const GetBatchesUseCase(this._repository);

  Future<Result<List<Batch>>> execute({
    MedicineId? medicineId,
    BatchStatus? status,
    String? searchQuery,
  }) {
    return _repository.getBatches(
      medicineId: medicineId,
      status: status,
      searchQuery: searchQuery,
    );
  }
}

/// Deletes a batch.
class DeleteBatchUseCase {
  final BatchRepository _repository;
  const DeleteBatchUseCase(this._repository);

  Future<Result<void>> execute(BatchId id) => _repository.deleteBatch(id);
}

/// Retrieves batches in FEFO order (earliest expiry first).
class GetBatchesByExpiryUseCase {
  final BatchRepository _repository;
  const GetBatchesByExpiryUseCase(this._repository);

  Future<Result<List<Batch>>> execute(MedicineId medicineId) {
    return _repository.getBatchesByExpiry(medicineId);
  }
}