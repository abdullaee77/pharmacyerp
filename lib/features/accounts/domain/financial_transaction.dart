import 'dart:math';
import '../../../core/domain/value_object.dart';
import '../../medicines/domain/value_objects.dart';
import 'account.dart';

/// Origin / source of a financial transaction.
enum TransactionSource {
  manual(label: 'Manual Entry'),
  expense(label: 'Expense'),
  openingBalance(label: 'Opening Balance'),
  transfer(label: 'Transfer'),
  adjustment(label: 'Adjustment');

  final String label;
  const TransactionSource({required this.label});
}

class FinancialTransaction extends ValueObject {
  final String id;
  final AccountId accountId;
  final TransactionSource source;
  final String description;
  final String? reference;
  final Money debit;
  final Money credit;
  final String operatorName;
  final DateTime createdAt;

  const FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.source,
    required this.description,
    this.reference,
    required this.debit,
    required this.credit,
    required this.operatorName,
    required this.createdAt,
  });

  static String newId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(9999);
    return 'ftx_${ts}_$rand';
  }
}

class FinancialTransactionRow {
  final FinancialTransaction transaction;
  final Money runningBalance;

  const FinancialTransactionRow({
    required this.transaction,
    required this.runningBalance,
  });
}