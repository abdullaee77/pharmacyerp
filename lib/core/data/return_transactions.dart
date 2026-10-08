import 'package:sqflite/sqflite.dart';

class ReturnException implements Exception {
  final String message;
  const ReturnException(this.message);

  @override
  String toString() => message;
}

class SalesReturnTransaction {
  SalesReturnTransaction._();

  static const List<String> _returnColumns = [
    'id', 'original_sale_id', 'original_invoice_number', 'reason', 'notes',
    'total_refund', 'operator_name', 'created_at'
  ];

  static const List<String> _itemColumns = [
    'id', 'return_id', 'original_sale_item_id', 'medicine_id', 'medicine_name',
    'batch_id', 'batch_number', 'quantity', 'refund_amount'
  ];

  static Map<String, dynamic> _pick(Map<String, dynamic> src, List<String> cols) {
    return {for (final c in cols) if (src.containsKey(c)) c: src[c]};
  }

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final returnIn = payload['return'];
    final itemsIn = payload['items'];
    if (returnIn is! Map || itemsIn is! List || itemsIn.isEmpty) {
      throw const ReturnException('Invalid sales return data.');
    }

    final returnDoc = _pick(Map<String, dynamic>.from(returnIn), _returnColumns);
    final returnId = returnDoc['id'] as String? ?? '';
    final originalSaleId = returnDoc['original_sale_id'] as String? ?? '';
    final invoice = returnDoc['original_invoice_number'] as String? ?? '';
    final operatorName = (returnDoc['operator_name'] as String? ?? 'System').trim();
    final refundAmount = returnDoc['total_refund'] as int? ?? 0;
    final accountId = payload['accountId'] as String?;

    // When false (damaged / expired), stock is NOT restored to inventory.
    final restockItems = payload['restockItems'] as bool? ?? true;

    if (returnId.isEmpty || originalSaleId.isEmpty) {
      throw const ReturnException('Return document is missing identifier paths.');
    }

    final items = <Map<String, dynamic>>[];
    for (final raw in itemsIn) {
      final row = _pick(Map<String, dynamic>.from(raw as Map), _itemColumns);
      row['return_id'] = returnId;
      items.add(row);
    }

    await db.transaction((txn) async {
      // Idempotency guard
      final existing = await txn.rawQuery(
        'SELECT 1 FROM sales_returns WHERE id = ? LIMIT 1',
        [returnId],
      );
      if (existing.isNotEmpty) return;

      // 1. Insert return header + items
      await txn.insert('sales_returns', returnDoc);
      for (final item in items) {
        await txn.insert('sales_return_items', item);
      }

      final nowIso = DateTime.now().toIso8601String();

      // 2. Restore stock only when items are resellable
      if (restockItems) {
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final medId = item['medicine_id'] as String;
          final batchId = item['batch_id'] as String;
          final qty = item['quantity'] as int;

          await txn.rawUpdate(
            'UPDATE batches SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
            [qty, nowIso, batchId],
          );

          await txn.rawUpdate(
            'UPDATE inventory_stocks SET quantity = quantity + ? WHERE medicine_id = ?',
            [qty, medId],
          );

          await txn.insert('inventory_movements', {
            'id': 'mov_sret_${returnId}_${i}_$medId',
            'medicine_id': medId,
            'batch_id': batchId,
            'type': 'sale_return',
            'quantity_changed': qty,
            'reason': 'Sales Return against invoice: $invoice',
            'reference': invoice,
            'operator_name': operatorName,
            'created_at': nowIso,
          });
        }
      }

      // 3. Mark original sale as partially returned
      await txn.rawUpdate(
        "UPDATE sales SET status = 'partially_returned' WHERE id = ?",
        [originalSaleId],
      );

      // 4. Financial impact
      if (accountId != null && accountId.isNotEmpty) {
        await txn.insert('financial_transactions', {
          'id': 'ft_sret_$returnId',
          'account_id': accountId,
          'source': 'sales_return',
          'description': 'Refund for Sales Return of Invoice $invoice',
          'reference': returnId,
          'debit': 0,
          'credit': refundAmount,
          'operator_name': operatorName,
          'created_at': nowIso,
        });
      } else {
        // Fallback: credit customer ledger if named customer
        final saleRows = await txn.rawQuery(
          'SELECT customer_name FROM sales WHERE id = ? LIMIT 1',
          [originalSaleId],
        );
        if (saleRows.isNotEmpty) {
          final customerName = saleRows.first['customer_name'] as String;
          final cusRows = await txn.rawQuery(
            'SELECT id FROM customers WHERE LOWER(name) = LOWER(?) LIMIT 1',
            [customerName],
          );
          if (cusRows.isNotEmpty) {
            final customerId = cusRows.first['id'] as String;
            await txn.insert('customer_ledger_entries', {
              'id': 'c_ledg_sret_$returnId',
              'customer_id': customerId,
              'entry_type': 'sale_return_credit',
              'description': 'Balance adjustment for Sales Return of Invoice $invoice',
              'reference': returnId,
              'debit': 0,
              'credit': refundAmount,
              'payment_method': 'credit',
              'operator_name': operatorName,
              'created_at': nowIso,
            });
          }
        }
      }
    });
  }
}

class PurchaseReturnTransaction {
  PurchaseReturnTransaction._();

  static const List<String> _returnColumns = [
    'id', 'original_purchase_id', 'original_invoice_number', 'supplier_name',
    'reason', 'notes', 'total_refund', 'operator_name', 'created_at'
  ];

  static const List<String> _itemColumns = [
    'id', 'return_id', 'original_purchase_item_id', 'medicine_id', 'medicine_name',
    'batch_number', 'quantity', 'refund_amount'
  ];

