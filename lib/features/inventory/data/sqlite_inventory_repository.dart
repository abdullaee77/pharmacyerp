import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/data/medicine_model.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/inventory_movement.dart';
import '../domain/inventory_repository.dart';

/// SQLite implementation of [InventoryRepository] with robust transactional writes.
class SqliteInventoryRepository implements InventoryRepository {
  final DatabaseHelper _dbHelper;

  SqliteInventoryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<Result<List<InventoryStock>>> getStockLevels({
    String? searchQuery,
    String? statusFilter,
  }) async {
    try {
      final db = await _db;

      // Single source of truth: total live stock calculated directly from active batches
      String query = '''
        SELECT m.*, IFNULL(b_sum.total_stock, 0) AS current_stock
        FROM medicines m
        LEFT JOIN (
          SELECT medicine_id, SUM(quantity) AS total_stock
          FROM batches
          GROUP BY medicine_id
        ) b_sum ON m.id = b_sum.medicine_id
      ''';

      final List<String> whereClauses = [];
      final List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClauses.add(
          '(m.name LIKE ? OR m.generic_name LIKE ? OR m.barcode LIKE ?)',
        );
        final q = '%$searchQuery%';
        whereArgs.addAll([q, q, q]);
      }

      if (whereClauses.isNotEmpty) {
        query += ' WHERE ${whereClauses.join(' AND ')}';
      }
      query += ' ORDER BY m.name ASC';

      final rows = await db.rawQuery(query, whereArgs);
      final List<InventoryStock> stocks = [];

      for (final row in rows) {
        final medicine = MedicineModel.fromMap(row).toDomain();
        final currentStock = (row['current_stock'] as num).toInt();

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
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to query database stock levels: $e'),
      );
    }
  }

  @override
  Future<Result<InventoryStock>> getStockForMedicine(
      MedicineId medicineId,
      ) async {
    try {
      final db = await _db;
      final medRows = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicineId.value],
      );
      if (medRows.isEmpty) {
        return const Failure(
          NotFoundFailure(message: 'Medicine record not found.'),
        );
      }

      final medicine = MedicineModel.fromMap(medRows.first).toDomain();

      // Dynamically derive current stock from remaining batch quantities
      final batchSumRows = await db.rawQuery(
        'SELECT IFNULL(SUM(quantity), 0) AS total_stock FROM batches WHERE medicine_id = ?',
        [medicineId.value],
      );
      final currentStock = (batchSumRows.first['total_stock'] as num).toInt();

      return Success(
        InventoryStock(
          id: medicineId,
          medicine: medicine,
          currentStock: Quantity.create(currentStock),
        ),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to fetch single stock balance: $e'),
      );
    }
  }

  @override
  Future<Result<void>> adjustStock({
    required MedicineId medicineId,
    required int quantityChange,
    required AdjustmentReason reason,
    String? reference,
    required String operatorName,
    String? batchId,
  }) async {
    try {
      final db = await _db;

      // Wrap in a single transaction so batch and medicine stock NEVER desync
      await db.transaction((txn) async {
        // ── 1. If batch-specific: update batches.quantity first ──────────────
        if (batchId != null && batchId.isNotEmpty) {
          final batchRows = await txn.query(
            'batches',
            where: 'id = ? AND medicine_id = ?',
            whereArgs: [batchId, medicineId.value],
          );
          if (batchRows.isEmpty) {
            throw Exception('Batch not found for this medicine.');
          }

          final batchQty = batchRows.first['quantity'] as int;
          final nextBatchQty = batchQty + quantityChange;

          if (nextBatchQty < 0) {
            throw Exception(
              'Batch stock cannot fall below zero (would be $nextBatchQty).',
            );
          }

          await txn.update(
            'batches',
            {
              'quantity': nextBatchQty,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [batchId],
          );
        } else {
          throw Exception('A specific batch is required for inventory adjustments.');
        }

        // ── 2. Sync medicine-level inventory_stocks to exact batch sum ───────────────
        final sumRows = await txn.rawQuery(
          'SELECT IFNULL(SUM(quantity), 0) AS total_stock FROM batches WHERE medicine_id = ?',
          [medicineId.value],
        );
        final newTotalStock = (sumRows.first['total_stock'] as num).toInt();

        final stockRows = await txn.query(
          'inventory_stocks',
          where: 'medicine_id = ?',
          whereArgs: [medicineId.value],
        );

        if (stockRows.isNotEmpty) {
          await txn.update(
            'inventory_stocks',
            {'quantity': newTotalStock},
            where: 'medicine_id = ?',
            whereArgs: [medicineId.value],
          );
        } else {
          await txn.insert('inventory_stocks', {
            'medicine_id': medicineId.value,
            'quantity': newTotalStock,
          });
        }

        // ── 3. Write immutable movement record ───────────────────────────────
        final movementId =
            'mov_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
        await txn.insert('inventory_movements', {
          'id': movementId,
          'medicine_id': medicineId.value,
          'batch_id': batchId,
          'type': MovementType.adjustment.name,
          'quantity_changed': quantityChange,
          'reason': reason.name,
          'reference': reference,
          'operator_name': operatorName,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Inventory transaction error: $e'),
      );
    }
  }

  @override
  Future<Result<List<InventoryMovement>>> getMovementsForMedicine(
      MedicineId medicineId,
      ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'inventory_movements',
        where: 'medicine_id = ?',
        whereArgs: [medicineId.value],
        orderBy: 'created_at DESC',
      );

      final movements = rows.map((row) {
        return InventoryMovement(
          id: row['id'] as String,
          medicineId: medicineId,
          batchId: row['batch_id'] as String?,
          type: _parseMovementType(row['type'] as String?),
          quantityChanged: (row['quantity_changed'] as num).toInt(),
          reason: _parseAdjustmentReason(row['reason'] as String?),
          reference: row['reference'] as String?,
          operatorName: (row['operator_name'] as String?) ?? 'System',
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();

      return Success(movements);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to retrieve transaction logs: $e'),
      );
    }
  }

  static MovementType _parseMovementType(String? value) {
    if (value == null) return MovementType.adjustment;
    return MovementType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MovementType.adjustment,
    );
  }

  static AdjustmentReason? _parseAdjustmentReason(String? value) {
    if (value == null || value.isEmpty) return null;
    return AdjustmentReason.values.firstWhere(
          (e) => e.name == value,
      orElse: () => AdjustmentReason.manualCorrection,
    );
  }
}