import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import 'batch.dart';

/// Abstract contract for batch-level inventory operations.
abstract class BatchRepository {
  /// Fetch all batches, optionally filtered by medicine or status.
  Future<Result<List<Batch>>> getBatches({
    MedicineId? medicineId,
    BatchStatus? status,
    String? searchQuery,
  });

  /// Fetch a single batch by ID.
  Future<Result<Batch>> getBatchById(BatchId id);

  /// Create a new batch record.
  Future<Result<Batch>> createBatch(Batch batch);

  /// Update an existing batch (quantity, pricing, expiry).
  Future<Result<Batch>> updateBatch(Batch batch);

  /// Delete a batch record.
  Future<Result<void>> deleteBatch(BatchId id);

  /// Get batches expiring within the given threshold (FEFO-compatible).
  Future<Result<List<Batch>>> getExpiringBatches({int daysThreshold = 90});

  /// Get all batches for a medicine sorted by expiry (FEFO order).
  Future<Result<List<Batch>>> getBatchesByExpiry(MedicineId medicineId);
}