import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/category.dart';
import '../domain/manufacturer.dart';
import '../domain/category_repository.dart';

class HttpCategoryRepository implements CategoryRepository {
  final ApiClient _api;

  HttpCategoryRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  // ── Categories ──

  @override
  Future<Result<List<Category>>> getCategories({String? searchQuery}) async {
    final where = searchQuery != null && searchQuery.isNotEmpty
        ? 'name LIKE ? OR description LIKE ?'
        : null;
    final args = searchQuery != null && searchQuery.isNotEmpty
        ? ['%$searchQuery%', '%$searchQuery%']
        : null;

    final res = await _api.query(
      table: 'categories',
      where: where,
      args: args,
      orderBy: 'name ASC',
    );
    return res.fold(
      onSuccess: (rows) => Success(rows
          .map((r) => Category(
        id: CategoryId(r['id'] as String),
        name: r['name'] as String,
        description: r['description'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      ))
          .toList()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Category>> createCategory(Category c) async {
    final res = await _api.insert(table: 'categories', data: {
      'id': c.id.value,
      'name': c.name,
      'description': c.description,
      'created_at': c.createdAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => Success(c), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<Category>> updateCategory(Category c) async {
    final res = await _api.update(
      table: 'categories',
      data: {'name': c.name, 'description': c.description},
      where: 'id = ?',
      args: [c.id.value],
    );
    return res.fold(
      onSuccess: (n) => n == 0
          ? const Failure(NotFoundFailure(message: 'Category not found.'))
          : Success(c),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteCategory(CategoryId id) async {
    final res = await _api.delete(
      table: 'categories',
      where: 'id = ?',
      args: [id.value],
    );
    return res.fold(
      onSuccess: (n) => n == 0
          ? const Failure(NotFoundFailure(message: 'Category not found.'))
          : const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  // ── Manufacturers ──

  @override
  Future<Result<List<Manufacturer>>> getManufacturers({String? searchQuery}) async {
    final where = searchQuery != null && searchQuery.isNotEmpty
        ? 'name LIKE ? OR contact LIKE ?'
        : null;
    final args = searchQuery != null && searchQuery.isNotEmpty
        ? ['%$searchQuery%', '%$searchQuery%']
        : null;

    final res = await _api.query(
      table: 'manufacturers',
      where: where,
      args: args,
      orderBy: 'name ASC',
    );
    return res.fold(
      onSuccess: (rows) => Success(rows
          .map((r) => Manufacturer(
        id: ManufacturerId(r['id'] as String),
        name: r['name'] as String,
        contact: r['contact'] as String? ?? '',
        address: r['address'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      ))
          .toList()),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<Manufacturer>> createManufacturer(Manufacturer m) async {
    final res = await _api.insert(table: 'manufacturers', data: {
      'id': m.id.value,
      'name': m.name,
      'contact': m.contact,
      'address': m.address,
      'created_at': m.createdAt.toIso8601String(),
    });
    return res.fold(onSuccess: (_) => Success(m), onFailure: (f) => Failure(f));
  }

  @override
  Future<Result<Manufacturer>> updateManufacturer(Manufacturer m) async {
    final res = await _api.update(
      table: 'manufacturers',
      data: {
        'name': m.name,
        'contact': m.contact,
        'address': m.address,
      },
      where: 'id = ?',
      args: [m.id.value],
    );
    return res.fold(
      onSuccess: (n) => n == 0
          ? const Failure(NotFoundFailure(message: 'Manufacturer not found.'))
          : Success(m),
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<void>> deleteManufacturer(ManufacturerId id) async {
    final res = await _api.delete(
      table: 'manufacturers',
      where: 'id = ?',
      args: [id.value],
    );
    return res.fold(
      onSuccess: (n) => n == 0
          ? const Failure(NotFoundFailure(message: 'Manufacturer not found.'))
          : const Success(null),
      onFailure: (f) => Failure(f),
    );
  }
}