  static Map<String, dynamic> _pick(Map<String, dynamic> src, List<String> cols) {
    return {for (final c in cols) if (src.containsKey(c)) c: src[c]};
  }

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final returnIn = payload['return'];
    final itemsIn = payload['items'];
    if (returnIn is! Map || itemsIn is! List || itemsIn.isEmpty) {
      throw const ReturnException('Invalid purchase return data.');
    }

    final returnDoc = _pick(Map<String, dynamic>.from(returnIn), _returnColumns);
    final returnId = returnDoc['id'] as String? ?? '';
    final originalPurchaseId = returnDoc['original_purchase_id'] as String? ?? '';
    final invoice = returnDoc['original_invoice_number'] as String? ?? '';
    final supplierName = (returnDoc['supplier_name'] as String? ?? '').trim();
    final operatorName = (returnDoc['operator_name'] as String? ?? 'System').trim();
    final refundAmount = returnDoc['total_refund'] as int? ?? 0;
    final accountId = payload['accountId'] as String?;

    if (returnId.isEmpty || originalPurchaseId.isEmpty) {
      throw const ReturnException('Return document is missing identifier paths.');
    }

    final items = <Map<String, dynamic>>[];
    for (final raw in itemsIn) {
      final row = _pick(Map<String, dynamic>.from(raw as Map), _itemColumns);
      row['return_id'] = returnId;
      items.add(row);
    }

    await db.transaction((txn) async {
      final existing = await txn.rawQuery(
        'SELECT 1 FROM purchase_returns WHERE id = ? LIMIT 1',
        [returnId],
      );
      if (existing.isNotEmpty) return;

      // 1. Validate stock levels before deducting
      for (final item in items) {
        final medId = item['medicine_id'] as String;
        final batchNum = item['batch_number'] as String;
        final qty = item['quantity'] as int;

        final batchRows = await txn.rawQuery(
          'SELECT id, quantity FROM batches WHERE medicine_id = ? AND batch_number = ?',
          [medId, batchNum],
        );
        if (batchRows.isEmpty) {
          throw ReturnException('Batch $batchNum was not found for return.');
        }
        final available = batchRows.first['quantity'] as int;
        if (available < qty) {
          throw ReturnException(
              'Insufficient batch stock for ${item['medicine_name']}. Available: $available, Returning: $qty'
          );
        }

        final stockRows = await txn.rawQuery(
          'SELECT quantity FROM inventory_stocks WHERE medicine_id = ?',
          [medId],
        );
        final genericQty = stockRows.isEmpty ? 0 : stockRows.first['quantity'] as int;
        if (genericQty < qty) {
          throw ReturnException(
              'Insufficient generic stock for ${item['medicine_name']}. Available: $genericQty, Returning: $qty'
          );
        }
      }

      // 2. Insert return records
      await txn.insert('purchase_returns', returnDoc);
      for (final item in items) {
        await txn.insert('purchase_return_items', item);
      }

      final nowIso = DateTime.now().toIso8601String();

      // 3. Deduct stock and log movements
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final medId = item['medicine_id'] as String;
        final batchNum = item['batch_number'] as String;
        final qty = item['quantity'] as int;

        final batchIdRows = await txn.rawQuery(
          'SELECT id FROM batches WHERE medicine_id = ? AND batch_number = ? LIMIT 1',
          [medId, batchNum],
        );
        final batchId = batchIdRows.first['id'] as String;

        final updatedBatches = await txn.rawUpdate(
          'UPDATE batches SET quantity = quantity - ?, updated_at = ? WHERE id = ? AND quantity >= ?',
          [qty, nowIso, batchId, qty],
        );
        if (updatedBatches == 0) {
          throw ReturnException('Insufficient batch stock for ${item['medicine_name']}.');
        }

        await txn.rawUpdate(
          'UPDATE inventory_stocks SET quantity = quantity - ? WHERE medicine_id = ?',
          [qty, medId],
        );

        await txn.insert('inventory_movements', {
          'id': 'mov_pret_${returnId}_${i}_$medId',
          'medicine_id': medId,
          'batch_id': batchId,
          'type': 'purchase_return',
          'quantity_changed': -qty,
          'reason': 'Purchase Return against: $invoice',
          'reference': invoice,
          'operator_name': operatorName,
          'created_at': nowIso,
        });
      }

      // 4. Update purchase header
      await txn.rawUpdate(
        "UPDATE purchases SET status = 'partially_returned' WHERE id = ?",
        [originalPurchaseId],
      );

      // 5. Financial entries
      if (accountId != null && accountId.isNotEmpty) {
        await txn.insert('financial_transactions', {
          'id': 'ft_pret_$returnId',
          'account_id': accountId,
          'source': 'purchase_return',
          'description': 'Refund received for Purchase Return against $invoice',
          'reference': returnId,
          'debit': refundAmount,
          'credit': 0,
          'operator_name': operatorName,
          'created_at': nowIso,
        });
      } else if (supplierName.isNotEmpty) {
        final supRows = await txn.rawQuery(
          'SELECT id FROM suppliers WHERE LOWER(name) = LOWER(?) LIMIT 1',
          [supplierName],
        );
        if (supRows.isNotEmpty) {
          final supplierId = supRows.first['id'] as String;
          await txn.insert('supplier_ledger_entries', {
            'id': 's_ledg_pret_$returnId',
            'supplier_id': supplierId,
            'entry_type': 'purchase_return_debit',
            'description': 'Debit adjustment for Purchase Return against invoice $invoice',
            'reference': returnId,
            'debit': refundAmount,
            'credit': 0,
            'payment_method': 'credit',
            'operator_name': operatorName,
            'created_at': nowIso,
          });
        }
      }
    });
  }
}