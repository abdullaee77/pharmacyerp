import 'dart:math';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/payment.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import '../domain/sales_return.dart';

class HttpSalesRepository implements SalesRepository {
  final ApiClient _api;

  HttpSalesRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<Result<Sale>> createSale({required Sale sale, required List<PaymentTender> tenders}) async {
    try {
      await _api.insert(table: 'sales', data: {
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
        await _api.insert(table: 'sale_items', data: {
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
        await _api.insert(table: 'sale_payments', data: {
          'id': 'pay_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
          'sale_id': sale.id.value,
          'method': tender.method.name,
          'amount': tender.amount.paisa,
          'reference': tender.reference,
        });
      }
      return Success(sale);
    } catch (e) {
      return Failure(ServerFailure(message: 'Failed to sync sale: $e'));
    }
  }

  Future<List<SaleItem>> _loadSaleItems(String saleId) async {
    final res = await _api.query(table: 'sale_items', where: 'sale_id = ?', args: [saleId]);
    return res.fold(
      onSuccess: (rows) => rows.map((r) => SaleItem(
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
      )).toList(),
      onFailure: (_) => [],
    );
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
      status: SaleStatus.values.firstWhere((e) => e.name == row['status'], orElse: () => SaleStatus.completed),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<Result<List<Sale>>> getSales({String? searchQuery, DateTime? fromDate, DateTime? toDate}) async {
    final where = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(invoice_number LIKE ? OR customer_name LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    if (fromDate != null) {
      where.add('created_at >= ?');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      where.add('created_at <= ?');
      args.add(toDate.toIso8601String());
    }

    final res = await _api.query(
      table: 'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      args: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );

    return res.fold(
      onSuccess: (rows) async {
        final sales = <Sale>[];
        for (final row in rows) {
          final items = await _loadSaleItems(row['id'] as String);
          sales.add(_rowToSale(row, items));
        }
        return Success(sales);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Sale>> getSaleById(SaleId id) async {
    final res = await _api.query(table: 'sales', where: 'id = ?', args: [id.value], limit: 1);
    return res.fold(
      onSuccess: (rows) async {
        if (rows.isEmpty) return const Failure(NotFoundFailure(message: 'Sale not found.'));
        final items = await _loadSaleItems(id.value);
        return Success(_rowToSale(rows.first, items));
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<PaymentTender>>> getPaymentsForSale(SaleId id) async {
    final res = await _api.query(table: 'sale_payments', where: 'sale_id = ?', args: [id.value]);
    return res.fold(
      onSuccess: (rows) => Success(rows.map((r) => PaymentTender(
        method: PaymentMethod.values.firstWhere((e) => e.name == r['method'], orElse: () => PaymentMethod.cash),
        amount: Money.fromPaisa(r['amount'] as int),
        reference: r['reference'] as String?,
      )).toList()),
      onFailure: (f) => Failure(f),
    );
  }

  // ─── ATOMIC SALES RETURNS ────────────────────────────────────

  @override
  Future<Result<SalesReturn>> createSalesReturn(SalesReturn r) async {
    try {
      final restock = r.reason != SalesReturnReason.damaged &&
          r.reason != SalesReturnReason.expired;

      final payload = {
        'return': {
          'id': r.id.value,
          'original_sale_id': r.originalSaleId.value,
          'original_invoice_number': r.originalInvoiceNumber,
          'reason': r.reason.name,
          'notes': r.notes,
          'total_refund': r.totalRefund.paisa,
          'operator_name': r.operatorName,
          'created_at': r.createdAt.toIso8601String(),
        },
        'items': r.items.map((item) => {
          'id': item.id,
          'original_sale_item_id': item.originalSaleItemId,
          'medicine_id': item.medicineId.value,
          'medicine_name': item.medicineName,
          'batch_id': item.batchId.value,
          'batch_number': item.batchNumber,
          'quantity': item.quantity,
          'refund_amount': item.refundAmount.paisa,
        }).toList(),
        'restockItems': restock,
        'accountId': null,
      };

      final res = await _api.completeSalesReturn(payload);
      return res.fold(
        onSuccess: (_) => Success(r),
        onFailure: (f) => Failure(f),
      );
    } catch (e) {
      return Failure(ServerFailure(message: 'Atomic sales return failed: $e'));
    }
  }

  @override
  Future<Result<List<SalesReturn>>> getReturnsForSale(SaleId id) async {
    final res = await _api.query(table: 'sales_returns', where: 'original_sale_id = ?', args: [id.value], orderBy: 'created_at DESC');
    return res.fold(
      onSuccess: (rows) async {
        final list = <SalesReturn>[];
        for (final row in rows) {
          final iRes = await _api.query(table: 'sales_return_items', where: 'return_id = ?', args: [row['id']]);
          final items = iRes.valueOrNull ?? [];

          list.add(SalesReturn(
            id: SalesReturnId(row['id'] as String),
            originalSaleId: id,
            originalInvoiceNumber: row['original_invoice_number'] as String,
            reason: SalesReturnReason.values.firstWhere((e) => e.name == row['reason'], orElse: () => SalesReturnReason.other),
            notes: row['notes'] as String?,
            totalRefund: Money.fromPaisa(row['total_refund'] as int),
            operatorName: row['operator_name'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            items: items.map((ri) => SalesReturnItem(
              id: ri['id'] as String,
              originalSaleItemId: ri['original_sale_item_id'] as String,
              medicineId: MedicineId(ri['medicine_id'] as String),
              medicineName: ri['medicine_name'] as String,
              batchId: BatchId(ri['batch_id'] as String),
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
  Future<Result<Map<String, int>>> getReturnedQuantities(SaleId id) async {
    final sql = '''
      SELECT ri.original_sale_item_id AS item_id, SUM(ri.quantity) AS qty
      FROM sales_return_items ri
      JOIN sales_returns r ON ri.return_id = r.id
      WHERE r.original_sale_id = ?
      GROUP BY ri.original_sale_item_id
    ''';
    final res = await _api.rawQuery(sql: sql, args: [id.value]);
    return res.fold(
      onSuccess: (rows) {
        final map = <String, int>{};
        for (final r in rows) {
          map[r['item_id'] as String] = (r['qty'] as num).toInt();
        }
        return Success(map);
      },
      onFailure: (f) => Failure(f),
    );
  }
}