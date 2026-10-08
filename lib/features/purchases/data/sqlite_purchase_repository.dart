// lib/features/purchases/data/sqlite_purchase_repository.dart
import 'package:sqflite/sqflite.dart' as sql;
import '../../../core/data/database_helper.dart';
import '../../../core/data/purchase_transaction.dart';
import '../../../core/data/return_transactions.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';
import '../domain/purchase_return.dart';

class SqlitePurchaseRepository implements PurchaseRepository {
  final DatabaseHelper _dbHelper;

  SqlitePurchaseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<sql.Database> get _db => _dbHelper.database;

  @override
  Future<Result<Purchase>> createPurchase(Purchase p) async {
    try {
      final db = await _db;

      // Pack exact payload structure matching our PurchaseTransaction payload expectation
      final payload = {
        'purchase': {
          'id': p.id.value,
          'invoice_number': p.invoiceNumber.value,
          'supplier_name': p.supplierName,
          'subtotal': p.subtotal.paisa,
          'discount': p.discount.paisa,
          'grand_total': p.grandTotal.paisa,
          'status': p.status.name,
          'created_at': p.createdAt.toIso8601String(),
          'updated_at': p.updatedAt.toIso8601String(),
        },
        'items': p.items.map((item) => {
          'id': item.id,
          'medicine_id': item.medicineId.value,
          'medicine_name': item.medicineName,
          'batch_number': item.batchNumber,
          'expiry_date': item.expiryDate.toIso8601String(),
          'quantity': item.quantity,
          'purchase_price': item.purchasePrice.paisa,
          'selling_price': item.sellingPrice.paisa,
          'line_total': item.lineTotal.paisa,
        }).toList(),
        'operatorName': 'System standalone/server',
      };

      await PurchaseTransaction.run(db, payload);
      return Success(p);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Atomic Purchase Transaction failed: $e'));
    }
  }

  @override
  Future<Result<List<Purchase>>> getPurchases({String? searchQuery}) async {
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'invoice_number LIKE ? OR supplier_name LIKE ?';
        args = ['%$searchQuery%', '%$searchQuery%'];
      }

      final rows = await db.query(
        'purchases',
        where: where,
        whereArgs: args,
        orderBy: 'created_at DESC',
      );
      final list = <Purchase>[];

      for (final r in rows) {
        final items = await _loadItems(db, r['id'] as String);
        list.add(_rowToPurchase(r, items));
      }

      return Success(list);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to load purchase history: $e'),
      );
    }
  }

  @override
  Future<Result<Purchase>> getPurchaseById(PurchaseId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Failure(
          NotFoundFailure(message: 'Purchase record not found.'),
        );
      }

      final items = await _loadItems(db, id.value);
      return Success(_rowToPurchase(rows.first, items));
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to load purchase record: $e'),
      );
    }
  }

  Future<List<PurchaseItem>> _loadItems(
      sql.Database db,
      String purchaseId,
      ) async {
    final rows = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return rows
        .map(
          (r) => PurchaseItem(
        id: r['id'] as String,
        medicineId: MedicineId(r['medicine_id'] as String),
        medicineName: r['medicine_name'] as String,
        batchNumber: r['batch_number'] as String,
        expiryDate: DateTime.parse(r['expiry_date'] as String),
        quantity: r['quantity'] as int,
        purchasePrice: Money.fromPaisa(r['purchase_price'] as int),
        sellingPrice: Money.fromPaisa(r['selling_price'] as int),
        lineTotal: Money.fromPaisa(r['line_total'] as int),
      ),
    )
        .toList();
  }

  Purchase _rowToPurchase(Map<String, dynamic> r, List<PurchaseItem> items) {
    return Purchase(
      id: PurchaseId(r['id'] as String),
      invoiceNumber: PurchaseInvoiceNumber(r['invoice_number'] as String),
      supplierName: r['supplier_name'] as String,
      items: items,
      subtotal: Money.fromPaisa(r['subtotal'] as int),
      discount: Money.fromPaisa(r['discount'] as int),
      grandTotal: Money.fromPaisa(r['grand_total'] as int),
      status: PurchaseStatus.values.firstWhere((e) => e.name == r['status']),
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  // ─── ATOMIC PURCHASE RETURNS ────────────────────────────────────────

  @override
  Future<Result<PurchaseReturn>> createPurchaseReturn(PurchaseReturn r) async {
    try {
      final db = await _db;

      // Wrap in standard transaction map format
      final payload = {
        'return': {
          'id': r.id.value,
          'original_purchase_id': r.originalPurchaseId.value,
          'original_invoice_number': r.originalInvoiceNumber,
          'supplier_name': r.supplierName,
          'reason': r.reason.name,
          'notes': r.notes,
          'total_refund': r.totalRefund.paisa,
          'operator_name': r.operatorName,
          'created_at': r.createdAt.toIso8601String(),
        },
        'items': r.items.map((item) => {
          'id': item.id,
          'original_purchase_item_id': item.originalPurchaseItemId,
          'medicine_id': item.medicineId.value,
          'medicine_name': item.medicineName,
          'batch_number': item.batchNumber,
          'quantity': item.quantity,
          'refund_amount': item.refundAmount.paisa,
        }).toList(),
        'accountId': null, // default ledger allocation, adjust when accounts selected
      };

      await PurchaseReturnTransaction.run(db, payload);
      return Success(r);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Atomic Purchase Return Transaction failed: $e'),
      );
    }
  }

  @override
  Future<Result<List<PurchaseReturn>>> getReturnsForPurchase(
      PurchaseId id,
      ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'purchase_returns',
        where: 'original_purchase_id = ?',
        whereArgs: [id.value],
      );
      final list = <PurchaseReturn>[];

      for (final r in rows) {
        final items = await db.query(
          'purchase_return_items',
          where: 'return_id = ?',
          whereArgs: [r['id']],
        );
        list.add(
          PurchaseReturn(
            id: PurchaseReturnId(r['id'] as String),
            originalPurchaseId: id,
            originalInvoiceNumber: r['original_invoice_number'] as String,
            supplierName: r['supplier_name'] as String,
            reason: PurchaseReturnReason.values.firstWhere(
                  (e) => e.name == r['reason'],
            ),
            notes: r['notes'] as String?,
            totalRefund: Money.fromPaisa(r['total_refund'] as int),
            operatorName: r['operator_name'] as String,
            createdAt: DateTime.parse(r['created_at'] as String),
            items: items
                .map(
                  (ri) => PurchaseReturnItem(
                id: ri['id'] as String,
                originalPurchaseItemId:
                ri['original_purchase_item_id'] as String,
                medicineId: MedicineId(ri['medicine_id'] as String),
                medicineName: ri['medicine_name'] as String,
                batchNumber: ri['batch_number'] as String,
                quantity: ri['quantity'] as int,
                refundAmount: Money.fromPaisa(ri['refund_amount'] as int),
              ),
            )
                .toList(),
          ),
        );
      }
      return Success(list);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to load purchase return listings: $e'),
      );
    }
  }

  @override
  Future<Result<Map<String, int>>> getReturnedQuantities(PurchaseId id) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        '''
        SELECT ri.original_purchase_item_id AS item_id, SUM(ri.quantity) AS qty
        FROM purchase_return_items ri
        JOIN purchase_returns r ON ri.return_id = r.id
        WHERE r.original_purchase_id = ?
        GROUP BY ri.original_purchase_item_id
      ''',
        [id.value],
      );

      final map = <String, int>{};
      for (final r in rows) {
        map[r['item_id'] as String] = r['qty'] as int;
      }
      return Success(map);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to load returned counts: $e'),
      );
    }
  }
}