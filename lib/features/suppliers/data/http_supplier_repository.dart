import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';
import '../domain/supplier_repository.dart';

class HttpSupplierRepository implements SupplierRepository {
  final ApiClient _api;

  HttpSupplierRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Supplier _rowToSupplier(Map<String, dynamic> r) {
    return Supplier(
      id: SupplierId(r['id'] as String),
      name: r['name'] as String,
      contactPerson: r['contact_person'] as String? ?? '',
      phone: r['phone'] as String? ?? '',
      email: r['email'] as String? ?? '',
      address: r['address'] as String? ?? '',
      paymentTerms: r['payment_terms'] as String? ?? '',
      status: SupplierStatus.values.firstWhere(
            (e) => e.name == (r['status'] as String? ?? 'active'),
        orElse: () => SupplierStatus.active,
      ),
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  Future<Money> _computePayable(String supplierId) async {
    final res = await _api.rawQuery(
      sql: '''
        SELECT COALESCE(SUM(credit), 0) AS total_credit,
               COALESCE(SUM(debit), 0) AS total_debit
        FROM supplier_ledger_entries
        WHERE supplier_id = ?
      ''',
      args: [supplierId],
    );
    return res.fold(
      onSuccess: (rows) {
        if (rows.isEmpty) return Money.zero();
        final credit = (rows.first['total_credit'] as num).toInt();
        final debit = (rows.first['total_debit'] as num).toInt();
        return Money.fromPaisa(credit - debit);
      },
      onFailure: (_) => Money.zero(),
    );
  }

  Future<DateTime?> _getLastActivity(String supplierId) async {
    final res = await _api.rawQuery(
      sql: '''
        SELECT MAX(created_at) AS last_at
        FROM supplier_ledger_entries
        WHERE supplier_id = ?
      ''',
      args: [supplierId],
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
  Future<Result<List<SupplierWithBalance>>> getSuppliers({String? searchQuery}) async {
    final where = <String>[];
    final args = <dynamic>[];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(name LIKE ? OR contact_person LIKE ? OR phone LIKE ?)');
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }

    final res = await _api.query(
      table: 'suppliers',
      where: where.isEmpty ? null : where.join(' AND '),
      args: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return res.fold(
      onSuccess: (rows) async {
        final list = <SupplierWithBalance>[];
        for (final r in rows) {
          final supplier = _rowToSupplier(r);
          final payable = await _computePayable(supplier.id.value);
          final last = await _getLastActivity(supplier.id.value);
          list.add(SupplierWithBalance(
            supplier: supplier,
            payable: payable,
            lastActivityAt: last,
          ));
        }
        return Success(list);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Supplier>> getSupplierById(SupplierId id) async {
    final res = await _api.query(
      table: 'suppliers',
      where: 'id = ?',
      args: [id.value],
      limit: 1,
    );
    return res.fold(
      onSuccess: (rows) => rows.isEmpty
          ? const Failure(NotFoundFailure(message: 'Supplier not found.'))
          : Success(_rowToSupplier(rows.first)),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Supplier?>> findSupplierByName(String name) async {
    final res = await _api.query(
      table: 'suppliers',
      where: 'LOWER(name) = ?',
      args: [name.toLowerCase()],
      limit: 1,
    );
    return res.fold(
      onSuccess: (rows) =>
      rows.isEmpty ? const Success(null) : Success(_rowToSupplier(rows.first)),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Supplier>> createSupplier(Supplier s) async {
    final res = await _api.insert(table: 'suppliers', data: {
      'id': s.id.value,
      'name': s.name,
      'contact_person': s.contactPerson,
      'phone': s.phone,
      'email': s.email,
      'address': s.address,
      'payment_terms': s.paymentTerms,
      'status': s.status.name,
      'created_at': s.createdAt.toIso8601String(),
      'updated_at': s.updatedAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => Success(s), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<Supplier>> updateSupplier(Supplier s) async {
    final res = await _api.update(
      table: 'suppliers',
      data: {
        'name': s.name,
        'contact_person': s.contactPerson,
        'phone': s.phone,
        'email': s.email,
        'address': s.address,
        'payment_terms': s.paymentTerms,
        'status': s.status.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      args: [s.id.value],
    );
    return res.fold(
      onSuccess: (c) => c == 0
          ? const Failure(NotFoundFailure(message: 'Supplier not found.'))
          : Success(s),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteSupplier(SupplierId id) async {
    final res = await _api.delete(
      table: 'suppliers',
      where: 'id = ?',
      args: [id.value],
    );
    return res.fold(
      onSuccess: (c) => c == 0
          ? const Failure(NotFoundFailure(message: 'Supplier not found.'))
          : const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<SupplierLedgerRow>>> getLedger(SupplierId id) async {
    final res = await _api.query(
      table: 'supplier_ledger_entries',
      where: 'supplier_id = ?',
      args: [id.value],
      orderBy: 'created_at ASC',
    );
    return res.fold(
      onSuccess: (rows) {
        int running = 0;
        final list = <SupplierLedgerRow>[];
        for (final r in rows) {
          final debit = r['debit'] as int? ?? 0;
          final credit = r['credit'] as int? ?? 0;
          running += (credit - debit);
          final entry = SupplierLedgerEntry(
            id: r['id'] as String,
            supplierId: id,
            entryType: SupplierEntryType.values.firstWhere(
                  (e) => e.name == r['entry_type'],
              orElse: () => SupplierEntryType.adjustment,
            ),
            description: r['description'] as String? ?? '',
            reference: r['reference'] as String?,
            debit: Money.fromPaisa(debit),
            credit: Money.fromPaisa(credit),
            paymentMethod: r['payment_method'] as String?,
            operatorName: r['operator_name'] as String? ?? '',
            createdAt: DateTime.parse(r['created_at'] as String),
          );
          list.add(SupplierLedgerRow(
            entry: entry,
            runningBalance: Money.fromPaisa(running),
          ));
        }
        return Success(list.reversed.toList());
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Money>> getPayableBalance(SupplierId id) async {
    try {
      return Success(await _computePayable(id.value));
    } catch (e) {
      return Failure(ServerFailure(message: 'Failed to compute payable: $e'));
    }
  }

  @override
  Future<Result<void>> addLedgerEntry(SupplierLedgerEntry entry) async {
    final res = await _api.insert(table: 'supplier_ledger_entries', data: {
      'id': entry.id,
      'supplier_id': entry.supplierId.value,
      'entry_type': entry.entryType.name,
      'description': entry.description,
      'reference': entry.reference,
      'debit': entry.debit.paisa,
      'credit': entry.credit.paisa,
      'payment_method': entry.paymentMethod,
      'operator_name': entry.operatorName,
      'created_at': entry.createdAt.toIso8601String(),
    });
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }
}