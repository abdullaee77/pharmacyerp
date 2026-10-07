import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../domain/financial_transaction.dart';

class SqliteAccountRepository implements AccountRepository {
  final DatabaseHelper _dbHelper;

  SqliteAccountRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

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

  Future<Money> _computeBalance(Database db, Account a) async {
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(debit), 0) AS total_debit,
             COALESCE(SUM(credit), 0) AS total_credit
      FROM financial_transactions
      WHERE account_id = ?
    ''', [a.id.value]);

    final debit = rows.isEmpty ? 0 : (rows.first['total_debit'] as num).toInt();
    final credit = rows.isEmpty ? 0 : (rows.first['total_credit'] as num).toInt();

    // For cash/bank: inflows are debits, outflows are credits.
    // For expense: expenses add to balance (debits).
    // Convention here: balance = opening + (debit - credit).
    final movement = debit - credit;
    return Money.fromPaisa(a.openingBalance.paisa + movement);
  }

  @override
  Future<Result<List<AccountWithBalance>>> getAccounts({String? searchQuery}) async {
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'name LIKE ?';
        args = ['%$searchQuery%'];
      }

      final rows = await db.query('accounts',
          where: where, whereArgs: args, orderBy: 'name ASC');

      final result = <AccountWithBalance>[];
      for (final r in rows) {
        final acc = _rowToAccount(r);
        final bal = await _computeBalance(db, acc);
        result.add(AccountWithBalance(account: acc, currentBalance: bal));
      }
      return Success(result);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load accounts: $e'));
    }
  }

  @override
  Future<Result<Account>> getAccountById(AccountId id) async {
    try {
      final db = await _db;
      final rows = await db
          .query('accounts', where: 'id = ?', whereArgs: [id.value], limit: 1);
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Account not found.'));
      }
      return Success(_rowToAccount(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load account: $e'));
    }
  }

  @override
  Future<Result<Account>> createAccount(Account a) async {
    try {
      final db = await _db;
      await db.insert('accounts', {
        'id': a.id.value,
        'name': a.name,
        'account_type': a.accountType.name,
        'opening_balance': a.openingBalance.paisa,
        'status': a.status.name,
        'notes': a.notes,
        'created_at': a.createdAt.toIso8601String(),
        'updated_at': a.updatedAt.toIso8601String(),
      });
      return Success(a);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save account: $e'));
    }
  }

  @override
  Future<Result<Account>> updateAccount(Account a) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'accounts',
        {
          'name': a.name,
          'account_type': a.accountType.name,
          'opening_balance': a.openingBalance.paisa,
          'status': a.status.name,
          'notes': a.notes,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [a.id.value],
      );
      if (rows == 0) {
        return const Failure(NotFoundFailure(message: 'Account not found.'));
      }
      return Success(a);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update account: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAccount(AccountId id) async {
    try {
      final db = await _db;
      final rows = await db.delete('accounts', where: 'id = ?', whereArgs: [id.value]);
      if (rows == 0) {
        return const Failure(NotFoundFailure(message: 'Account not found.'));
      }
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete account: $e'));
    }
  }

  @override
  Future<Result<Money>> getBalance(AccountId id) async {
    try {
      final db = await _db;
      final rows = await db.query('accounts',
          where: 'id = ?', whereArgs: [id.value], limit: 1);
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Account not found.'));
      }
      final acc = _rowToAccount(rows.first);
      return Success(await _computeBalance(db, acc));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to compute balance: $e'));
    }
  }

  @override
  Future<Result<List<FinancialTransactionRow>>> getLedger(AccountId id) async {
    try {
      final db = await _db;
      final accRows = await db.query('accounts',
          where: 'id = ?', whereArgs: [id.value], limit: 1);
      if (accRows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Account not found.'));
      }
      final account = _rowToAccount(accRows.first);

      final rows = await db.query(
        'financial_transactions',
        where: 'account_id = ?',
        whereArgs: [id.value],
        orderBy: 'created_at ASC',
      );

      int running = account.openingBalance.paisa;
      final list = <FinancialTransactionRow>[];

      // Insert synthetic opening-balance row at the top
      if (account.openingBalance.paisa != 0) {
        list.add(FinancialTransactionRow(
          transaction: FinancialTransaction(
            id: 'opening_${account.id.value}',
            accountId: account.id,
            source: TransactionSource.openingBalance,
            description: 'Opening Balance',
            debit: account.openingBalance.paisa > 0
                ? account.openingBalance
                : Money.zero(),
            credit: account.openingBalance.paisa < 0
                ? Money.fromPaisa(-account.openingBalance.paisa)
                : Money.zero(),
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
            source: TransactionSource.values.firstWhere(
                  (e) => e.name == r['source'],
              orElse: () => TransactionSource.manual,
            ),
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
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load ledger: $e'));
    }
  }

  @override
  Future<Result<void>> addTransaction(FinancialTransaction tx) async {
    try {
      final db = await _db;
      await db.insert('financial_transactions', {
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
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to record transaction: $e'));
    }
  }
}