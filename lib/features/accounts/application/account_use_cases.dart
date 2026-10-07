import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../domain/financial_transaction.dart';

class CreateAccountUseCase {
  final AccountRepository _repo;
  const CreateAccountUseCase(this._repo);

  Future<Result<Account>> execute(Account a) async {
    if (a.name.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Account name is required.'));
    }
    return _repo.createAccount(a);
  }
}

class UpdateAccountUseCase {
  final AccountRepository _repo;
  const UpdateAccountUseCase(this._repo);

  Future<Result<Account>> execute(Account a) async {
    if (a.name.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Account name is required.'));
    }
    return _repo.updateAccount(a);
  }
}

class GetAccountsUseCase {
  final AccountRepository _repo;
  const GetAccountsUseCase(this._repo);

  Future<Result<List<AccountWithBalance>>> execute({String? searchQuery}) =>
      _repo.getAccounts(searchQuery: searchQuery);
}

class DeleteAccountUseCase {
  final AccountRepository _repo;
  const DeleteAccountUseCase(this._repo);

  Future<Result<void>> execute(AccountId id) => _repo.deleteAccount(id);
}

class GetAccountLedgerUseCase {
  final AccountRepository _repo;
  const GetAccountLedgerUseCase(this._repo);

  Future<Result<List<FinancialTransactionRow>>> execute(AccountId id) =>
      _repo.getLedger(id);
}

/// Called by other modules (e.g. Expenses) to post a transaction to an account.
class PostTransactionUseCase {
  final AccountRepository _repo;
  const PostTransactionUseCase(this._repo);

  Future<Result<void>> execute({
    required AccountId accountId,
    required TransactionSource source,
    required String description,
    String? reference,
    required Money debit,
    required Money credit,
    required String operatorName,
  }) async {
    if (debit.paisa == 0 && credit.paisa == 0) {
      return const Failure(
          ValidationFailure(message: 'Transaction must have a debit or credit amount.'));
    }

    final tx = FinancialTransaction(
      id: FinancialTransaction.newId(),
      accountId: accountId,
      source: source,
      description: description,
      reference: reference,
      debit: debit,
      credit: credit,
      operatorName: operatorName,
      createdAt: DateTime.now(),
    );

    return _repo.addTransaction(tx);
  }
}