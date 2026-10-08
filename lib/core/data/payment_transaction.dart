import 'package:sqflite/sqflite.dart';

class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);

  @override
  String toString() => message;
}

class CustomerPaymentTransaction {
  CustomerPaymentTransaction._();

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final String paymentId = payload['paymentId'] as String? ?? '';
    final String customerId = payload['customerId'] as String? ?? '';
    final int amount = payload['amount'] as int? ?? 0;
    final String method = payload['paymentMethod'] as String? ?? 'cash';
    final String? reference = payload['reference'] as String?;
    final String? note = payload['note'] as String?;
    final String operatorName = (payload['operatorName'] as String? ?? 'System').trim();
    final String accountId = payload['accountId'] as String? ?? '';

    if (paymentId.isEmpty || customerId.isEmpty || accountId.isEmpty) {
      throw const PaymentException('Incomplete payment payload paths.');
    }
    if (amount <= 0) {
      throw const PaymentException('Payment amount must be greater than zero.');
    }

    await db.transaction((txn) async {
      final existing = await txn.rawQuery(
        'SELECT 1 FROM customer_ledger_entries WHERE id = ? LIMIT 1',
        [paymentId],
      );
      if (existing.isNotEmpty) return;

      final nowIso = DateTime.now().toIso8601String();

      // 1. Insert Ledger Entry (increases Customer Credit/reduces debit)
      await txn.insert('customer_ledger_entries', {
        'id': paymentId,
        'customer_id': customerId,
        'entry_type': 'payment_received',
        'description': note ?? 'Payment received: $method${reference != null ? ' (Ref: $reference)' : ''}',
        'reference': reference,
        'debit': 0,
        'credit': amount,
        'payment_method': method,
        'operator_name': operatorName,
        'created_at': nowIso,
      });

      // 2. Insert financial transaction entry in target Cash/Bank account (debit asset)
      await txn.insert('financial_transactions', {
        'id': 'ft_cpay_$paymentId',
        'account_id': accountId,
        'source': 'customer_payment',
        'description': 'Customer payment from profile ID: $customerId',
        'reference': paymentId,
        'debit': amount,
        'credit': 0,
        'operator_name': operatorName,
        'created_at': nowIso,
      });
    });
  }
}

class SupplierPaymentTransaction {
  SupplierPaymentTransaction._();

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final String paymentId = payload['paymentId'] as String? ?? '';
    final String supplierId = payload['supplierId'] as String? ?? '';
    final int amount = payload['amount'] as int? ?? 0;
    final String method = payload['paymentMethod'] as String? ?? 'cash';
    final String? reference = payload['reference'] as String?;
    final String? note = payload['note'] as String?;
    final String operatorName = (payload['operatorName'] as String? ?? 'System').trim();
    final String accountId = payload['accountId'] as String? ?? '';

    if (paymentId.isEmpty || supplierId.isEmpty || accountId.isEmpty) {
      throw const PaymentException('Incomplete payment parameters.');
    }
    if (amount <= 0) {
      throw const PaymentException('Payment amount must be greater than zero.');
    }

    await db.transaction((txn) async {
      final existing = await txn.rawQuery(
        'SELECT 1 FROM supplier_ledger_entries WHERE id = ? LIMIT 1',
        [paymentId],
      );
      if (existing.isNotEmpty) return;

      final nowIso = DateTime.now().toIso8601String();

      // 1. Insert Supplier Ledger entry (releasing liability - Debit)
      await txn.insert('supplier_ledger_entries', {
        'id': paymentId,
        'supplier_id': supplierId,
        'entry_type': 'payment_made',
        'description': note ?? 'Payment made: $method${reference != null ? ' (Ref: $reference)' : ''}',
        'reference': reference,
        'debit': amount,
        'credit': 0,
        'payment_method': method,
        'operator_name': operatorName,
        'created_at': nowIso,
      });

      // 2. Debit account source (reducing bank balance - Credit)
      await txn.insert('financial_transactions', {
        'id': 'ft_spay_$paymentId',
        'account_id': accountId,
        'source': 'supplier_payment',
        'description': 'Supplier payment to profile ID: $supplierId',
        'reference': paymentId,
        'debit': 0,
        'credit': amount,
        'operator_name': operatorName,
        'created_at': nowIso,
      });
    });
  }
}