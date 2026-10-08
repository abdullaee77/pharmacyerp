import 'package:flutter/material.dart';
import '../../application/account_use_cases.dart';
import '../../domain/account.dart';
import '../../domain/account_repository.dart';
import '../../domain/financial_transaction.dart';

class AccountController extends ChangeNotifier {
  final GetAccountsUseCase _getAccounts;
  final CreateAccountUseCase _create;
  final UpdateAccountUseCase _update;
  final DeleteAccountUseCase _delete;
  final GetAccountLedgerUseCase _getLedger;

  AccountController({required AccountRepository repository})
      : _getAccounts = GetAccountsUseCase(repository),
        _create = CreateAccountUseCase(repository),
        _update = UpdateAccountUseCase(repository),
        _delete = DeleteAccountUseCase(repository),
        _getLedger = GetAccountLedgerUseCase(repository);

  List<AccountWithBalance> _accounts = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<FinancialTransactionRow> _activeLedger = [];

  List<AccountWithBalance> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<FinancialTransactionRow> get activeLedger => _activeLedger;

  Future<void> loadAccounts({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getAccounts.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    result.fold(
      onSuccess: (data) {
        _accounts = data;
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void search(String q) {
    _searchQuery = q;
    loadAccounts();
  }

  Future<String?> createAccount(Account a) async {
    final r = await _create.execute(a);
    return r.fold(onSuccess: (_) {
      loadAccounts();
      return null;
    }, onFailure: (f) => f.message);
  }

  Future<String?> updateAccount(Account a) async {
    final r = await _update.execute(a);
    return r.fold(onSuccess: (_) {
      loadAccounts();
      return null;
    }, onFailure: (f) => f.message);
  }

  Future<String?> deleteAccount(AccountId id) async {
    final r = await _delete.execute(id);
    return r.fold(onSuccess: (_) {
      loadAccounts();
      return null;
    }, onFailure: (f) => f.message);
  }

  Future<void> loadLedger(AccountId id) async {
    _activeLedger = [];
    notifyListeners();
    final r = await _getLedger.execute(id);
    r.fold(
      onSuccess: (data) {
        _activeLedger = data;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        notifyListeners();
      },
    );
  }
}