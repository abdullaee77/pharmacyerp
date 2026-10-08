import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../domain/financial_transaction.dart';

class HttpAccountRepository implements AccountRepository {
  final ApiClient _api;

  HttpAccountRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Account _rowToAccount(Map<String, dynamic> r) {
    return Account(
      id: AccountId(r['id'] as String),
      name: r['name'] as String,
      accountType: AccountType.values.firstWhere(
            (e) => e.name == r['account_type'],
        orElse: () => AccountType.other,
      ),
      openingBalance: Money.fromPaisa(r['opening_balance'] as int? ?? 0),
      status: AccountStatus.values.firstWhere(
            (e) => e.name == r['status'],
        orElse: () => AccountStatus.active,
      ),
      notes: r['notes'] as String? ?? '',
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  Future<Money> _computeBalance(Account a) async {
    final res = await _api.rawQuery(
      sql: '''
        SELECT COALESCE(SUM(debit), 0) AS total_debit,
               COALESCE(SUM(credit), 0) AS total_credit
        FROM financial_transactions
        WHERE account_id = ?
      ''',
      args: [a.id.value],
    );

    return res.fold(
      onSuccess: (rows) {
        final debit = rows.isEmpty ? 0 : (rows.first['total_debit'] as num).toInt();
        final credit = rows.isEmpty ? 0 : (rows.first['total_credit'] as num).toInt();
        return Money.fromPaisa(a.openingBalance.paisa + (debit - credit));
      },
      onFailure: (_) => a.openingBalance,
    );
  }

  @override
  Future<Result<List<AccountWithBalance>>> getAccounts({String? searchQuery}) async {
    final where = searchQuery != null && searchQuery.isNotEmpty ? 'name LIKE ?' : null;
    final args = searchQuery != null && searchQuery.isNotEmpty ? ['%$searchQuery%'] : null;

    final res = await _api.query(table: 'accounts', where: where, args: args, orderBy: 'name ASC');

    return res.fold(
      onSuccess: (rows) async {
        final list = <AccountWithBalance>[];
        for (final r in rows) {
          final acc = _rowToAccount(r);
          final bal = await _computeBalance(acc);
          list.add(AccountWithBalance(account: acc, currentBalance: bal));
        }
        return Success(list);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Account>> getAccountById(AccountId id) async {
    final res = await _api.query(table: 'accounts', where: 'id = ?', args: [id.value], limit: 1);
    return res.fold(
      onSuccess: (rows) => rows.isEmpty
          ? const Failure(NotFoundFailure(message: 'Account not found.'))
          : Success(_rowToAccount(rows.first)),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Account>> createAccount(Account a) async {
    final res = await _api.insert(table: 'accounts', data: {
      'id': a.id.value,
      'name': a.name,
      'account_type': a.accountType.name,
      'opening_balance': a.openingBalance.paisa,
      'status': a.status.name,
      'notes': a.notes,
      'created_at': a.createdAt.toIso8601String(),
      'updated_at': a.updatedAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => Success(a), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<Account>> updateAccount(Account a) async {
    final res = await _api.update(
      table: 'accounts',
      data: {
        'name': a.name,
        'account_type': a.accountType.name,
        'opening_balance': a.openingBalance.paisa,
        'status': a.status.name,
        'notes': a.notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      args: [a.id.value],
    );
    return res.fold(
      onSuccess: (c) => c == 0 ? const Failure(NotFoundFailure(message: 'Account not found.')) : Success(a),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteAccount(AccountId id) async {
    final res = await _api.delete(table: 'accounts', where: 'id = ?', args: [id.value]);
    return res.fold(
      onSuccess: (c) => c == 0 ? const Failure(NotFoundFailure(message: 'Account not found.')) : const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Money>> getBalance(AccountId id) async {
    final accRes = await getAccountById(id);
    if (accRes.isFailure) return Failure(accRes.failureOrNull!);
    return Success(await _computeBalance(accRes.valueOrNull!));
  }

  @override
  Future<Result<List<FinancialTransactionRow>>> getLedger(AccountId id) async {
    final accRes = await getAccountById(id);
    if (accRes.isFailure) return Failure(accRes.failureOrNull!);
    final account = accRes.valueOrNull!;

    final res = await _api.query(table: 'financial_transactions', where: 'account_id = ?', args: [id.value], orderBy: 'created_at ASC');

    return res.fold(
      onSuccess: (rows) {
        int running = account.openingBalance.paisa;
        final list = <FinancialTransactionRow>[];

        if (account.openingBalance.paisa != 0) {
          list.add(FinancialTransactionRow(
            transaction: FinancialTransaction(
              id: 'opening_${account.id.value}',
              accountId: account.id,
              source: TransactionSource.openingBalance,
              description: 'Opening Balance',
              debit: account.openingBalance.paisa > 0 ? account.openingBalance : Money.zero(),
              credit: account.openingBalance.paisa < 0 ? Money.fromPaisa(-account.openingBalance.paisa) : Money.zero(),
              operatorName: 'System',
              createdAt: account.createdAt,
            ),
            runningBalance: account.openingBalance,
          ));
        }

        for (final r in rows) {
          final debit = r['debit'] as int;
          final credit = r['credit'] as int;
          running += (debit - credit);

          list.add(FinancialTransactionRow(
            transaction: FinancialTransaction(
              id: r['id'] as String,
              accountId: id,
              source: TransactionSource.values.firstWhere((e) => e.name == r['source'], orElse: () => TransactionSource.manual),
              description: r['description'] as String,
              reference: r['reference'] as String?,
              debit: Money.fromPaisa(debit),
              credit: Money.fromPaisa(credit),
              operatorName: r['operator_name'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
            runningBalance: Money.fromPaisa(running),
          ));
        }
        return Success(list.reversed.toList());
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> addTransaction(FinancialTransaction tx) async {
    final res = await _api.insert(table: 'financial_transactions', data: {
      'id': tx.id,
      'account_id': tx.accountId.value,
      'source': tx.source.name,
      'description': tx.description,
      'reference': tx.reference,
      'debit': tx.debit.paisa,
      'credit': tx.credit.paisa,
      'operator_name': tx.operatorName,
      'created_at': tx.createdAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => const Success(null), onFailure: (f) => Failure(f));
  }
}