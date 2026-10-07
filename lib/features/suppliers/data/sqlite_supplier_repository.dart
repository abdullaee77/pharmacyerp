import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';
import '../domain/supplier_repository.dart';

class SqliteSupplierRepository implements SupplierRepository {
  final DatabaseHelper _dbHelper;

  SqliteSupplierRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

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
        (e) => e.name == r['status'],
        orElse: () => SupplierStatus.active,
      ),
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  Future<Money> _computePayable(Database db, String supplierId) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(credit), 0) AS total_credit,
             COALESCE(SUM(debit), 0) AS total_debit
      FROM supplier_ledger_entries
      WHERE supplier_id = ?
    ''',
      [supplierId],
    );
    if (rows.isEmpty) return Money.zero();
    final credit = (rows.first['total_credit'] as num).toInt();
    final debit = (rows.first['total_debit'] as num).toInt();
    // Payable = we owe = credit - debit
    return Money.fromPaisa(credit - debit);
  }

  Future<DateTime?> _getLastActivity(Database db, String supplierId) async {
    final rows = await db.rawQuery(
      '''
      SELECT MAX(created_at) AS last_at
      FROM supplier_ledger_entries
      WHERE supplier_id = ?
    ''',
      [supplierId],
    );
    if (rows.isEmpty || rows.first['last_at'] == null) return null;
    return DateTime.parse(rows.first['last_at'] as String);
  }

  @override
  Future<Result<List<SupplierWithBalance>>> getSuppliers({
    String? searchQuery,
  }) async {
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'name LIKE ? OR contact_person LIKE ? OR phone LIKE ?';
        final q = '%$searchQuery%';
        args = [q, q, q];
      }

      final rows = await db.query(
        'suppliers',
        where: where,
        whereArgs: args,
        orderBy: 'name ASC',
      );

      final result = <SupplierWithBalance>[];
      for (final r in rows) {
        final supplier = _rowToSupplier(r);
        final payable = await _computePayable(db, supplier.id.value);
        final lastActivity = await _getLastActivity(db, supplier.id.value);
        result.add(
          SupplierWithBalance(
            supplier: supplier,
            payable: payable,
            lastActivityAt: lastActivity,
          ),
        );
      }

      return Success(result);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load suppliers: $e'));
    }
  }

  @override
  Future<Result<Supplier>> getSupplierById(SupplierId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Supplier not found.'));
      }
      return Success(_rowToSupplier(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load supplier: $e'));
    }
  }

  @override
  Future<Result<Supplier?>> findSupplierByName(String name) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'suppliers',
        where: 'LOWER(name) = ?',
        whereArgs: [name.toLowerCase()],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);
      return Success(_rowToSupplier(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Supplier lookup failed: $e'));
    }
  }

  @override
  Future<Result<Supplier>> createSupplier(Supplier s) async {
    try {
      final db = await _db;
      await db.insert('suppliers', {
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
      return Success(s);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save supplier: $e'));
    }
  }

  @override
  Future<Result<Supplier>> updateSupplier(Supplier s) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'suppliers',
        {
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
        whereArgs: [s.id.value],
      );
      if (rows == 0)
        return const Failure(NotFoundFailure(message: 'Supplier not found.'));
      return Success(s);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update supplier: $e'));
    }
  }

  @override
  Future<Result<void>> deleteSupplier(SupplierId id) async {
    try {
      final db = await _db;
      final rows = await db.delete(
        'suppliers',
        where: 'id = ?',
        whereArgs: [id.value],
      );
      if (rows == 0)
        return const Failure(NotFoundFailure(message: 'Supplier not found.'));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete supplier: $e'));
    }
  }

  @override
  Future<Result<List<SupplierLedgerRow>>> getLedger(SupplierId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'supplier_ledger_entries',
        where: 'supplier_id = ?',
        whereArgs: [id.value],
        orderBy: 'created_at ASC',
      );

      int running = 0;
      final result = <SupplierLedgerRow>[];

      for (final r in rows) {
        final debit = r['debit'] as int;
        final credit = r['credit'] as int;
        // For suppliers, payable = credit - debit
        running += (credit - debit);

        final entry = SupplierLedgerEntry(
          id: r['id'] as String,
          supplierId: id,
          entryType: SupplierEntryType.values.firstWhere(
            (e) => e.name == r['entry_type'],
            orElse: () => SupplierEntryType.adjustment,
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
          SupplierLedgerRow(
            entry: entry,
            runningBalance: Money.fromPaisa(running),
          ),
        );
      }

      return Success(result.reversed.toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load ledger: $e'));
    }
  }

  @override
  Future<Result<Money>> getPayableBalance(SupplierId id) async {
    try {
      final db = await _db;
      return Success(await _computePayable(db, id.value));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to compute payable: $e'));
    }
  }

  @override
  Future<Result<void>> addLedgerEntry(SupplierLedgerEntry entry) async {
    try {
      final db = await _db;
      await db.insert('supplier_ledger_entries', {
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
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to record ledger entry: $e'),
      );
    }
  }
}
