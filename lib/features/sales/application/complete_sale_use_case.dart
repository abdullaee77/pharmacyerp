import '../../../core/data/database_helper.dart';
import '../../../core/data/sale_transaction.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_config.dart';
import '../../../core/result/result.dart';
import '../../customers/domain/customer_repository.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/payment.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

/// Completes a POS checkout as ONE atomic transaction.
///
///  - Client PC  : the sale is sent to the server (`/api/sales/complete`),
///                 which runs the transaction on the shared database. Before
///                 this change a client saved the sale to its own local
///                 SQLite, so it never reached the server.
///  - Server PC / standalone: the same transaction runs on the local database.
class CompleteSaleUseCase {
  final DatabaseHelper _dbHelper;

  CompleteSaleUseCase({
    required SalesRepository salesRepository,
    required InventoryRepository inventoryRepository,
    CustomerRepository? customerRepository,
    DatabaseHelper? dbHelper,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Result<void>> execute({
    required Sale sale,
    required List<PaymentTender> tenders,
    String? customerPhone,
  }) async {
    final creditTender = tenders.firstWhere(
          (t) => t.method == PaymentMethod.credit,
      orElse: () => PaymentTender(method: PaymentMethod.cash, amount: Money.zero()),
    );

    final Map<String, dynamic> payload = {
      'sale': <String, dynamic>{
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
      },
      'items': [
        for (final item in sale.items)
          <String, dynamic>{
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
          },
      ],
      'payments': [
        for (int i = 0; i < tenders.length; i++)
          <String, dynamic>{
            'id': 'pay_${sale.id.value}_${tenders[i].method.name}_$i',
            'sale_id': sale.id.value,
            'method': tenders[i].method.name,
            'amount': tenders[i].amount.paisa,
            'reference': null,
          },
      ],
      'customerName': sale.customerName,
      'customerPhone': customerPhone ?? '',
      'creditAmount': creditTender.amount.paisa,
    };

    // ── Client PC: let the server run the transaction ──
    if (NetworkConfig.instance.isClient &&
        NetworkConfig.instance.serverIp.trim().isNotEmpty) {
      return ApiClient.instance.completeSale(payload);
    }

    // ── Server PC / standalone: run it on the local database ──
    try {
      final db = await _dbHelper.database;
      await SaleTransaction.run(db, payload);
      return const Success(null);
    } on SaleException catch (e) {
      return Failure(
        DatabaseFailure(message: 'POS Transaction rolled back: ${e.message}'),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'POS Transaction rolled back: $e'),
      );
    }
  }
}