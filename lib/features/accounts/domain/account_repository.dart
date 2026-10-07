import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import 'account.dart';
import 'financial_transaction.dart';

abstract class AccountRepository {
  Future<Result<List<AccountWithBalance>>> getAccounts({String? searchQuery});
  Future<Result<Account>> getAccountById(AccountId id);
  Future<Result<Account>> createAccount(Account account);
  Future<Result<Account>> updateAccount(Account account);
  Future<Result<void>> deleteAccount(AccountId id);

  Future<Result<Money>> getBalance(AccountId id);
  Future<Result<List<FinancialTransactionRow>>> getLedger(AccountId id);
  Future<Result<void>> addTransaction(FinancialTransaction tx);
}