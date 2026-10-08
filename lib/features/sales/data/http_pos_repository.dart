import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../inventory/domain/batch.dart';
import '../../inventory/domain/batch_repository.dart';
import '../../medicines/data/medicine_model.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/pos_models.dart';
import '../domain/pos_repository.dart';

class HttpPosRepository implements PosRepository {
  final ApiClient _api;
  final BatchRepository _batchRepo;

  HttpPosRepository({ApiClient? api, required BatchRepository batchRepo})
      : _api = api ?? ApiClient.instance,
        _batchRepo = batchRepo;

  @override
  Future<Result<List<PosSearchResult>>> searchMedicines(String query, {int limit = 20}) async {
    final q = '%${query.trim()}%';
    final sql = '''
      SELECT m.*, 
        MAX(
          COALESCE(s.quantity, 0), 
          COALESCE((SELECT SUM(b.quantity) FROM batches b WHERE b.medicine_id = m.id), 0)
        ) AS current_stock
      FROM medicines m
      LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
      WHERE (m.name LIKE ? OR m.generic_name LIKE ? OR m.barcode LIKE ? OR m.manufacturer LIKE ?)
        AND m.status = 'active'
      ORDER BY m.name ASC
      LIMIT ?
    ''';

    final res = await _api.rawQuery(sql: sql, args: [q, q, q, q, limit]);
    return res.fold(
      onSuccess: (rows) {
        final results = rows.map((r) {
          final medicine = MedicineModel.fromMap(r).toDomain();
          final stock = r['current_stock'] as int? ?? 0;
          return PosSearchResult(medicine: medicine, currentStock: stock);
        }).toList();
        return Success(results);
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<PosSearchResult>> findByBarcode(String barcode) async {
    final sql = '''
      SELECT m.*, 
        MAX(
          COALESCE(s.quantity, 0), 
          COALESCE((SELECT SUM(b.quantity) FROM batches b WHERE b.medicine_id = m.id), 0)
        ) AS current_stock
      FROM medicines m
      LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
      WHERE m.barcode = ? AND m.status = 'active'
      LIMIT 1
    ''';
    final res = await _api.rawQuery(sql: sql, args: [barcode.trim()]);
    return res.fold(
      onSuccess: (rows) {
        if (rows.isEmpty) return const Failure(NotFoundFailure(message: 'No medicine assigned to this barcode.'));
        final row = rows.first;
        final med = MedicineModel.fromMap(row).toDomain();
        final stock = row['current_stock'] as int? ?? 0;
        return Success(PosSearchResult(medicine: med, currentStock: stock));
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<Batch>>> getAvailableBatches(MedicineId medicineId) {
    return _batchRepo.getBatchesByExpiry(medicineId);
  }
}