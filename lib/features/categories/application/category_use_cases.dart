import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/category.dart';
import '../domain/manufacturer.dart';
import '../domain/category_repository.dart';

class GetCategoriesUseCase {
  final CategoryRepository _repo;
  const GetCategoriesUseCase(this._repo);

  Future<Result<List<Category>>> execute({String? searchQuery}) =>
      _repo.getCategories(searchQuery: searchQuery);
}

class SaveCategoryUseCase {
  final CategoryRepository _repo;
  const SaveCategoryUseCase(this._repo);

  Future<Result<Category>> execute(Category c, {bool isNew = true}) async {
    if (c.name.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Category name is required.'));
    }
    return isNew ? _repo.createCategory(c) : _repo.updateCategory(c);
  }
}

class DeleteCategoryUseCase {
  final CategoryRepository _repo;
  const DeleteCategoryUseCase(this._repo);

  Future<Result<void>> execute(CategoryId id) => _repo.deleteCategory(id);
}

class GetManufacturersUseCase {
  final CategoryRepository _repo;
  const GetManufacturersUseCase(this._repo);

  Future<Result<List<Manufacturer>>> execute({String? searchQuery}) =>
      _repo.getManufacturers(searchQuery: searchQuery);
}

class SaveManufacturerUseCase {
  final CategoryRepository _repo;
  const SaveManufacturerUseCase(this._repo);

  Future<Result<Manufacturer>> execute(Manufacturer m, {bool isNew = true}) async {
    if (m.name.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Manufacturer name is required.'));
    }
    return isNew ? _repo.createManufacturer(m) : _repo.updateManufacturer(m);
  }
}

class DeleteManufacturerUseCase {
  final CategoryRepository _repo;
  const DeleteManufacturerUseCase(this._repo);

  Future<Result<void>> execute(ManufacturerId id) => _repo.deleteManufacturer(id);
}