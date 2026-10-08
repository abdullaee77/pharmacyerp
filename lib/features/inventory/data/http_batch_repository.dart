import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/batch.dart';
import '../domain/batch_repository.dart';

class HttpBatchRepository implements BatchRepository {
  final ApiClient _api;

  HttpBatchRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

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
    final where = <String>[];
    final args = <dynamic>[];

    if (medicineId != null) {
      where.add('b.medicine_id = ?');
      args.add(medicineId.value);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(b.batch_number LIKE ? OR m.name LIKE ? OR m.generic_name LIKE ?)');
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }

    final sql = '''
      SELECT b.*, m.name AS medicine_name
      FROM batches b
      LEFT JOIN medicines m ON b.medicine_id = m.id
      ${where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : ''}
      ORDER BY b.expiry_date ASC
    ''';

    final res = await _api.rawQuery(sql: sql, args: args.isEmpty ? null : args);
    return res.fold(
      onSuccess: (rows) {
        var batches = rows.map(_rowToBatch).toList();
        if (status != null) {
          batches = batches.where((b) => b.status == status).toList();
        }
        return Success(batches);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Batch>> getBatchById(BatchId id) async {
    final sql = '''
      SELECT b.*, m.name AS medicine_name
      FROM batches b
      LEFT JOIN medicines m ON b.medicine_id = m.id
      WHERE b.id = ?
    ''';
    final res = await _api.rawQuery(sql: sql, args: [id.value]);
    return res.fold(
      onSuccess: (rows) => rows.isEmpty
          ? const Failure(NotFoundFailure(message: 'Batch not found.'))
          : Success(_rowToBatch(rows.first)),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Batch>> createBatch(Batch batch) async {
    final res = await _api.insert(table: 'batches', data: _batchToMap(batch));
    return res.fold(onSuccess: (_) => Success(batch), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<Batch>> updateBatch(Batch batch) async {
    final res = await _api.update(table: 'batches', data: _batchToMap(batch), where: 'id = ?', args: [batch.id.value]);
    return res.fold(
      onSuccess: (c) => c == 0 ? const Failure(NotFoundFailure(message: 'Batch not found.')) : Success(batch),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteBatch(BatchId id) async {
    final res = await _api.delete(table: 'batches', where: 'id = ?', args: [id.value]);
    return res.fold(
      onSuccess: (c) => c == 0 ? const Failure(NotFoundFailure(message: 'Batch not found.')) : const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<Batch>>> getExpiringBatches({int daysThreshold = 90}) async {
    final cutoff = DateTime.now().add(Duration(days: daysThreshold)).toIso8601String();
    final sql = '''
      SELECT b.*, m.name AS medicine_name
      FROM batches b
      LEFT JOIN medicines m ON b.medicine_id = m.id
      WHERE b.expiry_date <= ? AND b.quantity > 0
      ORDER BY b.expiry_date ASC
    ''';
    final res = await _api.rawQuery(sql: sql, args: [cutoff]);
    return res.fold(onSuccess: (rows) => Success(rows.map(_rowToBatch).toList()), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<List<Batch>>> getBatchesByExpiry(MedicineId medicineId) async {
    final sql = '''
      SELECT b.*, m.name AS medicine_name
      FROM batches b
      LEFT JOIN medicines m ON b.medicine_id = m.id
      WHERE b.medicine_id = ? AND b.quantity > 0
      ORDER BY b.expiry_date ASC
    ''';
    final res = await _api.rawQuery(sql: sql, args: [medicineId.value]);
    return res.fold(onSuccess: (rows) => Success(rows.map(_rowToBatch).toList()), onFailure: (f) => Failure(f));
  }
}