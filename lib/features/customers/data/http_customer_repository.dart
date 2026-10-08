import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';
import '../domain/customer_repository.dart';

class HttpCustomerRepository implements CustomerRepository {
  final ApiClient _api;

  HttpCustomerRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Customer _rowToCustomer(Map<String, dynamic> r) {
    return Customer(
      id: CustomerId(r['id'] as String),
      name: r['name'] as String,
      phone: r['phone'] as String? ?? '',
      email: r['email'] as String? ?? '',
      address: r['address'] as String? ?? '',
      creditLimit: Money.fromPaisa(r['credit_limit'] as int? ?? 0),
      status: CustomerStatus.values.firstWhere(
            (e) => e.name == (r['status'] as String? ?? 'active'),
        orElse: () => CustomerStatus.active,
      ),
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  Future<Money> _computeBalance(String customerId) async {
    final res = await _api.rawQuery(
      sql: '''
        SELECT COALESCE(SUM(debit), 0) AS total_debit,
               COALESCE(SUM(credit), 0) AS total_credit
        FROM customer_ledger_entries
        WHERE customer_id = ?
      ''',
      args: [customerId],
    );
    return res.fold(
      onSuccess: (rows) {
        if (rows.isEmpty) return Money.zero();
        final debit = (rows.first['total_debit'] as num).toInt();
        final credit = (rows.first['total_credit'] as num).toInt();
        return Money.fromPaisa(debit - credit);
      },
      onFailure: (_) => Money.zero(),
    );
  }

  Future<DateTime?> _getLastActivity(String customerId) async {
    final res = await _api.rawQuery(
      sql: '''
        SELECT MAX(created_at) AS last_at
        FROM customer_ledger_entries
        WHERE customer_id = ?
      ''',
      args: [customerId],
    );
    return res.fold(
      onSuccess: (rows) {
        if (rows.isEmpty || rows.first['last_at'] == null) return null;
        return DateTime.parse(rows.first['last_at'] as String);
      },
      onFailure: (_) => null,
    );
  }

  @override
  Future<Result<List<CustomerWithBalance>>> getCustomers({String? searchQuery}) async {
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR phone LIKE ? OR email LIKE ?)');
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }

    final result = await _api.query(
      table: 'customers',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      args: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return result.fold(
      onSuccess: (rows) async {
        final list = <CustomerWithBalance>[];
        for (final r in rows) {
          final customer = _rowToCustomer(r);
          final balance = await _computeBalance(customer.id.value);
          final lastActivity = await _getLastActivity(customer.id.value);
          list.add(CustomerWithBalance(
            customer: customer,
            outstanding: balance,
            lastActivityAt: lastActivity,
          ));
        }
        return Success(list);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Customer>> getCustomerById(CustomerId id) async {
    final result = await _api.query(
      table: 'customers',
      where: 'id = ?',
      args: [id.value],
      limit: 1,
    );
    return result.fold(
      onSuccess: (rows) {
        if (rows.isEmpty) {
          return const Failure(NotFoundFailure(message: 'Customer not found.'));
        }
        return Success(_rowToCustomer(rows.first));
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Customer?>> findCustomerByName(String name) async {
    final result = await _api.query(
      table: 'customers',
      where: 'LOWER(name) = ?',
      args: [name.toLowerCase()],
      limit: 1,
    );
    return result.fold(
      onSuccess: (rows) {
        if (rows.isEmpty) return const Success(null);
        return Success(_rowToCustomer(rows.first));
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Customer>> createCustomer(Customer c) async {
    final result = await _api.insert(table: 'customers', data: {
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
    return result.fold(
      onSuccess: (_) => Success(c),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Customer>> updateCustomer(Customer c) async {
    final result = await _api.update(
      table: 'customers',
      data: {
        'name': c.name,
        'phone': c.phone,
        'email': c.email,
        'address': c.address,
        'credit_limit': c.creditLimit.paisa,
        'status': c.status.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      args: [c.id.value],
    );
    return result.fold(
      onSuccess: (count) {
        if (count == 0) {
          return const Failure(NotFoundFailure(message: 'Customer not found.'));
        }
        return Success(c);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteCustomer(CustomerId id) async {
    final result = await _api.delete(
      table: 'customers',
      where: 'id = ?',
      args: [id.value],
    );
    return result.fold(
      onSuccess: (count) {
        if (count == 0) {
          return const Failure(NotFoundFailure(message: 'Customer not found.'));
        }
        return const Success(null);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<LedgerRow>>> getLedger(CustomerId id) async {
    final result = await _api.query(
      table: 'customer_ledger_entries',
      where: 'customer_id = ?',
      args: [id.value],
      orderBy: 'created_at ASC',
    );

    return result.fold(
      onSuccess: (rows) {
        int running = 0;
        final list = <LedgerRow>[];
        for (final r in rows) {
          final debit = r['debit'] as int? ?? 0;
          final credit = r['credit'] as int? ?? 0;
          running += (debit - credit);
          final entry = CustomerLedgerEntry(
            id: r['id'] as String,
            customerId: id,
            entryType: CustomerEntryType.values.firstWhere(
                  (e) => e.name == r['entry_type'],
              orElse: () => CustomerEntryType.adjustment,
            ),
            description: r['description'] as String? ?? '',
            reference: r['reference'] as String?,
            debit: Money.fromPaisa(debit),
            credit: Money.fromPaisa(credit),
            paymentMethod: r['payment_method'] as String?,
            operatorName: r['operator_name'] as String? ?? '',
            createdAt: DateTime.parse(r['created_at'] as String),
          );
          list.add(LedgerRow(entry: entry, runningBalance: Money.fromPaisa(running)));
        }
        return Success(list.reversed.toList());
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Money>> getOutstandingBalance(CustomerId id) async {
    try {
      final bal = await _computeBalance(id.value);
      return Success(bal);
    } catch (e) {
      return Failure(ServerFailure(message: 'Failed to compute balance: $e'));
    }
  }

  @override
  Future<Result<void>> addLedgerEntry(CustomerLedgerEntry entry) async {
    final result = await _api.insert(table: 'customer_ledger_entries', data: {
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
    return result.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }
}