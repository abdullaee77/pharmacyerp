import 'package:sqflite/sqflite.dart';

class ExpenseException implements Exception {
  final String message;
  const ExpenseException(this.message);

  @override
  String toString() => message;
}

class ExpenseTransaction {
  ExpenseTransaction._();

  static const List<String> _expenseColumns = [
    'id', 'category', 'description', 'amount', 'payment_method',
    'account_id', 'reference', 'operator_name', 'expense_date', 'created_at'
  ];

  static Map<String, dynamic> _pick(Map<String, dynamic> src, List<String> cols) {
    return {for (final c in cols) if (src.containsKey(c)) c: src[c]};
  }

  static Future<void> run(Database db, Map<String, dynamic> payload) async {
    final expenseIn = payload['expense'];
    if (expenseIn is! Map) {
      throw const ExpenseException('Invalid expense payload properties.');
    }

    final expense = _pick(Map<String, dynamic>.from(expenseIn), _expenseColumns);
    final expenseId = expense['id'] as String? ?? '';
    final accountId = expense['account_id'] as String? ?? '';
    final amount = expense['amount'] as int? ?? 0;
    final operatorName = (expense['operator_name'] as String? ?? 'System').trim();
    final category = expense['category'] as String? ?? 'Other';
    final description = expense['description'] as String? ?? '';

    if (expenseId.isEmpty) {
      throw const ExpenseException('Expense document contains no unique ID.');
    }
    if (amount <= 0) {
      throw const ExpenseException('Expense amount must be greater than zero.');
    }

    await db.transaction((txn) async {
      final existing = await txn.rawQuery(
        'SELECT 1 FROM expenses WHERE id = ? LIMIT 1',
        [expenseId],
      );
      if (existing.isNotEmpty) return;

      final nowIso = DateTime.now().toIso8601String();

      // 1. Insert Expense Row
      await txn.insert('expenses', expense);

      // 2. Log Credit Financial Transaction to clear expense against target cash/bank account
      if (accountId.isNotEmpty) {
        await txn.insert('financial_transactions', {
          'id': 'ft_exp_$expenseId',
          'account_id': accountId,
          'source': 'expense',
          'description': 'Expense Paid ($category): $description',
          'reference': expenseId,
          'debit': 0,
          'credit': amount,
          'operator_name': operatorName,
          'created_at': nowIso,
        });
      }
    });
  }
}