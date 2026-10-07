import 'package:sqflite/sqflite.dart' as sql;
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../inventory/data/sqlite_batch_repository.dart';
import '../../inventory/domain/batch.dart';
import '../../medicines/data/medicine_model.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/pos_models.dart';
import '../domain/pos_repository.dart';

class SqlitePosRepository implements PosRepository {
  final DatabaseHelper _dbHelper;
  final SqliteBatchRepository _batchRepo;

  SqlitePosRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _batchRepo = SqliteBatchRepository(dbHelper: dbHelper);

  Future<sql.Database> get _db => _dbHelper.database;

  @override
  Future<Result<List<PosSearchResult>>> searchMedicines(
      String query, {
        int limit = 20,
      }) async {
    try {
      final db = await _db;
      final q = '%${query.trim()}%';

      // Reads max of inventory_stocks or the sum of active batches
      final String sqlQuery = '''
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

      final rows = await db.rawQuery(sqlQuery, [q, q, q, q, limit]);

      final results = rows.map((r) {
        final medicine = MedicineModel.fromMap(r).toDomain();
        final stock = r['current_stock'] as int;
        return PosSearchResult(medicine: medicine, currentStock: stock);
      }).toList();

      return Success(results);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'POS search failed: $e'));
    }
  }

  @override
  Future<Result<PosSearchResult>> findByBarcode(String barcode) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery('''
        SELECT m.*, 
          MAX(
            COALESCE(s.quantity, 0), 
            COALESCE((SELECT SUM(b.quantity) FROM batches b WHERE b.medicine_id = m.id), 0)
          ) AS current_stock
        FROM medicines m
        LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
        WHERE m.barcode = ? AND m.status = 'active'
        LIMIT 1
      ''', [barcode.trim()]);

      if (rows.isEmpty) {
        return const Failure(
          NotFoundFailure(message: 'No medicine assigned to this barcode.'),
        );
      }

      final row = rows.first;
      final med = MedicineModel.fromMap(row).toDomain();
      final stock = row['current_stock'] as int;
      return Success(PosSearchResult(medicine: med, currentStock: stock));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Barcode lookup failed: $e'));
    }
  }

  @override
  Future<Result<List<Batch>>> getAvailableBatches(MedicineId medicineId) {
    return _batchRepo.getBatchesByExpiry(medicineId);
  }
}