// lib/features/sales/data/sqlite_sales_repository.dart

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

  // ─── CREATE SALE (FEFO ATOMIC STOCK DEDUCTION) ───────────────

  @override
  Future<Result<Sale>> createSale({
    required Sale sale,
    required List<PaymentTender> tenders,
    String? accountId, // Added for Ledger
    int accountAmountPaisa = 0, // Added for Ledger
  }) async {
    try {
      final db = await _db;
      final nowIso = sale.createdAt.toIso8601String();

      await db.transaction((txn) async {
        // 1. Save Sale Invoice Header
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
          'created_at': nowIso,
        });

        // 2. Save Line Items & Deduct Physical Batch Stock (FEFO)
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

          int remainingToDeduct = item.quantity;

          // A. If a specific batch ID was provided by POS, deduct from it first
          if (item.batchId.value.isNotEmpty) {
            final batchRows = await txn.query(
              'batches',
              where: 'id = ? AND medicine_id = ?',
              whereArgs: [item.batchId.value, item.medicineId.value],
            );

            if (batchRows.isNotEmpty) {
              final currentBatchQty = batchRows.first['quantity'] as int;
              final take = currentBatchQty >= remainingToDeduct
                  ? remainingToDeduct
                  : currentBatchQty;

              await txn.update(
                'batches',
                {
                  'quantity': currentBatchQty - take,
                  'updated_at': nowIso,
                },
                where: 'id = ?',
                whereArgs: [item.batchId.value],
              );

              remainingToDeduct -= take;
            }
          }

          // B. FEFO Auto-Deduction: Deduct remaining units from oldest active batches
          if (remainingToDeduct > 0) {
            final batches = await txn.query(
              'batches',
              where: 'medicine_id = ? AND quantity > 0',
              whereArgs: [item.medicineId.value],
              orderBy: 'expiry_date ASC',
            );

            for (final b in batches) {
              if (remainingToDeduct <= 0) break;
              final bId = b['id'] as String;
              final bQty = b['quantity'] as int;
              final take = bQty >= remainingToDeduct ? remainingToDeduct : bQty;

              await txn.update(
                'batches',
                {
                  'quantity': bQty - take,
                  'updated_at': nowIso,
                },
                where: 'id = ?',
                whereArgs: [bId],
              );

              remainingToDeduct -= take;
            }
          }

          // C. Deduct total balance in inventory_stocks table
          final stockRows = await txn.query(
            'inventory_stocks',
            where: 'medicine_id = ?',
            whereArgs: [item.medicineId.value],
          );

          if (stockRows.isNotEmpty) {
            final currentStock = stockRows.first['quantity'] as int;
            await txn.update(
              'inventory_stocks',
              {'quantity': currentStock - item.quantity},
              where: 'medicine_id = ?',
              whereArgs: [item.medicineId.value],
            );
          } else {
            await txn.insert('inventory_stocks', {
              'medicine_id': item.medicineId.value,
              'quantity': -item.quantity,
            });
          }

          // D. Log immutable inventory movement
          final movementId = 'mov_sale_${sale.id.value}_${item.id}';
          await txn.insert('inventory_movements', {
            'id': movementId,
            'medicine_id': item.medicineId.value,
            'batch_id':
            item.batchId.value.isNotEmpty ? item.batchId.value : null,
            'type': 'sale',
            'quantity_changed': -item.quantity,
            'reason': 'Sale (Invoice: ${sale.invoiceNumber.value})',
            'reference': sale.invoiceNumber.value,
            'operator_name': sale.operatorName,
            'created_at': nowIso,
          });
        }

        // 3. Save Payment Tenders
        for (final tender in tenders) {
          await txn.insert('sale_payments', {
            'id':
            'pay_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
            'sale_id': sale.id.value,
            'method': tender.method.name,
            'amount': tender.amount.paisa,
            'reference': tender.reference,
          });
        }

        // 4. Ledger: MONEY IN (Debit)
        if (accountId != null && accountId.isNotEmpty && accountAmountPaisa > 0) {
          await txn.insert('financial_transactions', {
            'id': 'ft_sale_${sale.id.value}',
            'account_id': accountId,
            'source': 'sale',
            'description': 'Sale ${sale.invoiceNumber.value} — ${sale.customerName}',
            'reference': sale.invoiceNumber.value,
            'debit': accountAmountPaisa, // Money arriving in till
            'credit': 0,
            'operator_name': sale.operatorName,
            'created_at': nowIso,
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
    return rows
        .map((r) => SaleItem(
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
    ))
        .toList();
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
      final tenders = rows
          .map((r) => PaymentTender(
        method: PaymentMethod.values.firstWhere(
              (e) => e.name == r['method'],
          orElse: () => PaymentMethod.cash,
        ),
        amount: Money.fromPaisa(r['amount'] as int),
        reference: r['reference'] as String?,
      ))
          .toList();
      return Success(tenders);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load payments: $e'));
    }
  }

  // ─── ATOMIC SALES RETURNS ────────────────────────────────────

  @override
  Future<Result<SalesReturn>> createSalesReturn(SalesReturn r) async {
    try {
      final db = await _db;
      final restock = r.reason != SalesReturnReason.damaged &&
          r.reason != SalesReturnReason.expired;

      await db.transaction((txn) async {
        final existing = await txn.rawQuery(
          'SELECT 1 FROM sales_returns WHERE id = ? LIMIT 1',
          [r.id.value],
        );
        if (existing.isNotEmpty) return;

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

        if (restock) {
          final nowIso = DateTime.now().toIso8601String();
          for (var i = 0; i < r.items.length; i++) {
            final item = r.items[i];

            await txn.rawUpdate(
              'UPDATE batches SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
              [item.quantity, nowIso, item.batchId.value],
            );

            await txn.rawUpdate(
              'UPDATE inventory_stocks SET quantity = quantity + ? WHERE medicine_id = ?',
              [item.quantity, item.medicineId.value],
            );

            await txn.insert('inventory_movements', {
              'id': 'mov_sret_${r.id.value}_${i}_${item.medicineId.value}',
              'medicine_id': item.medicineId.value,
              'batch_id': item.batchId.value,
              'type': 'sale_return',
              'quantity_changed': item.quantity,
              'reason': 'Sales Return (Return ID: ${r.id.value})',
              'reference': r.originalInvoiceNumber,
              'operator_name': r.operatorName,
              'created_at': nowIso,
            });
          }
        }

        await txn.update(
          'sales',
          {'status': SaleStatus.partiallyReturned.name},
          where: 'id = ?',
          whereArgs: [r.originalSaleId.value],
        );
      });

      return Success(r);
    } catch (e) {
      return Failure(
          DatabaseFailure(message: 'Atomic sales return failed: $e'));
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
          items: items
              .map((r) => SalesReturnItem(
            id: r['id'] as String,
            originalSaleItemId: r['original_sale_item_id'] as String,
            medicineId: MedicineId(r['medicine_id'] as String),
            medicineName: r['medicine_name'] as String,
            batchId: BatchId(r['batch_id'] as String),
            batchNumber: r['batch_number'] as String,
            quantity: r['quantity'] as int,
            refundAmount: Money.fromPaisa(r['refund_amount'] as int),
          ))
              .toList(),
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
      return Failure(
          DatabaseFailure(message: 'Failed to load return quantities: $e'));
    }
  }
}

// ignore: unused_element
void _keepJson() => jsonEncode({});