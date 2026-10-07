import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../inventory/domain/batch.dart';
import '../../inventory/domain/batch_repository.dart';
import '../../inventory/domain/inventory_movement.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../medicines/domain/value_objects.dart';
import '../../suppliers/application/supplier_use_cases.dart';
import '../../suppliers/domain/supplier_repository.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';
import '../domain/purchase_return.dart';

class ReceivePurchaseUseCase {
  final PurchaseRepository _purchaseRepository;
  final InventoryRepository _inventoryRepository;
  final BatchRepository _batchRepository;
  final SupplierRepository? _supplierRepository;

  const ReceivePurchaseUseCase({
    required PurchaseRepository purchaseRepository,
    required InventoryRepository inventoryRepository,
    required BatchRepository batchRepository,
    SupplierRepository? supplierRepository,
  }) : _purchaseRepository = purchaseRepository,
       _inventoryRepository = inventoryRepository,
       _batchRepository = batchRepository,
       _supplierRepository = supplierRepository;

  Future<Result<Purchase>> execute(Purchase purchase) async {
    if (purchase.items.isEmpty) {
      return const Failure(
        ValidationFailure(message: 'Purchase items list cannot be empty.'),
      );
    }

    final saveResult = await _purchaseRepository.createPurchase(purchase);
    if (saveResult.isFailure) return saveResult;

    for (final item in purchase.items) {
      final batchId = BatchId.generate();

      final batchResult = await _batchRepository.createBatch(
        Batch(
          id: batchId,
          medicineId: item.medicineId,
          medicineName: item.medicineName,
          batchNumber: BatchNumber.unsafe(item.batchNumber),
          expiryDate: ExpiryDate(item.expiryDate),
          quantity: Quantity.create(item.quantity),
          purchasePrice: item.purchasePrice,
          sellingPrice: item.sellingPrice,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (batchResult.isFailure) return Failure(batchResult.failureOrNull!);

      final stockResult = await _inventoryRepository.adjustStock(
        medicineId: item.medicineId,
        quantityChange: item.quantity,
        reason: AdjustmentReason.physicalCountCorrection,
        reference: 'Purchase Recv ${purchase.invoiceNumber.value}',
        operatorName: 'System Proc',
      );
      if (stockResult.isFailure) return Failure(stockResult.failureOrNull!);
    }

    // Post the purchase total to the supplier's ledger if supplier exists.
    if (_supplierRepository != null) {
      final useCase = PostPurchaseToSupplierUseCase(_supplierRepository!);
      await useCase.execute(
        supplierName: purchase.supplierName,
        invoiceNumber: purchase.invoiceNumber.value,
        amount: purchase.grandTotal,
        operatorName: 'System Proc',
      );
    }

    return Success(purchase);
  }
}

class CreatePurchaseReturnUseCase {
  final PurchaseRepository _purchaseRepository;
  final InventoryRepository _inventoryRepository;

  const CreatePurchaseReturnUseCase({
    required PurchaseRepository purchaseRepository,
    required InventoryRepository inventoryRepository,
  }) : _purchaseRepository = purchaseRepository,
       _inventoryRepository = inventoryRepository;

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

      final currentStockResult = await _inventoryRepository.getStockForMedicine(
        item.medicineId,
      );
      if (currentStockResult.isFailure) {
        return Failure(currentStockResult.failureOrNull!);
      }
      final currentStock = currentStockResult.valueOrNull!.currentStock.value;

      if (currentStock < item.quantity) {
        return Failure(
          ValidationFailure(
            message:
                'Insufficient stock in inventory for ${item.medicineName} (Available: $currentStock, Returning: ${item.quantity}).',
          ),
        );
      }
    }

    final saveResult = await _purchaseRepository.createPurchaseReturn(
      returnDoc,
    );
    if (saveResult.isFailure) return saveResult;

    for (final item in returnDoc.items) {
      final adjResult = await _inventoryRepository.adjustStock(
        medicineId: item.medicineId,
        quantityChange: -item.quantity,
        reason: AdjustmentReason.damaged,
        reference: 'Purchase Return against ${returnDoc.originalInvoiceNumber}',
        operatorName: returnDoc.operatorName,
      );
      if (adjResult.isFailure) return Failure(adjResult.failureOrNull!);
    }

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
