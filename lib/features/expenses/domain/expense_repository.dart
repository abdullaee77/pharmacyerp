import '../../../core/result/result.dart';
import 'expense.dart';

abstract class ExpenseRepository {
  Future<Result<List<ExpenseCategory>>> getCategories();
  Future<Result<ExpenseCategory>> createCategory(ExpenseCategory c);
  Future<Result<void>> deleteCategory(String id);

  Future<Result<List<Expense>>> getExpenses({
    String? searchQuery,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<Result<Expense>> createExpense(Expense expense);
  Future<Result<void>> deleteExpense(ExpenseId id);
  Future<Result<ExpenseSummary>> getSummary();
}