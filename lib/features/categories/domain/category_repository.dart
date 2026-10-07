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

  // Manufacturers
  Future<Result<List<Manufacturer>>> getManufacturers({String? searchQuery});
  Future<Result<Manufacturer>> createManufacturer(Manufacturer manufacturer);
  Future<Result<Manufacturer>> updateManufacturer(Manufacturer manufacturer);
  Future<Result<void>> deleteManufacturer(ManufacturerId id);
}