import 'package:flutter/material.dart';
import '../../../accounts/domain/account_repository.dart';
import '../../application/expense_use_cases.dart';
import '../../domain/expense.dart';
import '../../domain/expense_repository.dart';

class ExpenseController extends ChangeNotifier {
  final GetExpensesUseCase _getExpenses;
  final GetExpenseSummaryUseCase _getSummary;
  final GetExpenseCategoriesUseCase _getCategories;
  final CreateExpenseUseCase _createExpense;
  final DeleteExpenseUseCase _deleteExpense;

  ExpenseController({
    required ExpenseRepository expenseRepository,
    AccountRepository? accountRepository,
  }) : _getExpenses = GetExpensesUseCase(expenseRepository),
       _getSummary = GetExpenseSummaryUseCase(expenseRepository),
       _getCategories = GetExpenseCategoriesUseCase(expenseRepository),
       _createExpense = CreateExpenseUseCase(
         expenseRepository: expenseRepository,
         accountRepository: accountRepository,
       ),
       _deleteExpense = DeleteExpenseUseCase(expenseRepository);

  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  ExpenseSummary? _summary;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _categoryFilter;

  List<Expense> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  ExpenseSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get categoryFilter => _categoryFilter;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final expensesR = await _getExpenses.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      category: _categoryFilter,
    );
    final catR = await _getCategories.execute();
    final sumR = await _getSummary.execute();

    expensesR.fold(
      onSuccess: (d) => _expenses = d,
      onFailure: (f) => _error = f.message,
    );
    catR.fold(
      onSuccess: (d) => _categories = d,
      onFailure: (f) => _error = f.message,
    );
    sumR.fold(
      onSuccess: (d) => _summary = d,
      onFailure: (f) => _error = f.message,
    );

    _isLoading = false;
    notifyListeners();
  }

  void search(String q) {
    _searchQuery = q;
    loadAll();
  }

  void filterByCategory(String? cat) {
    _categoryFilter = cat;
    loadAll();
  }

  Future<String?> createExpense(Expense e) async {
    final r = await _createExpense.execute(e);
    return r.fold(
      onSuccess: (_) {
        loadAll();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteExpense(ExpenseId id) async {
    final r = await _deleteExpense.execute(id);
    return r.fold(
      onSuccess: (_) {
        loadAll();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }
}
