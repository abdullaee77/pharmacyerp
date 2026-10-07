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

      // Select medicines joined with physical balances
      String query = '''
        SELECT m.*, IFNULL(s.quantity, 0) AS current_stock
        FROM medicines m
        LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
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
        final currentStock = row['current_stock'] as int;

        final stock = InventoryStock(
          id: medicine.id,
          medicine: medicine,
          currentStock: Quantity.create(currentStock),
        );

        // Apply visual status filtering at repository level
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
      final stockRows = await db.query(
        'inventory_stocks',
        where: 'medicine_id = ?',
        whereArgs: [medicineId.value],
      );
      final currentStock = stockRows.isEmpty
          ? 0
          : stockRows.first['quantity'] as int;

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
  }) async {
    try {
      final db = await _db;

      // Wrap in SQLite transaction blocks to prevent inconsistent state on hardware lockups
      await db.transaction((txn) async {
        // 1. Fetch current stock
        final stockRows = await txn.query(
          'inventory_stocks',
          where: 'medicine_id = ?',
          whereArgs: [medicineId.value],
        );

        int currentQty = 0;
        bool exists = false;

        if (stockRows.isNotEmpty) {
          currentQty = stockRows.first['quantity'] as int;
          exists = true;
        }

        final nextQty = currentQty + quantityChange;
        if (nextQty < 0) {
          throw Exception('Stock cannot fall below zero');
        }

        // 2. Perform write/upsert updates
        if (exists) {
          await txn.update(
            'inventory_stocks',
            {'quantity': nextQty},
            where: 'medicine_id = ?',
            whereArgs: [medicineId.value],
          );
        } else {
          await txn.insert('inventory_stocks', {
            'medicine_id': medicineId.value,
            'quantity': nextQty,
          });
        }

        // 3. Write immutable movement record
        final movementId =
            'mov_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
        await txn.insert('inventory_movements', {
          'id': movementId,
          'medicine_id': medicineId.value,
          'batch_id': null,
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
        orderBy: 'created_at DESC',
      );

      final movements = rows.map((row) {
        return InventoryMovement(
          id: row['id'] as String,
          medicineId: medicineId,
          batchId: row['batch_id'] as String?,
          type: MovementType.values.firstWhere((e) => e.name == row['type']),
          quantityChanged: row['quantity_changed'] as int,
          reason: row['reason'] != null
              ? AdjustmentReason.values.firstWhere(
                  (e) => e.name == row['reason'],
                )
              : null,
          reference: row['reference'] as String?,
          operatorName: row['operator_name'] as String,
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
}
