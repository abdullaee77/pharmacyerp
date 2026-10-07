import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../accounts/application/account_use_cases.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_repository.dart';
import '../../accounts/domain/financial_transaction.dart';
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

/// Creates an expense record and (if an account is linked) posts a transaction
/// to the linked account's ledger (debit = account spent money).
class CreateExpenseUseCase {
  final ExpenseRepository _repo;
  final AccountRepository? _accountRepo;

  const CreateExpenseUseCase({
    required ExpenseRepository expenseRepository,
    AccountRepository? accountRepository,
  })  : _repo = expenseRepository,
        _accountRepo = accountRepository;

  Future<Result<Expense>> execute(Expense expense) async {
    if (expense.description.trim().isEmpty) {
      return const Failure(
          ValidationFailure(message: 'Expense description is required.'));
    }
    if (expense.amount.paisa <= 0) {
      return const Failure(
          ValidationFailure(message: 'Expense amount must be greater than zero.'));
    }

    final saved = await _repo.createExpense(expense);
    if (saved.isFailure) return saved;

    // Post to account if linked
    if (_accountRepo != null && expense.accountId != null) {
      final poster = PostTransactionUseCase(_accountRepo!);
      await poster.execute(
        accountId: AccountId(expense.accountId!),
        source: TransactionSource.expense,
        description: '${expense.category}: ${expense.description}',
        reference: expense.reference,
        debit: Money.zero(),
        credit: expense.amount, // Money leaving the account
        operatorName: expense.operatorName,
      );
    }

    return saved;
  }
}

class DeleteExpenseUseCase {
  final ExpenseRepository _repo;
  const DeleteExpenseUseCase(this._repo);

  Future<Result<void>> execute(ExpenseId id) => _repo.deleteExpense(id);
}