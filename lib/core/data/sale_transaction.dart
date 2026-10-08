import 'dart:math';
import 'package:sqflite/sqflite.dart';

/// A business-rule failure (e.g. insufficient stock). The whole sale is rolled back.
class SaleException implements Exception {
  final String message;
  const SaleException(this.message);

  @override
  String toString() => message;
}

/// Runs a complete POS checkout as ONE atomic database transaction.
///
/// Used by:
///  - the server (`POST /api/sales/complete`) for sales made on client PCs, and
///  - the local use case when the app runs standalone / on the server PC.
///
/// Because SQLite serialises transactions, two cashiers selling the last unit
/// of the same batch at the same time cannot both succeed.
class SaleTransaction {
  SaleTransaction._();

  static const List<String> _saleColumns = [
    'id', 'invoice_number', 'customer_name', 'operator_name', 'subtotal',
    'discount', 'grand_total', 'amount_received', 'change_amount', 'status',
    'created_at',
  ];
  static const List<String> _itemColumns = [
    'id', 'sale_id', 'medicine_id', 'medicine_name', 'medicine_strength',
    'batch_id', 'batch_number', 'quantity', 'unit_price', 'discount_percent',
    'line_total',
  ];
  static const List<String> _paymentColumns = [
    'id', 'sale_id', 'method', 'amount', 'reference',
  ];

  /// Only known columns are ever copied, so a tampered payload cannot
  /// write to arbitrary columns.
  static Map<String, dynamic> _pick(Map<String, dynamic> src, List<String> cols) {
    return {for (final c in cols) c: src[c]};
  }

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final saleIn = payload['sale'];
    final itemsIn = payload['items'];
    final paymentsIn = payload['payments'];
    if (saleIn is! Map || itemsIn is! List || itemsIn.isEmpty) {
      throw const SaleException('Invalid sale data.');
    }

    final sale = _pick(Map<String, dynamic>.from(saleIn), _saleColumns);
    final saleId = sale['id'] as String? ?? '';
    final invoice = sale['invoice_number'] as String? ?? '';
    final operatorName = sale['operator_name'] as String? ?? '';
    if (saleId.isEmpty || invoice.isEmpty) {
      throw const SaleException('Sale is missing its id or invoice number.');
    }

    final items = <Map<String, dynamic>>[];
    for (final raw in itemsIn) {
      final row = _pick(Map<String, dynamic>.from(raw as Map), _itemColumns);
      row['sale_id'] = saleId;
      final qty = row['quantity'];
      if (qty is! int || qty <= 0) {
        throw SaleException('Invalid quantity for ${row['medicine_name']}.');
      }
      items.add(row);
    }

    final payments = <Map<String, dynamic>>[];
    if (paymentsIn is List) {
      for (final raw in paymentsIn) {
        final row =
        _pick(Map<String, dynamic>.from(raw as Map), _paymentColumns);
        row['sale_id'] = saleId;
        payments.add(row);
      }
    }

    final customerName = (payload['customerName'] as String? ?? '').trim();
    final customerPhone = (payload['customerPhone'] as String? ?? '').trim();
    final creditAmount = (payload['creditAmount'] as num?)?.toInt() ?? 0;

    await db.transaction((txn) async {
      // Idempotent: if a retry arrives after the first attempt already
      // committed (e.g. the reply was lost), do nothing and report success.
      final existing = await txn.rawQuery(
        'SELECT 1 FROM sales WHERE id = ? LIMIT 1',
        [saleId],
      );
      if (existing.isNotEmpty) return;

      // 1. Sale, items, payments
      await txn.insert('sales', sale);
      for (final item in items) {
        await txn.insert('sale_items', item);
      }
      for (final payment in payments) {
        await txn.insert('sale_payments', payment);
      }

      // 2. Stock + movements
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final batchId = item['batch_id'] as String;
        final batchNumber = item['batch_number'];
        final qty = item['quantity'] as int;
        final medicineId = item['medicine_id'] as String;
        final nowIso = DateTime.now().toIso8601String();

        final batchRows = await txn.rawQuery(
          'SELECT quantity FROM batches WHERE id = ?',
          [batchId],
        );
        if (batchRows.isEmpty) {
          throw SaleException('Batch $batchNumber was not found.');
        }
        final available = batchRows.first['quantity'] as int;
        if (available < qty) {
          throw SaleException(
            'Insufficient stock in batch $batchNumber. Available: $available',
          );
        }

        // Guarded update: can never take stock below zero.
        final updated = await txn.rawUpdate(
          'UPDATE batches SET quantity = quantity - ?, updated_at = ? '
              'WHERE id = ? AND quantity >= ?',
          [qty, nowIso, batchId, qty],
        );
        if (updated == 0) {
          throw SaleException('Insufficient stock in batch $batchNumber.');
        }

        await txn.rawUpdate(
          'UPDATE inventory_stocks SET quantity = quantity - ? '
              'WHERE medicine_id = ?',
          [qty, medicineId],
        );

        await txn.insert('inventory_movements', {
          'id': 'mov_${DateTime.now().microsecondsSinceEpoch}_${i}_$medicineId',
          'medicine_id': medicineId,
          'batch_id': batchId,
          'type': 'sale',
          'quantity_changed': -qty,
          'reason': 'Customer Sale (Inv: $invoice)',
          'reference': invoice,
          'operator_name': operatorName,
          'created_at': nowIso,
        });
      }

      // 3. Customer profile + credit ledger
      final lowerName = customerName.toLowerCase();
      final isNamedCustomer = customerName.isNotEmpty &&
          lowerName != 'walk-in customer' &&
          lowerName != 'walk-in' &&
          lowerName != 'walkin';

      String? customerId;
      if (isNamedCustomer) {
        List<Map<String, dynamic>> rows = [];
        if (customerPhone.isNotEmpty) {
          rows = await txn.rawQuery(
            'SELECT id FROM customers WHERE phone = ? LIMIT 1',
            [customerPhone],
          );
        }
        if (rows.isEmpty) {
          rows = await txn.rawQuery(
            'SELECT id FROM customers WHERE LOWER(name) = LOWER(?) LIMIT 1',
            [customerName],
          );
        }

        if (rows.isNotEmpty) {
          customerId = rows.first['id'] as String;
        } else {
          final rand = Random().nextInt(99999).toString().padLeft(5, '0');
          customerId = 'cus_${DateTime.now().millisecondsSinceEpoch}_$rand';
          final nowIso = DateTime.now().toIso8601String();
          await txn.insert('customers', {
            'id': customerId,
            'name': customerName,
            'phone': customerPhone,
            'email': '',
            'address': '',
            'credit_limit': 0,
            'status': 'active',
            'created_at': nowIso,
            'updated_at': nowIso,
          });
        }
      }

      if (creditAmount > 0 && customerId != null) {
        await txn.insert('customer_ledger_entries', {
          'id': 'c_ledg_${DateTime.now().microsecondsSinceEpoch}',
          'customer_id': customerId,
          'entry_type': 'sale_credit',
          'description': 'On-credit sale under Invoice: $invoice',
          'reference': saleId,
          'debit': creditAmount,
          'credit': 0,
          'payment_method': 'credit',
          'operator_name': operatorName,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }
}