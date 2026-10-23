import '../../../core/result/result.dart';
import 'category.dart';
import 'manufacturer.dart';

/// Combined contract for category + manufacturer master data.
abstract class CategoryRepository {
  // Categories
  Future<Result<List<Category>>> getCategories({String? searchQuery});
  Future<Result<Category>> createCategory(Category category);
  Future<Result<Category>> updateCategory(Category category);
  Future<Result<void>> deleteCategory(CategoryId id);

  /// Ensures a category with [name] exists in the master table.
  /// Case-insensitive lookup; creates if missing.
  Future<Result<Category>> ensureCategoryByName(String name);

  // Manufacturers
  Future<Result<List<Manufacturer>>> getManufacturers({String? searchQuery});
  Future<Result<Manufacturer>> createManufacturer(Manufacturer manufacturer);
  Future<Result<Manufacturer>> updateManufacturer(Manufacturer manufacturer);
  Future<Result<void>> deleteManufacturer(ManufacturerId id);

  /// Ensures a manufacturer with [name] exists in the master table.
  /// Case-insensitive lookup; creates if missing.
  Future<Result<Manufacturer>> ensureManufacturerByName(String name);
}