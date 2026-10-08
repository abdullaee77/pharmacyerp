import 'package:sqflite/sqflite.dart';

class PurchaseException implements Exception {
  final String message;
  const PurchaseException(this.message);

  @override
  String toString() => message;
}

class PurchaseTransaction {
  PurchaseTransaction._();

  static const List<String> _purchaseColumns = [
    'id', 'invoice_number', 'supplier_name', 'subtotal', 'discount',
    'grand_total', 'status', 'created_at', 'updated_at'
  ];

  static const List<String> _itemColumns = [
    'id', 'purchase_id', 'medicine_id', 'medicine_name', 'batch_number',
    'expiry_date', 'quantity', 'purchase_price', 'selling_price', 'line_total'
  ];

  static Map<String, dynamic> _pick(Map<String, dynamic> src, List<String> cols) {
    return {for (final c in cols) if (src.containsKey(c)) c: src[c]};
  }

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final purchaseIn = payload['purchase'];
    final itemsIn = payload['items'];
    if (purchaseIn is! Map || itemsIn is! List || itemsIn.isEmpty) {
      throw const PurchaseException('Invalid purchase data.');
    }

    final purchase = _pick(Map<String, dynamic>.from(purchaseIn), _purchaseColumns);
    final purchaseId = purchase['id'] as String? ?? '';
    final invoice = purchase['invoice_number'] as String? ?? '';
    final supplierName = (purchase['supplier_name'] as String? ?? '').trim();
    final operatorName = (payload['operatorName'] as String? ?? 'System').trim();

    if (purchaseId.isEmpty || invoice.isEmpty) {
      throw const PurchaseException('Purchase is missing id or invoice number.');
    }

    final items = <Map<String, dynamic>>[];
    for (final raw in itemsIn) {
      final row = _pick(Map<String, dynamic>.from(raw as Map), _itemColumns);
      row['purchase_id'] = purchaseId;
      final qty = row['quantity'];
      if (qty is! int || qty <= 0) {
        throw PurchaseException('Invalid quantity for item in purchase.');
      }
      items.add(row);
    }

    await db.transaction((txn) async {
      // Idempotency check: if already recorded, bypass and return success
      final existing = await txn.rawQuery(
        'SELECT 1 FROM purchases WHERE id = ? LIMIT 1',
        [purchaseId],
      );
      if (existing.isNotEmpty) return;

      // 1. Insert Purchase and Purchase Items
      await txn.insert('purchases', purchase);
      for (final item in items) {
        await txn.insert('purchase_items', item);
      }

      final nowIso = DateTime.now().toIso8601String();

      // 2. Loop items to construct Batches, Stocks, and Movements
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final medId = item['medicine_id'] as String;
        final qty = item['quantity'] as int;
        final batchNum = item['batch_number'] as String;

        // Generate batch ID
        final batchId = 'bat_pur_${purchaseId}_${i}_$medId';

        // Insert new Batch
        await txn.insert('batches', {
          'id': batchId,
          'medicine_id': medId,
          'batch_number': batchNum,
          'expiry_date': item['expiry_date'],
          'quantity': qty,
          'purchase_price': item['purchase_price'],
          'selling_price': item['selling_price'],
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        // Update/Insert inventory stock
        final stockRows = await txn.rawQuery(
          'SELECT quantity FROM inventory_stocks WHERE medicine_id = ?',
          [medId],
        );

        if (stockRows.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE inventory_stocks SET quantity = quantity + ? WHERE medicine_id = ?',
            [qty, medId],
          );
        } else {
          await txn.insert('inventory_stocks', {
            'medicine_id': medId,
            'quantity': qty,
          });
        }

        // Insert Movement log
        await txn.insert('inventory_movements', {
          'id': 'mov_pur_${purchaseId}_${i}_$medId',
          'medicine_id': medId,
          'batch_id': batchId,
          'type': 'purchase',
          'quantity_changed': qty,
          'reason': 'Purchase Recv (Inv: $invoice)',
          'reference': invoice,
          'operator_name': operatorName,
          'created_at': nowIso,
        });
      }

      // 3. Post to Supplier Ledger if Supplier exists by Name
      if (supplierName.isNotEmpty) {
        final supRows = await txn.rawQuery(
          'SELECT id FROM suppliers WHERE LOWER(name) = LOWER(?) LIMIT 1',
          [supplierName],
        );
        if (supRows.isNotEmpty) {
          final supplierId = supRows.first['id'] as String;
          final grandTotal = purchase['grand_total'] as int? ?? 0;

          await txn.insert('supplier_ledger_entries', {
            'id': 's_ledg_pur_$purchaseId',
            'supplier_id': supplierId,
            'entry_type': 'purchase_invoice',
            'description': 'Purchase invoice received: $invoice',
            'reference': purchaseId,
            'debit': 0,
            'credit': grandTotal,
            'payment_method': 'credit',
            'operator_name': operatorName,
            'created_at': nowIso,
          });
        }
      }
    });
  }
}