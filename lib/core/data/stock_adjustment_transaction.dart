import 'package:sqflite/sqflite.dart';

class AdjustmentException implements Exception {
  final String message;
  const AdjustmentException(this.message);

  @override
  String toString() => message;
}

class StockAdjustmentTransaction {
  StockAdjustmentTransaction._();

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final String medicineId = payload['medicineId'] as String? ?? '';
    final int qtyChange = payload['quantityChange'] as int? ?? 0;
    final String reasonStr = payload['reason'] as String? ?? 'correction';
    final String? reference = payload['reference'] as String?;
    final String operatorName = (payload['operatorName'] as String? ?? 'System').trim();
    final String? batchId = payload['batchId'] as String?;

    if (medicineId.isEmpty) {
      throw const AdjustmentException('Adjustment error: medicine ID cannot be blank.');
    }
    if (qtyChange == 0) return; // redundant

    await db.transaction((txn) async {
      final nowIso = DateTime.now().toIso8601String();

      // If adjustment targets a specific batch
      if (batchId != null && batchId.isNotEmpty) {
        final bRows = await txn.rawQuery(
          'SELECT quantity, batch_number FROM batches WHERE id = ?',
          [batchId],
        );
        if (bRows.isEmpty) {
          throw const AdjustmentException('Adjustment error: designated Batch record not found.');
        }

        final currentBatchQty = bRows.first['quantity'] as int;
        if (currentBatchQty + qtyChange < 0) {
          throw AdjustmentException(
              'Adjustment denied: Batch ${bRows.first['batch_number']} cannot drop below 0 stock (Available: $currentBatchQty).'
          );
        }

        // Perform safe update
        final updated = await txn.rawUpdate(
          'UPDATE batches SET quantity = quantity + ?, updated_at = ? WHERE id = ? AND quantity + ? >= 0',
          [qtyChange, nowIso, batchId, qtyChange],
        );
        if (updated == 0) {
          throw const AdjustmentException('Adjustment failed due to concurrency or stock bounds.');
        }
      }

      // Check generic stock balance
      final stockRows = await txn.rawQuery(
        'SELECT quantity FROM inventory_stocks WHERE medicine_id = ?',
        [medicineId],
      );

      final currentStock = stockRows.isEmpty ? 0 : stockRows.first['quantity'] as int;
      if (currentStock + qtyChange < 0) {
        throw AdjustmentException(
            'Adjustment denied: Stock levels cannot fall below zero (Available: $currentStock, Request: $qtyChange).'
        );
      }

      // Write to inventory stocks
      if (stockRows.isNotEmpty) {
        await txn.rawUpdate(
          'UPDATE inventory_stocks SET quantity = quantity + ? WHERE medicine_id = ?',
          [qtyChange, medicineId],
        );
      } else {
        await txn.insert('inventory_stocks', {
          'medicine_id': medicineId,
          'quantity': qtyChange,
        });
      }

      // Create log movement
      await txn.insert('inventory_movements', {
        'id': 'mov_adj_${DateTime.now().microsecondsSinceEpoch}_$medicineId',
        'medicine_id': medicineId,
        'batch_id': batchId,
        'type': 'adjustment',
        'quantity_changed': qtyChange,
        'reason': reasonStr,
        'reference': reference,
        'operator_name': operatorName,
        'created_at': nowIso,
      });
    });
  }
}