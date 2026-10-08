import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import '../domain/sales_return.dart';

class GetSalesHistoryUseCase {
  final SalesRepository _repository;
  const GetSalesHistoryUseCase(this._repository);

  Future<Result<List<Sale>>> execute({String? searchQuery}) {
    return _repository.getSales(searchQuery: searchQuery);
  }
}

class CreateSalesReturnUseCase {
  final SalesRepository _salesRepository;

  CreateSalesReturnUseCase({
    required SalesRepository salesRepository,
    // InventoryRepository kept in signature to avoid breaking callers
    dynamic inventoryRepository,
    dynamic dbHelper,
  }) : _salesRepository = salesRepository;

  Future<Result<void>> execute({
    required Sale originalSale,
    required SalesReturn returnDoc,
  }) async {
    if (returnDoc.items.isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Return must contain at least one item.'),
      );
    }

    // The repository now handles return records + stock restoration +
    // sale status update in ONE atomic transaction.
    final result = await _salesRepository.createSalesReturn(returnDoc);
    return result.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }
}