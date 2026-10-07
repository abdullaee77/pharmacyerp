import 'dart:math';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../customers/domain/customer_repository.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/payment.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

class CompleteSaleUseCase {
  final SalesRepository _salesRepository;
  final DatabaseHelper _dbHelper;

  CompleteSaleUseCase({
    required SalesRepository salesRepository,
    required InventoryRepository inventoryRepository,
    CustomerRepository? customerRepository,
    DatabaseHelper? dbHelper,
  })  : _salesRepository = salesRepository,
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Result<void>> execute({
    required Sale sale,
    required List<PaymentTender> tenders,
    String? customerPhone,
  }) async {
    try {
      final db = await _dbHelper.database;

      // Wrap the entire checkout inside a secure, atomic database transaction
      return await db.transaction<Result<void>>((txn) async {

        // 1. Save Sale to database tables directly on the transaction (txn) object
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

        // Insert sale line items
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

        // Insert payments
        for (int i = 0; i < tenders.length; i++) {
          final tender = tenders[i];
          await txn.insert('sale_payments', {
            'id': 'pay_${sale.id.value}_${tender.method.name}_$i',
            'sale_id': sale.id.value,
            'method': tender.method.name,
            'amount': tender.amount.paisa,
            'reference': null,
          });
        }

        // 2. Adjust Stocks & Write Movements
        for (final item in sale.items) {
          final batchRows = await txn.rawQuery(
            'SELECT quantity FROM batches WHERE id = ?',
            [item.batchId.value],
          );
          if (batchRows.isEmpty) {
            throw Exception('Selected batch ${item.batchNumber} was not found in database.');
          }
          final currentBatchQty = batchRows.first['quantity'] as int;
          if (currentBatchQty < item.quantity) {
            throw Exception('Insufficient stock in batch ${item.batchNumber}. Available: $currentBatchQty');
          }

          await txn.rawUpdate(
            'UPDATE batches SET quantity = quantity - ?, updated_at = ? WHERE id = ?',
            [item.quantity, DateTime.now().toIso8601String(), item.batchId.value],
          );

          await txn.rawUpdate(
            'UPDATE inventory_stocks SET quantity = quantity - ? WHERE medicine_id = ?',
            [item.quantity, item.medicineId.value],
          );

          await txn.insert('inventory_movements', {
            'id': 'mov_${DateTime.now().microsecondsSinceEpoch}_${item.medicineId.value}',
            'medicine_id': item.medicineId.value,
            'batch_id': item.batchId.value,
            'type': 'sale',
            'quantity_changed': -item.quantity,
            'reason': 'Customer Sale (Inv: ${sale.invoiceNumber.value})',
            'reference': sale.invoiceNumber.value,
            'operator_name': sale.operatorName,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // 3. Customer Profile & Credit Ledger Management
        final trimmedName = sale.customerName.trim();
        final trimmedPhone = (customerPhone ?? '').trim();
        final isNamedCustomer = trimmedName.isNotEmpty &&
            trimmedName.toLowerCase() != 'walk-in customer' &&
            trimmedName.toLowerCase() != 'walk-in' &&
            trimmedName.toLowerCase() != 'walkin';

        String? customerId;

        if (isNamedCustomer) {
          // Look for existing customer by phone or name
          List<Map<String, dynamic>> customerRows = [];
          if (trimmedPhone.isNotEmpty) {
            customerRows = await txn.rawQuery(
              'SELECT id FROM customers WHERE phone = ? LIMIT 1',
              [trimmedPhone],
            );
          }
          if (customerRows.isEmpty) {
            customerRows = await txn.rawQuery(
              'SELECT id FROM customers WHERE LOWER(name) = LOWER(?) LIMIT 1',
              [trimmedName],
            );
          }

          if (customerRows.isNotEmpty) {
            customerId = customerRows.first['id'] as String;
          } else {
            // Auto-create customer if they do not exist
            final rand = Random().nextInt(99999).toString().padLeft(5, '0');
            customerId = 'cus_${DateTime.now().millisecondsSinceEpoch}_$rand';
            final nowIso = DateTime.now().toIso8601String();
            await txn.insert('customers', {
              'id': customerId,
              'name': trimmedName,
              'phone': trimmedPhone,
              'email': '',
              'address': '',
              'credit_limit': 0,
              'status': 'active',
              'created_at': nowIso,
              'updated_at': nowIso,
            });
          }
        }

        // If credit tender was used, write debit entry to customer ledger
        final creditTender = tenders.firstWhere(
              (t) => t.method == PaymentMethod.credit,
          orElse: () => PaymentTender(method: PaymentMethod.cash, amount: Money.zero()),
        );

        if (creditTender.amount.paisa > 0 && customerId != null) {
          await txn.insert('customer_ledger_entries', {
            'id': 'c_ledg_${DateTime.now().microsecondsSinceEpoch}',
            'customer_id': customerId,
            'entry_type': 'sale_credit',
            'description': 'On-credit sale under Invoice: ${sale.invoiceNumber.value}',
            'reference': sale.id.value,
            'debit': creditTender.amount.paisa,
            'credit': 0,
            'payment_method': 'credit',
            'operator_name': sale.operatorName,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        return const Success(null);
      });
    } catch (e) {
      return Failure(DatabaseFailure(message: 'POS Transaction rolled back: ${e.toString()}'));
    }
  }
}