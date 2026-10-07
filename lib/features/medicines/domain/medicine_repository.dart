import '../../../core/result/result.dart';
import 'medicine.dart';

/// Filter criteria for medicine queries.
class MedicineFilter {
  final String? searchQuery;
  final String? category;
  final String? manufacturer;
  final MedicineStatus? status;
  final bool? prescriptionOnly;

  const MedicineFilter({
    this.searchQuery,
    this.category,
    this.manufacturer,
    this.status,
    this.prescriptionOnly,
  });

  bool get isEmpty =>
      searchQuery == null &&
          category == null &&
          manufacturer == null &&
          status == null &&
          prescriptionOnly == null;
}

/// Pure domain repository interface for Medicine aggregate.
///
/// Implemented in the data layer. Zero dependencies on Flutter or SQLite.
abstract class MedicineRepository {
  /// Fetch all medicines matching the given filter.
  Future<Result<List<Medicine>>> getMedicines({MedicineFilter filter = const MedicineFilter()});

  /// Fetch a single medicine by ID.
  Future<Result<Medicine>> getMedicineById(MedicineId id);

  /// Fetch a medicine by barcode. Returns NotFoundFailure if none.
  Future<Result<Medicine>> getMedicineByBarcode(String barcode);

  /// Create a new medicine. Validates barcode uniqueness.
  Future<Result<Medicine>> createMedicine(Medicine medicine);

  /// Update an existing medicine. Preserves identity.
  Future<Result<Medicine>> updateMedicine(Medicine medicine);

  /// Delete a medicine by ID.
  Future<Result<void>> deleteMedicine(MedicineId id);

  /// Get distinct categories for filter dropdowns.
  Future<Result<List<String>>> getCategories();

  /// Get distinct manufacturers for filter dropdowns.
  Future<Result<List<String>>> getManufacturers();
}