import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/medicine.dart';
import '../domain/medicine_repository.dart';
import 'medicine_model.dart';

class HttpMedicineRepository implements MedicineRepository {
  final ApiClient _api;

  HttpMedicineRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<Result<List<Medicine>>> getMedicines({
    MedicineFilter filter = const MedicineFilter(),
  }) async {
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR generic_name LIKE ? OR barcode LIKE ? OR manufacturer LIKE ?)');
      final q = '%${filter.searchQuery}%';
      args.addAll([q, q, q, q]);
    }
    if (filter.category != null && filter.category!.isNotEmpty) {
      whereClauses.add('category = ?');
      args.add(filter.category);
    }
    if (filter.manufacturer != null && filter.manufacturer!.isNotEmpty) {
      whereClauses.add('manufacturer = ?');
      args.add(filter.manufacturer);
    }
    if (filter.status != null) {
      whereClauses.add('status = ?');
      args.add(filter.status!.name);
    }
    if (filter.prescriptionOnly == true) {
      whereClauses.add('prescription_required = 1');
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final result = await _api.query(
      table: 'medicines', where: where,
      args: args.isNotEmpty ? args : null, orderBy: 'name ASC',
    );

    return result.fold(
      onSuccess: (rows) => Success(rows.map((r) => MedicineModel.fromMap(r).toDomain()).toList()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Medicine>> getMedicineById(MedicineId id) async {
    final result = await _api.query(table: 'medicines', where: 'id = ?', args: [id.value], limit: 1);
    return result.fold(
      onSuccess: (rows) => rows.isEmpty
          ? const Failure(NotFoundFailure(message: 'Medicine not found.'))
          : Success(MedicineModel.fromMap(rows.first).toDomain()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Medicine>> getMedicineByBarcode(String barcode) async {
    final result = await _api.query(table: 'medicines', where: 'barcode = ?', args: [barcode], limit: 1);
    return result.fold(
      onSuccess: (rows) => rows.isEmpty
          ? const Failure(NotFoundFailure(message: 'No medicine found for this barcode.'))
          : Success(MedicineModel.fromMap(rows.first).toDomain()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Medicine>> createMedicine(Medicine medicine) async {
    final model = MedicineModel.fromDomain(medicine);
    final result = await _api.insert(table: 'medicines', data: model.toMap());
    return result.fold(
      onSuccess: (_) => Success(medicine),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Medicine>> updateMedicine(Medicine medicine) async {
    final model = MedicineModel.fromDomain(medicine);
    final result = await _api.update(
      table: 'medicines', data: model.toMap(),
      where: 'id = ?', args: [medicine.id.value],
    );
    return result.fold(
      onSuccess: (count) => count == 0
          ? const Failure(NotFoundFailure(message: 'Medicine not found for update.'))
          : Success(medicine),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteMedicine(MedicineId id) async {
    final result = await _api.delete(table: 'medicines', where: 'id = ?', args: [id.value]);
    return result.fold(
      onSuccess: (count) => count == 0
          ? const Failure(NotFoundFailure(message: 'Medicine not found for deletion.'))
          : const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<String>>> getCategories() async {
    final result = await _api.rawQuery(
      sql: 'SELECT DISTINCT category FROM medicines WHERE category != "" ORDER BY category ASC',
    );
    return result.fold(
      onSuccess: (rows) => Success(rows.map((r) => r['category'] as String).toList()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<List<String>>> getManufacturers() async {
    final result = await _api.rawQuery(
      sql: 'SELECT DISTINCT manufacturer FROM medicines WHERE manufacturer != "" ORDER BY manufacturer ASC',
    );
    return result.fold(
      onSuccess: (rows) => Success(rows.map((r) => r['manufacturer'] as String).toList()),
      onFailure: (f) => Failure(f),
    );
  }
}