import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';
import '../domain/purchase_return.dart';

class ReceivePurchaseUseCase {
  final PurchaseRepository _purchaseRepository;

  const ReceivePurchaseUseCase({
    required PurchaseRepository purchaseRepository,
    dynamic inventoryRepository,
    dynamic batchRepository,
    dynamic supplierRepository,
  }) : _purchaseRepository = purchaseRepository;

  Future<Result<Purchase>> execute(
      Purchase purchase, {
        String? accountId,
        int amountPaidPaisa = 0,
      }) async {
    if (purchase.items.isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Purchase items list cannot be empty.'),
      );
    }

    // Auto-create supplier REMOVED strictly matching user instructions.
    // Supplier MUST be selected from the existing database entries.

    final saveResult = await _purchaseRepository.createPurchase(
      purchase,
      accountId: accountId,
      amountPaidPaisa: amountPaidPaisa,
    );

    if (saveResult.isFailure) return saveResult;
    return Success(purchase);
  }
}

class CreatePurchaseReturnUseCase {
  final PurchaseRepository _purchaseRepository;

  const CreatePurchaseReturnUseCase({
    required PurchaseRepository purchaseRepository,
    dynamic inventoryRepository,
  }) : _purchaseRepository = purchaseRepository;

  Future<Result<PurchaseReturn>> execute({
    required Purchase originalPurchase,
    required PurchaseReturn returnDoc,
  }) async {
    if (returnDoc.items.isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Return must have at least one item.'),
      );
    }

    final returnedSoFarResult = await _purchaseRepository.getReturnedQuantities(
      originalPurchase.id,
    );
    if (returnedSoFarResult.isFailure) {
      return Failure(returnedSoFarResult.failureOrNull!);
    }
    final returnedSoFar = returnedSoFarResult.valueOrNull!;

    for (final item in returnDoc.items) {
      final originalItem = originalPurchase.items.firstWhere(
            (pi) => pi.id == item.originalPurchaseItemId,
      );
      final alreadyReturned = returnedSoFar[item.originalPurchaseItemId] ?? 0;
      final maxReturnable = originalItem.quantity - alreadyReturned;

      if (item.quantity > maxReturnable) {
        return Failure(
          ValidationFailure(
            message:
            '${item.medicineName} cannot return ${item.quantity} units (max returnable: $maxReturnable).',
          ),
        );
      }
    }

    final saveResult = await _purchaseRepository.createPurchaseReturn(returnDoc);
    if (saveResult.isFailure) return saveResult;

    return Success(returnDoc);
  }
}

class GetPurchasesUseCase {
  final PurchaseRepository _repository;
  const GetPurchasesUseCase(this._repository);

  Future<Result<List<Purchase>>> execute({String? searchQuery}) {
    return _repository.getPurchases(searchQuery: searchQuery);
  }
}