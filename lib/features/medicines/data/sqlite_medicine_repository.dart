import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/medicine.dart';
import '../domain/medicine_repository.dart';
import 'medicine_model.dart';

/// SQLite implementation of [MedicineRepository].
///
/// All database access is isolated here. The domain layer never
/// knows that SQLite exists.
class SqliteMedicineRepository implements MedicineRepository {
  final DatabaseHelper _dbHelper;

  SqliteMedicineRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<Result<List<Medicine>>> getMedicines({
    MedicineFilter filter = const MedicineFilter(),
  }) async {
    try {
      final db = await _db;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        whereClauses.add(
          '(name LIKE ? OR generic_name LIKE ? OR barcode LIKE ? OR manufacturer LIKE ?)',
        );
        final q = '%${filter.searchQuery}%';
        whereArgs.addAll([q, q, q, q]);
      }
      if (filter.category != null && filter.category!.isNotEmpty) {
        whereClauses.add('category = ?');
        whereArgs.add(filter.category);
      }
      if (filter.manufacturer != null && filter.manufacturer!.isNotEmpty) {
        whereClauses.add('manufacturer = ?');
        whereArgs.add(filter.manufacturer);
      }
      if (filter.status != null) {
        whereClauses.add('status = ?');
        whereArgs.add(filter.status!.name);
      }
      if (filter.prescriptionOnly == true) {
        whereClauses.add('prescription_required = 1');
      }

      final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final rows = await db.query(
        'medicines',
        where: where,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'name ASC',
      );

      final medicines = rows
          .map((row) => MedicineModel.fromMap(row).toDomain())
          .toList();
      return Success(medicines);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load medicines: $e'));
    }
  }

  @override
  Future<Result<Medicine>> getMedicineById(MedicineId id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );

      if (rows.isEmpty) {
        return const Failure(NotFoundFailure(message: 'Medicine not found.'));
      }

      return Success(MedicineModel.fromMap(rows.first).toDomain());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load medicine: $e'));
    }
  }

  @override
  Future<Result<Medicine>> getMedicineByBarcode(String barcode) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'medicines',
        where: 'barcode = ?',
        whereArgs: [barcode],
        limit: 1,
      );

      if (rows.isEmpty) {
        return const Failure(
          NotFoundFailure(message: 'No medicine found for this barcode.'),
        );
      }

      return Success(MedicineModel.fromMap(rows.first).toDomain());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Barcode lookup failed: $e'));
    }
  }

  @override
  Future<Result<Medicine>> createMedicine(Medicine medicine) async {
    try {
      final db = await _db;

      // Check barcode uniqueness
      if (medicine.barcode != null) {
        final existing = await db.query(
          'medicines',
          where: 'barcode = ?',
          whereArgs: [medicine.barcode!.value],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return const Failure(
            ValidationFailure(
              message: 'This barcode is already assigned to another medicine.',
            ),
          );
        }
      }

      final model = MedicineModel.fromDomain(medicine);
      await db.insert('medicines', model.toMap());
      return Success(medicine);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        return const Failure(
          ValidationFailure(
            message: 'A medicine with this barcode already exists.',
          ),
        );
      }
      return Failure(DatabaseFailure(message: 'Failed to save medicine: $e'));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save medicine: $e'));
    }
  }

  @override
  Future<Result<Medicine>> updateMedicine(Medicine medicine) async {
    try {
      final db = await _db;

      // Check barcode uniqueness (exclude self)
      if (medicine.barcode != null) {
        final existing = await db.query(
          'medicines',
          where: 'barcode = ? AND id != ?',
          whereArgs: [medicine.barcode!.value, medicine.id.value],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return const Failure(
            ValidationFailure(
              message: 'This barcode is already assigned to another medicine.',
            ),
          );
        }
      }

      final model = MedicineModel.fromDomain(medicine);
      final rows = await db.update(
        'medicines',
        model.toMap(),
        where: 'id = ?',
        whereArgs: [medicine.id.value],
      );

      if (rows == 0) {
        return const Failure(
          NotFoundFailure(message: 'Medicine not found for update.'),
        );
      }

      return Success(medicine);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update medicine: $e'));
    }
  }

  @override
  Future<Result<void>> deleteMedicine(MedicineId id) async {
    try {
      final db = await _db;
      final rows = await db.delete(
        'medicines',
        where: 'id = ?',
        whereArgs: [id.value],
      );

      if (rows == 0) {
        return const Failure(
          NotFoundFailure(message: 'Medicine not found for deletion.'),
        );
      }

      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete medicine: $e'));
    }
  }

  @override
  Future<Result<List<String>>> getCategories() async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        'SELECT DISTINCT category FROM medicines WHERE category != "" ORDER BY category ASC',
      );
      final categories = rows.map((r) => r['category'] as String).toList();
      return Success(categories);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load categories: $e'));
    }
  }

  @override
  Future<Result<List<String>>> getManufacturers() async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        'SELECT DISTINCT manufacturer FROM medicines WHERE manufacturer != "" ORDER BY manufacturer ASC',
      );
      final manufacturers = rows
          .map((r) => r['manufacturer'] as String)
          .toList();
      return Success(manufacturers);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to load manufacturers: $e'),
      );
    }
  }
}
