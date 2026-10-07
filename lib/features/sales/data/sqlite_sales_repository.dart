import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart' as sql;

import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/payment.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import '../domain/sales_return.dart';

class SqliteSalesRepository implements SalesRepository {
  final DatabaseHelper _dbHelper;

  SqliteSalesRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<sql.Database> get _db => _dbHelper.database;

  // ─── CREATE SALE (transactional) ─────────────────────────────

  @override
  Future<Result<Sale>> createSale({
    required Sale sale,
    required List<PaymentTender> tenders,
  }) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.insert('sales', {
          'id': sale.id.value,
          'invoice_number': sale.invoiceNumber.value,
          'customer_name': sale.customerName,
          'operator_name': sale.operatorName,
          'subtotal': sale.subtotal.paisa,
          'discount': sale.discount.paisa,
          'grand_total': sale.grandTotal.paisa,
          'amount_received': sale.amountReceived.paisa,
          'change_amount': sale.change.paisa,
          'status': sale.status.name,
          'created_at': sale.createdAt.toIso8601String(),
        });

        for (final item in sale.items) {
          await txn.insert('sale_items', {
            'id': item.id,
            'sale_id': sale.id.value,
            'medicine_id': item.medicineId.value,
            'medicine_name': item.medicineName,
            'medicine_strength': item.medicineStrength,
            'batch_id': item.batchId.value,
            'batch_number': item.batchNumber,
            'quantity': item.quantity,
            'unit_price': item.unitPrice.paisa,
            'discount_percent': item.discountPercent,
            'line_total': item.lineTotal.paisa,
          });
        }

