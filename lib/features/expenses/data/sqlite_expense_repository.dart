import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class SqliteExpenseRepository implements ExpenseRepository {
  final DatabaseHelper _dbHelper;

  SqliteExpenseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<Result<List<ExpenseCategory>>> getCategories() async {
    try {
      final db = await _db;
      final rows = await db.query('expense_categories', orderBy: 'name ASC');
      return Success(rows
          .map((r) => ExpenseCategory(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      ))
          .toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load categories: $e'));
    }
  }

  @override
  Future<Result<ExpenseCategory>> createCategory(ExpenseCategory c) async {
    try {
      final db = await _db;
      await db.insert('expense_categories', {
        'id': c.id,
        'name': c.name,
        'description': c.description,
        'created_at': c.createdAt.toIso8601String(),
      });
      return Success(c);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save category: $e'));
    }
  }

  @override
  Future<Result<void>> deleteCategory(String id) async {
    try {
      final db = await _db;
      await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete category: $e'));
    }
  }

  @override
  Future<Result<List<Expense>>> getExpenses({
    String? searchQuery,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final db = await _db;
      final whereClauses = <String>[];
      final args = <dynamic>[];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClauses.add('(description LIKE ? OR category LIKE ?)');
        final q = '%$searchQuery%';
        args.addAll([q, q]);
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

      final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
      final rows = await db.query(
        'expenses',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'expense_date DESC',
      );

      return Success(rows
          .map((r) => Expense(
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
      ))
          .toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load expenses: $e'));
    }
  }

  @override
  Future<Result<Expense>> createExpense(Expense e) async {
    try {
      final db = await _db;
      await db.insert('expenses', {
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
      });
      return Success(e);
    } catch (err) {
      return Failure(DatabaseFailure(message: 'Failed to save expense: $err'));
    }
  }

  @override
  Future<Result<void>> deleteExpense(ExpenseId id) async {
    try {
      final db = await _db;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id.value]);
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete expense: $e'));
    }
  }

  @override
  Future<Result<ExpenseSummary>> getSummary() async {
    try {
      final db = await _db;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      final totalRow = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses');
      final todayRow = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE expense_date >= ?',
          [startOfDay]);
      final monthRow = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE expense_date >= ?',
          [startOfMonth]);

      final byCatRows = await db.rawQuery('''
        SELECT category, COALESCE(SUM(amount), 0) AS total
        FROM expenses
        GROUP BY category
        ORDER BY total DESC
      ''');

      final byCategory = <String, Money>{};
      for (final r in byCatRows) {
        byCategory[r['category'] as String] =
            Money.fromPaisa((r['total'] as num).toInt());
      }

      return Success(ExpenseSummary(
        today: Money.fromPaisa((todayRow.first['total'] as num).toInt()),
        thisMonth: Money.fromPaisa((monthRow.first['total'] as num).toInt()),
        total: Money.fromPaisa((totalRow.first['total'] as num).toInt()),
        byCategory: byCategory,
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to compute summary: $e'));
    }
  }
}