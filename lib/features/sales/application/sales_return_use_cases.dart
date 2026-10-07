import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../inventory/domain/inventory_repository.dart';
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
  final DatabaseHelper _dbHelper;

  CreateSalesReturnUseCase({
    required SalesRepository salesRepository,
    required InventoryRepository inventoryRepository,
    DatabaseHelper? dbHelper,
  })  : _salesRepository = salesRepository,
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Result<void>> execute({
    required Sale originalSale,
    required SalesReturn returnDoc,
  }) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction<Result<void>>((txn) async {
        // Save the structural returns records
        final retResult = await _salesRepository.createSalesReturn(returnDoc);
        if (retResult is Failure) {
          throw Exception((retResult as Failure).failure.message);
        }

        // If returned items are functional/resellable (not damaged or expired), put them back in physical inventory
        if (returnDoc.reason != SalesReturnReason.damaged && returnDoc.reason != SalesReturnReason.expired) {
          for (final item in returnDoc.items) {
            // Restore batch quantity
            await txn.rawUpdate(
              'UPDATE batches SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
              [item.quantity, DateTime.now().toIso8601String(), item.batchId.value],
            );

            // Restore overall master inventory stock
            await txn.rawUpdate(
              'UPDATE inventory_stocks SET quantity = quantity + ? WHERE medicine_id = ?',
              [item.quantity, item.medicineId.value],
            );

            // Log restock event
            await txn.insert('inventory_movements', {
              'id': 'mov_${DateTime.now().microsecondsSinceEpoch}',
              'medicine_id': item.medicineId.value,
              'batch_id': item.batchId.value,
              'type': 'return',
              'quantity_changed': item.quantity,
              'reason': 'Returned to Stock (Return ID: ${returnDoc.id.value})',
              'reference': returnDoc.id.value,
              'operator_name': returnDoc.operatorName,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        return const Success(null);
      });
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to process sales return: $e'));
    }
  }
}