import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';
import '../domain/customer_repository.dart';

class SqliteCustomerRepository implements CustomerRepository {
  final DatabaseHelper _dbHelper;

  SqliteCustomerRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  Customer _rowToCustomer(Map<String, dynamic> r) {
    return Customer(
      id: CustomerId(r['id'] as String),
      name: r['name'] as String,
      phone: r['phone'] as String? ?? '',
      email: r['email'] as String? ?? '',
      address: r['address'] as String? ?? '',
      creditLimit: Money.fromPaisa(r['credit_limit'] as int? ?? 0),
      status: CustomerStatus.values.firstWhere(
        (e) => e.name == r['status'],
        orElse: () => CustomerStatus.active,
      ),
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  @override
  Future<Result<List<CustomerWithBalance>>> getCustomers({
    String? searchQuery,
  }) async {
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'name LIKE ? OR phone LIKE ? OR email LIKE ?';
        final q = '%$searchQuery%';
        args = [q, q, q];
      }

      final rows = await db.query(
        'customers',
        where: where,
        whereArgs: args,
        orderBy: 'name ASC',
      );

      final result = <CustomerWithBalance>[];
      for (final r in rows) {
        final customer = _rowToCustomer(r);
        final balanceResult = await _computeBalance(db, customer.id.value);
        final lastActivity = await _getLastActivity(db, customer.id.value);
        result.add(
          CustomerWithBalance(
            customer: customer,
            outstanding: balanceResult,
            lastActivityAt: lastActivity,
          ),
        );
      }

      return Success(result);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load customers: $e'));
    }
  }

  Future<Money> _computeBalance(Database db, String customerId) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(debit), 0) AS total_debit,
             COALESCE(SUM(credit), 0) AS total_credit
      FROM customer_ledger_entries
      WHERE customer_id = ?
    ''',
      [customerId],
    );

    if (rows.isEmpty) return Money.zero();
    final debit = (rows.first['total_debit'] as num).toInt();
    final credit = (rows.first['total_credit'] as num).toInt();
    return Money.fromPaisa(debit - credit);
  }

  Future<DateTime?> _getLastActivity(Database db, String customerId) async {
    final rows = await db.rawQuery(
      '''
      SELECT MAX(created_at) AS last_at
      FROM customer_ledger_entries
      WHERE customer_id = ?
    ''',
      [customerId],
    );
    if (rows.isEmpty || rows.first['last_at'] == null) return null;
    return DateTime.parse(rows.first['last_at'] as String);
  }

  @override
  Future<Result<Customer>> getCustomerById(CustomerId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Customer not found.'));
      }
      return Success(_rowToCustomer(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load customer: $e'));
    }
  }

  @override
  Future<Result<Customer?>> findCustomerByName(String name) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'customers',
        where: 'LOWER(name) = ?',
        whereArgs: [name.toLowerCase()],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);
      return Success(_rowToCustomer(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Customer lookup failed: $e'));
    }
  }

  @override
  Future<Result<Customer>> createCustomer(Customer c) async {
    try {
      final db = await _db;
      await db.insert('customers', {
        'id': c.id.value,
        'name': c.name,
        'phone': c.phone,
        'email': c.email,
        'address': c.address,
        'credit_limit': c.creditLimit.paisa,
        'status': c.status.name,
        'created_at': c.createdAt.toIso8601String(),
        'updated_at': c.updatedAt.toIso8601String(),
      });
      return Success(c);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save customer: $e'));
    }
  }

  @override
  Future<Result<Customer>> updateCustomer(Customer c) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'customers',
        {
          'name': c.name,
          'phone': c.phone,
          'email': c.email,
          'address': c.address,
          'credit_limit': c.creditLimit.paisa,
          'status': c.status.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [c.id.value],
      );
      if (rows == 0)
        return const Failure(NotFoundFailure(message: 'Customer not found.'));
      return Success(c);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update customer: $e'));
    }
  }

  @override
  Future<Result<void>> deleteCustomer(CustomerId id) async {
    try {
      final db = await _db;
      final rows = await db.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [id.value],
      );
      if (rows == 0)
        return const Failure(NotFoundFailure(message: 'Customer not found.'));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete customer: $e'));
    }
  }

  @override
  Future<Result<List<LedgerRow>>> getLedger(CustomerId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'customer_ledger_entries',
        where: 'customer_id = ?',
        whereArgs: [id.value],
        orderBy: 'created_at ASC',
      );

      int running = 0;
      final result = <LedgerRow>[];

      for (final r in rows) {
        final debit = r['debit'] as int;
        final credit = r['credit'] as int;
        running += (debit - credit);

        final entry = CustomerLedgerEntry(
          id: r['id'] as String,
          customerId: id,
          entryType: CustomerEntryType.values.firstWhere(
            (e) => e.name == r['entry_type'],
            orElse: () => CustomerEntryType.adjustment,
          ),
          description: r['description'] as String,
          reference: r['reference'] as String?,
          debit: Money.fromPaisa(debit),
          credit: Money.fromPaisa(credit),
          paymentMethod: r['payment_method'] as String?,
          operatorName: r['operator_name'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
        );

        result.add(
          LedgerRow(entry: entry, runningBalance: Money.fromPaisa(running)),
        );
      }

      // Reverse so newest shows first in UI
      return Success(result.reversed.toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load ledger: $e'));
    }
  }

  @override
  Future<Result<Money>> getOutstandingBalance(CustomerId id) async {
    try {
      final db = await _db;
      final bal = await _computeBalance(db, id.value);
      return Success(bal);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to compute balance: $e'));
    }
  }

  @override
  Future<Result<void>> addLedgerEntry(CustomerLedgerEntry entry) async {
    try {
      final db = await _db;
      await db.insert('customer_ledger_entries', {
        'id': entry.id,
        'customer_id': entry.customerId.value,
        'entry_type': entry.entryType.name,
        'description': entry.description,
        'reference': entry.reference,
        'debit': entry.debit.paisa,
        'credit': entry.credit.paisa,
        'payment_method': entry.paymentMethod,
        'operator_name': entry.operatorName,
        'created_at': entry.createdAt.toIso8601String(),
      });
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to record ledger entry: $e'),
      );
    }
  }
}
