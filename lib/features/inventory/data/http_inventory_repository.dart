import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/data/medicine_model.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/inventory_movement.dart';
import '../domain/inventory_repository.dart';

class HttpInventoryRepository implements InventoryRepository {
  final ApiClient _api;

  HttpInventoryRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<Result<List<InventoryStock>>> getStockLevels({
    String? searchQuery,
    String? statusFilter,
  }) async {
    try {
      final where = <String>[];
      final args = <dynamic>[];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where.add('(m.name LIKE ? OR m.generic_name LIKE ? OR m.barcode LIKE ?)');
        final q = '%$searchQuery%';
        args.addAll([q, q, q]);
      }

      final sql = '''
        SELECT m.*, IFNULL(s.quantity, 0) AS current_stock
        FROM medicines m
        LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
        ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
        ORDER BY m.name ASC
      ''';

      final res = await _api.rawQuery(sql: sql, args: args.isEmpty ? null : args);
      return res.fold(
        onSuccess: (rows) {
          final stocks = <InventoryStock>[];
          for (final row in rows) {
            final medicine = MedicineModel.fromMap(row).toDomain();
            final currentStock = (row['current_stock'] as num?)?.toInt() ?? 0;
            final stock = InventoryStock(
              id: medicine.id,
              medicine: medicine,
              currentStock: Quantity.create(currentStock),
            );

            if (statusFilter != null) {
              if (statusFilter == 'out' && !stock.isOutOfStock) continue;
              if (statusFilter == 'low' && !stock.isLowStock) continue;
              if (statusFilter == 'in' && !stock.isInStock) continue;
            }
            stocks.add(stock);
          }
          return Success(stocks);
        },
        onFailure: (f) => Failure(f),
      );
    } catch (e) {
      return Failure(ServerFailure(message: 'Failed to load stock levels: $e'));
    }
  }

  @override
  Future<Result<InventoryStock>> getStockForMedicine(MedicineId medicineId) async {
    final medRes = await _api.query(
      table: 'medicines',
      where: 'id = ?',
      args: [medicineId.value],
      limit: 1,
    );

    if (medRes.isFailure) return Failure(medRes.failureOrNull!);
    final medRows = medRes.valueOrNull ?? [];
    if (medRows.isEmpty) {
      return const Failure(NotFoundFailure(message: 'Medicine record not found.'));
    }

    final medicine = MedicineModel.fromMap(medRows.first).toDomain();

    final stockRes = await _api.query(
      table: 'inventory_stocks',
      where: 'medicine_id = ?',
      args: [medicineId.value],
      limit: 1,
    );

    final currentStock = stockRes.fold(
      onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['quantity'] as int? ?? 0),
      onFailure: (_) => 0,
    );

    return Success(InventoryStock(
      id: medicineId,
      medicine: medicine,
      currentStock: Quantity.create(currentStock),
    ));
  }

  // ─── ATOMIC STOCK ADJUSTMENT ─────────────────────────────────

  @override
  Future<Result<void>> adjustStock({
    required MedicineId medicineId,
    required int quantityChange,
    required AdjustmentReason reason,
    String? reference,
    required String operatorName,
  }) async {
    // Single atomic call to the server — stock check, update, and movement
    // log all happen inside one SQLite transaction on the server side.
    final payload = {
      'medicineId': medicineId.value,
      'quantityChange': quantityChange,
      'reason': reason.name,
      'reference': reference,
      'operatorName': operatorName,
      'batchId': null,
    };

    final res = await _api.adjustStock(payload);
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<InventoryMovement>>> getMovementsForMedicine(
      MedicineId medicineId,
      ) async {
    final res = await _api.query(
      table: 'inventory_movements',
      where: 'medicine_id = ?',
      args: [medicineId.value],
      orderBy: 'created_at DESC',
    );

    return res.fold(
      onSuccess: (rows) {
        final movements = rows.map((row) {
          return InventoryMovement(
            id: row['id'] as String,
            medicineId: medicineId,
            batchId: row['batch_id'] as String?,
            type: MovementType.values.firstWhere(
                  (e) => e.name == row['type'],
              orElse: () => MovementType.adjustment,
            ),
            quantityChanged: row['quantity_changed'] as int? ?? 0,
            reason: row['reason'] != null
                ? AdjustmentReason.values.firstWhere(
                  (e) => e.name == row['reason'],
              orElse: () => AdjustmentReason.other,
            )
                : null,
            reference: row['reference'] as String?,
            operatorName: row['operator_name'] as String? ?? '',
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        }).toList();
        return Success(movements);
      },
      onFailure: (f) => Failure(f),
    );
  }
}