        for (final tender in tenders) {
          await txn.insert('sale_payments', {
            'id': 'pay_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
            'sale_id': sale.id.value,
            'method': tender.method.name,
            'amount': tender.amount.paisa,
            'reference': tender.reference,
          });
        }
      });

      return Success(sale);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save sale: $e'));
    }
  }

  // ─── READ SALES ──────────────────────────────────────────────

  @override
  Future<Result<List<Sale>>> getSales({
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final db = await _db;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClauses.add('(invoice_number LIKE ? OR customer_name LIKE ?)');
        final q = '%$searchQuery%';
        whereArgs.addAll([q, q]);
      }
      if (fromDate != null) {
        whereClauses.add('created_at >= ?');
        whereArgs.add(fromDate.toIso8601String());
      }
      if (toDate != null) {
        whereClauses.add('created_at <= ?');
        whereArgs.add(toDate.toIso8601String());
      }

      final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
      final rows = await db.query(
        'sales',
        where: where,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'created_at DESC',
      );

      final sales = <Sale>[];
      for (final row in rows) {
        final items = await _loadSaleItems(db, row['id'] as String);
        sales.add(_rowToSale(row, items));
      }

      return Success(sales);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load sales: $e'));
    }
  }

  @override
  Future<Result<Sale>> getSaleById(SaleId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Sale not found.'));
      }
      final items = await _loadSaleItems(db, id.value);
      return Success(_rowToSale(rows.first, items));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load sale: $e'));
    }
  }

  Future<List<SaleItem>> _loadSaleItems(sql.Database db, String saleId) async {
    final rows = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return rows.map((r) => SaleItem(
      id: r['id'] as String,
      medicineId: MedicineId(r['medicine_id'] as String),
      medicineName: r['medicine_name'] as String,
      medicineStrength: r['medicine_strength'] as String? ?? '',
      batchId: BatchId(r['batch_id'] as String),
      batchNumber: r['batch_number'] as String,
      quantity: r['quantity'] as int,
      unitPrice: Money.fromPaisa(r['unit_price'] as int),
      discountPercent: r['discount_percent'] as int,
      lineTotal: Money.fromPaisa(r['line_total'] as int),
    )).toList();
  }

  Sale _rowToSale(Map<String, dynamic> row, List<SaleItem> items) {
    return Sale(
      id: SaleId(row['id'] as String),
      invoiceNumber: InvoiceNumber(row['invoice_number'] as String),
      customerName: row['customer_name'] as String,
      operatorName: row['operator_name'] as String,
      items: items,
      subtotal: Money.fromPaisa(row['subtotal'] as int),
      discount: Money.fromPaisa(row['discount'] as int),
      grandTotal: Money.fromPaisa(row['grand_total'] as int),
      amountReceived: Money.fromPaisa(row['amount_received'] as int),
      change: Money.fromPaisa(row['change_amount'] as int),
      status: SaleStatus.values.firstWhere(
            (e) => e.name == row['status'],
        orElse: () => SaleStatus.completed,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ─── PAYMENTS ────────────────────────────────────────────────

  @override
  Future<Result<List<PaymentTender>>> getPaymentsForSale(SaleId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'sale_payments',
        where: 'sale_id = ?',
        whereArgs: [id.value],
      );
      final tenders = rows.map((r) => PaymentTender(
        method: PaymentMethod.values.firstWhere(
              (e) => e.name == r['method'],
          orElse: () => PaymentMethod.cash,
        ),
        amount: Money.fromPaisa(r['amount'] as int),
        reference: r['reference'] as String?,
      )).toList();
      return Success(tenders);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load payments: $e'));
    }
  }

  // ─── RETURNS ─────────────────────────────────────────────────

  @override
  Future<Result<SalesReturn>> createSalesReturn(SalesReturn r) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.insert('sales_returns', {
          'id': r.id.value,
          'original_sale_id': r.originalSaleId.value,
          'original_invoice_number': r.originalInvoiceNumber,
          'reason': r.reason.name,
          'notes': r.notes,
          'total_refund': r.totalRefund.paisa,
          'operator_name': r.operatorName,
          'created_at': r.createdAt.toIso8601String(),
        });

        for (final item in r.items) {
          await txn.insert('sales_return_items', {
            'id': item.id,
            'return_id': r.id.value,
            'original_sale_item_id': item.originalSaleItemId,
            'medicine_id': item.medicineId.value,
            'medicine_name': item.medicineName,
            'batch_id': item.batchId.value,
            'batch_number': item.batchNumber,
            'quantity': item.quantity,
            'refund_amount': item.refundAmount.paisa,
          });
        }

        // Update original sale status.
        await txn.update(
          'sales',
          {'status': SaleStatus.partiallyReturned.name},
          where: 'id = ?',
          whereArgs: [r.originalSaleId.value],
        );
      });

      return Success(r);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save return: $e'));
    }
  }

  @override
  Future<Result<List<SalesReturn>>> getReturnsForSale(SaleId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'sales_returns',
        where: 'original_sale_id = ?',
        whereArgs: [id.value],
        orderBy: 'created_at DESC',
      );

      final returns = <SalesReturn>[];
      for (final row in rows) {
        final items = await db.query(
          'sales_return_items',
          where: 'return_id = ?',
          whereArgs: [row['id']],
        );

        returns.add(SalesReturn(
          id: SalesReturnId(row['id'] as String),
          originalSaleId: SaleId(row['original_sale_id'] as String),
          originalInvoiceNumber: row['original_invoice_number'] as String,
          reason: SalesReturnReason.values.firstWhere(
                (e) => e.name == row['reason'],
            orElse: () => SalesReturnReason.other,
          ),
          notes: row['notes'] as String?,
          totalRefund: Money.fromPaisa(row['total_refund'] as int),
          operatorName: row['operator_name'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          items: items.map((r) => SalesReturnItem(
            id: r['id'] as String,
            originalSaleItemId: r['original_sale_item_id'] as String,
            medicineId: MedicineId(r['medicine_id'] as String),
            medicineName: r['medicine_name'] as String,
            batchId: BatchId(r['batch_id'] as String),
            batchNumber: r['batch_number'] as String,
            quantity: r['quantity'] as int,
            refundAmount: Money.fromPaisa(r['refund_amount'] as int),
          )).toList(),
        ));
      }

      return Success(returns);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load returns: $e'));
    }
  }

  @override
  Future<Result<Map<String, int>>> getReturnedQuantities(SaleId id) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery('''
        SELECT ri.original_sale_item_id AS item_id, SUM(ri.quantity) AS qty
        FROM sales_return_items ri
        JOIN sales_returns r ON ri.return_id = r.id
        WHERE r.original_sale_id = ?
        GROUP BY ri.original_sale_item_id
      ''', [id.value]);

      final map = <String, int>{};
      for (final r in rows) {
        map[r['item_id'] as String] = (r['qty'] as int);
      }
      return Success(map);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load return quantities: $e'));
    }
  }
}

/// Dummy import to silence unused import warning.
// ignore: unused_element
void _keepJson() => jsonEncode({});