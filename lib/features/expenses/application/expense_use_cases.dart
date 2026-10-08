import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class GetExpensesUseCase {
  final ExpenseRepository _repo;
  const GetExpensesUseCase(this._repo);

  Future<Result<List<Expense>>> execute({
    String? searchQuery,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _repo.getExpenses(
        searchQuery: searchQuery,
        category: category,
        fromDate: fromDate,
        toDate: toDate,
      );
}

class GetExpenseSummaryUseCase {
  final ExpenseRepository _repo;
  const GetExpenseSummaryUseCase(this._repo);

  Future<Result<ExpenseSummary>> execute() => _repo.getSummary();
}

class GetExpenseCategoriesUseCase {
  final ExpenseRepository _repo;
  const GetExpenseCategoriesUseCase(this._repo);

  Future<Result<List<ExpenseCategory>>> execute() => _repo.getCategories();
}

class CreateExpenseUseCase {
  final ExpenseRepository _repo;

  const CreateExpenseUseCase({
    required ExpenseRepository expenseRepository,
    // AccountRepository kept in signature to avoid breaking callers
    dynamic accountRepository,
  }) : _repo = expenseRepository;

  Future<Result<Expense>> execute(Expense expense) async {
    if (expense.description.trim().isEmpty) {
      return const Failure(
          ValidationFailure(message: 'Expense description is required.'));
    }
    if (expense.amount.paisa <= 0) {
      return const Failure(
          ValidationFailure(message: 'Expense amount must be greater than zero.'));
    }

    // The repository now handles expense insert + account debit in ONE
    // atomic transaction, so there is no window for half-saved data.
    return _repo.createExpense(expense);
  }
}

class DeleteExpenseUseCase {
  final ExpenseRepository _repo;
  const DeleteExpenseUseCase(this._repo);

  Future<Result<void>> execute(ExpenseId id) => _repo.deleteExpense(id);
}