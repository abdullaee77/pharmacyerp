import 'package:sqflite/sqflite.dart' as sql;
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/batch.dart';
import '../domain/batch_repository.dart';

/// SQLite implementation of [BatchRepository].
class SqliteBatchRepository implements BatchRepository {
  final DatabaseHelper _dbHelper;

  SqliteBatchRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<sql.Database> get _db => _dbHelper.database;

  Batch _rowToBatch(Map<String, dynamic> row) {
    final expiryDate = ExpiryDate(DateTime.parse(row['expiry_date'] as String));
    return Batch(
      id: BatchId(row['id'] as String),
      medicineId: MedicineId(row['medicine_id'] as String),
      medicineName: row['medicine_name'] as String? ?? '',
      batchNumber: BatchNumber.unsafe(row['batch_number'] as String),
      expiryDate: expiryDate,
      quantity: Quantity.create(row['quantity'] as int),
      purchasePrice: Money.fromPaisa(row['purchase_price'] as int),
      sellingPrice: Money.fromPaisa(row['selling_price'] as int),
      status: Batch.deriveStatus(expiryDate),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> _batchToMap(Batch b) {
    return {
      'id': b.id.value,
      'medicine_id': b.medicineId.value,
      'batch_number': b.batchNumber.value,
      'expiry_date': b.expiryDate.date.toIso8601String(),
      'quantity': b.quantity.value,
      'purchase_price': b.purchasePrice.paisa,
      'selling_price': b.sellingPrice.paisa,
      'created_at': b.createdAt.toIso8601String(),
      'updated_at': b.updatedAt.toIso8601String(),
    };
  }

  @override
  Future<Result<List<Batch>>> getBatches({
    MedicineId? medicineId,
    BatchStatus? status,
    String? searchQuery,
  }) async {
    try {
      final db = await _db;

      String query = '''
        SELECT b.*, m.name AS medicine_name
        FROM batches b
        LEFT JOIN medicines m ON b.medicine_id = m.id
      ''';

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (medicineId != null) {
        whereClauses.add('b.medicine_id = ?');
        whereArgs.add(medicineId.value);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClauses.add(
          '(b.batch_number LIKE ? OR m.name LIKE ? OR m.generic_name LIKE ?)',
        );
        final q = '%$searchQuery%';
        whereArgs.addAll([q, q, q]);
      }

      if (whereClauses.isNotEmpty) {
        query += ' WHERE ${whereClauses.join(' AND ')}';
      }

      query += ' ORDER BY b.expiry_date ASC';

      final rows = await db.rawQuery(query, whereArgs);
      var batches = rows.map(_rowToBatch).toList();

      if (status != null) {
        batches = batches.where((b) => b.status == status).toList();
      }

      return Success(batches);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load batches: $e'));
    }
  }

  @override
  Future<Result<Batch>> getBatchById(BatchId id) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery('''
        SELECT b.*, m.name AS medicine_name
        FROM batches b
        LEFT JOIN medicines m ON b.medicine_id = m.id
        WHERE b.id = ?
      ''', [id.value]);

      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Batch not found.'));
      }

      return Success(_rowToBatch(rows.first));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load batch: $e'));
    }
  }

  @override
  Future<Result<Batch>> createBatch(Batch batch) async {
    try {
      final db = await _db;
      await db.insert('batches', _batchToMap(batch));
      return Success(batch);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create batch: $e'));
    }
  }

  @override
  Future<Result<Batch>> updateBatch(Batch batch) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'batches',
        _batchToMap(batch),
        where: 'id = ?',
        whereArgs: [batch.id.value],
      );

      if (rows == 0) {
        return const Failure(NotFoundFailure(message: 'Batch not found for update.'));
      }

      return Success(batch);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update batch: $e'));
    }
  }

  @override
  Future<Result<void>> deleteBatch(BatchId id) async {
    try {
      final db = await _db;
      final rows = await db.delete('batches', where: 'id = ?', whereArgs: [id.value]);

      if (rows == 0) {
        return const Failure(NotFoundFailure(message: 'Batch not found for deletion.'));
      }

      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete batch: $e'));
    }
  }

  @override
  Future<Result<List<Batch>>> getExpiringBatches({int daysThreshold = 90}) async {
    try {
      final db = await _db;
      final cutoff = DateTime.now().add(Duration(days: daysThreshold)).toIso8601String();

      final rows = await db.rawQuery('''
        SELECT b.*, m.name AS medicine_name
        FROM batches b
        LEFT JOIN medicines m ON b.medicine_id = m.id
        WHERE b.expiry_date <= ? AND b.quantity > 0
        ORDER BY b.expiry_date ASC
      ''', [cutoff]);

      final batches = rows.map(_rowToBatch).toList();
      return Success(batches);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load expiring batches: $e'));
    }
  }

  @override
  Future<Result<List<Batch>>> getBatchesByExpiry(MedicineId medicineId) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery('''
        SELECT b.*, m.name AS medicine_name
        FROM batches b
        LEFT JOIN medicines m ON b.medicine_id = m.id
        WHERE b.medicine_id = ? AND b.quantity > 0
        ORDER BY b.expiry_date ASC
      ''', [medicineId.value]);

      final batches = rows.map(_rowToBatch).toList();
      return Success(batches);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load FEFO batches: $e'));
    }
  }
}