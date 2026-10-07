import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/cart_item.dart';
import '../domain/pos_models.dart';
import '../domain/pos_repository.dart';

class SearchMedicinesForPosUseCase {
  final PosRepository _repository;
  const SearchMedicinesForPosUseCase(this._repository);

  Future<Result<List<PosSearchResult>>> execute(String query) {
    return _repository.searchMedicines(query.trim());
  }
}

class ResolveBarcodeUseCase {
  final PosRepository _repository;
  const ResolveBarcodeUseCase(this._repository);

  Future<Result<PosSearchResult>> execute(String barcode) async {
    if (barcode.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Barcode is empty.'));
    }
    return _repository.findByBarcode(barcode.trim());
  }
}

class GetAvailableBatchesUseCase {
  final PosRepository _repository;
  const GetAvailableBatchesUseCase(this._repository);

  Future<Result<List<Batch>>> execute(MedicineId medicineId) {
    return _repository.getAvailableBatches(medicineId);
  }
}

class ValidateCartLineUseCase {
  const ValidateCartLineUseCase();

  Result<void> execute({
    required Batch batch,
    required int requestedQuantity,
  }) {
    if (requestedQuantity <= 0) {
      return const Failure(
        ValidationFailure(message: 'Quantity must be greater than zero.'),
      );
    }
    if (batch.status == BatchStatus.expired) {
      return const Failure(
        ValidationFailure(message: 'Cannot sell from an expired batch.'),
      );
    }
    if (requestedQuantity > batch.quantity.value) {
      return Failure(
        ValidationFailure(
          message: 'Only ${batch.quantity.value} units available in this batch.',
        ),
      );
    }
    return const Success(null);
  }
}