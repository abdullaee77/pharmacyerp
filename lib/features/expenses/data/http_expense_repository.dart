import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class HttpExpenseRepository implements ExpenseRepository {
  final ApiClient _api;

  HttpExpenseRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<Result<List<ExpenseCategory>>> getCategories() async {
    final res = await _api.query(table: 'expense_categories', orderBy: 'name ASC');
    return res.fold(
      onSuccess: (rows) => Success(rows.map((r) => ExpenseCategory(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      )).toList()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<ExpenseCategory>> createCategory(ExpenseCategory c) async {
    final res = await _api.insert(table: 'expense_categories', data: {
      'id': c.id,
      'name': c.name,
      'description': c.description,
      'created_at': c.createdAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => Success(c), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<void>> deleteCategory(String id) async {
    final res = await _api.delete(table: 'expense_categories', where: 'id = ?', args: [id]);
    return res.fold(onSuccess: (_) => const Success(null), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<List<Expense>>> getExpenses({String? searchQuery, String? category, DateTime? fromDate, DateTime? toDate}) async {
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(description LIKE ? OR category LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    if (category != null && category.isNotEmpty) {
      whereClauses.add('category = ?');
      args.add(category);
    }
    if (fromDate != null) {
      whereClauses.add('expense_date >= ?');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      whereClauses.add('expense_date <= ?');
      args.add(toDate.toIso8601String());
    }

    final res = await _api.query(
      table: 'expenses',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      args: args.isEmpty ? null : args,
      orderBy: 'expense_date DESC',
    );

    return res.fold(
      onSuccess: (rows) => Success(rows.map((r) => Expense(
        id: ExpenseId(r['id'] as String),
        category: r['category'] as String,
        description: r['description'] as String,
        amount: Money.fromPaisa(r['amount'] as int),
        paymentMethod: r['payment_method'] as String,
        accountId: r['account_id'] as String?,
        reference: r['reference'] as String?,
        operatorName: r['operator_name'] as String,
        expenseDate: DateTime.parse(r['expense_date'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
      )).toList()),
      onFailure: (f) => Failure(f),
    );
  }

  // ─── ATOMIC EXPENSE CREATION ─────────────────────────────────

  @override
  Future<Result<Expense>> createExpense(Expense e) async {
    final payload = {
      'expense': {
        'id': e.id.value,
        'category': e.category,
        'description': e.description,
        'amount': e.amount.paisa,
        'payment_method': e.paymentMethod,
        'account_id': e.accountId,
        'reference': e.reference,
        'operator_name': e.operatorName,
        'expense_date': e.expenseDate.toIso8601String(),
        'created_at': e.createdAt.toIso8601String(),
      },
    };

    final res = await _api.completeExpense(payload);
    return res.fold(
      onSuccess: (_) => Success(e),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteExpense(ExpenseId id) async {
    final res = await _api.delete(table: 'expenses', where: 'id = ?', args: [id.value]);
    return res.fold(onSuccess: (_) => const Success(null), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<ExpenseSummary>> getSummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    Future<int> getSum(String dateCol, String? since) async {
      final res = await _api.rawQuery(
        sql: 'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses ${since != null ? 'WHERE $dateCol >= ?' : ''}',
        args: since != null ? [since] : null,
      );
      return res.fold(onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['total'] as num).toInt(), onFailure: (_) => 0);
    }

    final total = await getSum('expense_date', null);
    final today = await getSum('expense_date', startOfDay);
    final month = await getSum('expense_date', startOfMonth);

    final catRes = await _api.rawQuery(sql: 'SELECT category, COALESCE(SUM(amount), 0) AS total FROM expenses GROUP BY category ORDER BY total DESC');

    final byCategory = <String, Money>{};
    catRes.fold(
      onSuccess: (rows) {
        for (final r in rows) byCategory[r['category'] as String] = Money.fromPaisa((r['total'] as num).toInt());
      },
      onFailure: (_) {},
    );

    return Success(ExpenseSummary(
      today: Money.fromPaisa(today),
      thisMonth: Money.fromPaisa(month),
      total: Money.fromPaisa(total),
      byCategory: byCategory,
    ));
  }
}