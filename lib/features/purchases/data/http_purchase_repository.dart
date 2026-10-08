// lib/features/purchases/data/http_purchase_repository.dart
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';
import '../domain/purchase_return.dart';

class HttpPurchaseRepository implements PurchaseRepository {
  final ApiClient _api;

  HttpPurchaseRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<Result<Purchase>> createPurchase(Purchase p) async {
    try {
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
        'operatorName': 'LAN client profile',
      };

      final res = await _api.completePurchase(payload);
      return res.fold(
        onSuccess: (_) => Success(p),
        onFailure: (f) => Failure(f),
      );
    } catch (e) {
      return Failure(ServerFailure(message: 'Atomic http checkout failed: $e'));
    }
  }

  Future<List<PurchaseItem>> _loadItems(String purchaseId) async {
    final res = await _api.query(table: 'purchase_items', where: 'purchase_id = ?', args: [purchaseId]);
    return res.fold(
      onSuccess: (rows) => rows.map((r) => PurchaseItem(
        id: r['id'] as String,
        medicineId: MedicineId(r['medicine_id'] as String),
        medicineName: r['medicine_name'] as String,
        batchNumber: r['batch_number'] as String,
        expiryDate: DateTime.parse(r['expiry_date'] as String),
        quantity: r['quantity'] as int,
        purchasePrice: Money.fromPaisa(r['purchase_price'] as int),
        sellingPrice: Money.fromPaisa(r['selling_price'] as int),
        lineTotal: Money.fromPaisa(r['line_total'] as int),
      )).toList(),
      onFailure: (_) => [],
    );
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

  @override
  Future<Result<List<Purchase>>> getPurchases({String? searchQuery}) async {
    final where = searchQuery != null && searchQuery.isNotEmpty ? 'invoice_number LIKE ? OR supplier_name LIKE ?' : null;
    final args = searchQuery != null && searchQuery.isNotEmpty ? ['%$searchQuery%', '%$searchQuery%'] : null;

    final res = await _api.query(
      table: 'purchases',
      where: where,
      args: args,
      orderBy: 'created_at DESC',
    );

    return res.fold(
      onSuccess: (rows) async {
        final list = <Purchase>[];
        for (final r in rows) {
          final items = await _loadItems(r['id'] as String);
          list.add(_rowToPurchase(r, items));
        }
        return Success(list);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Purchase>> getPurchaseById(PurchaseId id) async {
    final res = await _api.query(table: 'purchases', where: 'id = ?', args: [id.value], limit: 1);
    return res.fold(
      onSuccess: (rows) async {
        if (rows.isEmpty) return const Failure(NotFoundFailure(message: 'Purchase record not found.'));
        final items = await _loadItems(id.value);
        return Success(_rowToPurchase(rows.first, items));
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<PurchaseReturn>> createPurchaseReturn(PurchaseReturn r) async {
    try {
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
        'accountId': null,
      };

      final res = await _api.completePurchaseReturn(payload);
      return res.fold(
        onSuccess: (_) => Success(r),
        onFailure: (f) => Failure(f),
      );
    } catch (e) {
      return Failure(ServerFailure(message: 'Failed to sync purchase return: $e'));
    }
  }

  @override
  Future<Result<List<PurchaseReturn>>> getReturnsForPurchase(PurchaseId id) async {
    final res = await _api.query(table: 'purchase_returns', where: 'original_purchase_id = ?', args: [id.value]);
    return res.fold(
      onSuccess: (rows) async {
        final list = <PurchaseReturn>[];
        for (final r in rows) {
          final iRes = await _api.query(table: 'purchase_return_items', where: 'return_id = ?', args: [r['id']]);
          final items = iRes.valueOrNull ?? [];

          list.add(PurchaseReturn(
            id: PurchaseReturnId(r['id'] as String),
            originalPurchaseId: id,
            originalInvoiceNumber: r['original_invoice_number'] as String,
            supplierName: r['supplier_name'] as String,
            reason: PurchaseReturnReason.values.firstWhere((e) => e.name == r['reason']),
            notes: r['notes'] as String?,
            totalRefund: Money.fromPaisa(r['total_refund'] as int),
            operatorName: r['operator_name'] as String,
            createdAt: DateTime.parse(r['created_at'] as String),
            items: items.map((ri) => PurchaseReturnItem(
              id: ri['id'] as String,
              originalPurchaseItemId: ri['original_purchase_item_id'] as String,
              medicineId: MedicineId(ri['medicine_id'] as String),
              medicineName: ri['medicine_name'] as String,
              batchNumber: ri['batch_number'] as String,
              quantity: ri['quantity'] as int,
              refundAmount: Money.fromPaisa(ri['refund_amount'] as int),
            )).toList(),
          ));
        }
        return Success(list);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Map<String, int>>> getReturnedQuantities(PurchaseId id) async {
    final sql = '''
      SELECT ri.original_purchase_item_id AS item_id, SUM(ri.quantity) AS qty
      FROM purchase_return_items ri
      JOIN purchase_returns r ON ri.return_id = r.id
      WHERE r.original_purchase_id = ?
      GROUP BY ri.original_purchase_item_id
    ''';
    final res = await _api.rawQuery(sql: sql, args: [id.value]);
    return res.fold(
      onSuccess: (rows) {
        final map = <String, int>{};
        for (final r in rows) map[r['item_id'] as String] = (r['qty'] as num).toInt();
        return Success(map);
      },
      onFailure: (f) => Failure(f),
    );
  }
}