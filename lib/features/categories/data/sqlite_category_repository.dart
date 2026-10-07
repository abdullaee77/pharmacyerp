import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/category.dart';
import '../domain/manufacturer.dart';
import '../domain/category_repository.dart';

class SqliteCategoryRepository implements CategoryRepository {
  final DatabaseHelper _dbHelper;

  SqliteCategoryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  // ─── CATEGORIES ─────────────────────────────────────────────

  @override
  Future<Result<List<Category>>> getCategories({String? searchQuery}) async {
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'name LIKE ? OR description LIKE ?';
        args = ['%$searchQuery%', '%$searchQuery%'];
      }

      final rows = await db.query(
        'categories',
        where: where,
        whereArgs: args,
        orderBy: 'name ASC',
      );

      final list = rows.map((r) => Category(
        id: CategoryId(r['id'] as String),
        name: r['name'] as String,
        description: r['description'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      )).toList();

      return Success(list);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load categories: $e'));
    }
  }

  @override
  Future<Result<Category>> createCategory(Category c) async {
    try {
      final db = await _db;
      await db.insert('categories', {
        'id': c.id.value,
        'name': c.name,
        'description': c.description,
        'created_at': c.createdAt.toIso8601String(),
      });
      return Success(c);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save category: $e'));
    }
  }

  @override
  Future<Result<Category>> updateCategory(Category c) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'categories',
        {
          'name': c.name,
          'description': c.description,
        },
        where: 'id = ?',
        whereArgs: [c.id.value],
      );
      if (rows == 0) return const Failure(NotFoundFailure(message: 'Category not found.'));
      return Success(c);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update category: $e'));
    }
  }

  @override
  Future<Result<void>> deleteCategory(CategoryId id) async {
    try {
      final db = await _db;
      final rows = await db.delete('categories', where: 'id = ?', whereArgs: [id.value]);
      if (rows == 0) return const Failure(NotFoundFailure(message: 'Category not found.'));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete category: $e'));
    }
  }

  // ─── MANUFACTURERS ──────────────────────────────────────────

  @override
  Future<Result<List<Manufacturer>>> getManufacturers({String? searchQuery}) async {
    try {
      final db = await _db;
      String? where;
      List<dynamic>? args;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where = 'name LIKE ? OR contact LIKE ?';
        args = ['%$searchQuery%', '%$searchQuery%'];
      }

      final rows = await db.query(
        'manufacturers',
        where: where,
        whereArgs: args,
        orderBy: 'name ASC',
      );

      final list = rows.map((r) => Manufacturer(
        id: ManufacturerId(r['id'] as String),
        name: r['name'] as String,
        contact: r['contact'] as String? ?? '',
        address: r['address'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      )).toList();

      return Success(list);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load manufacturers: $e'));
    }
  }

  @override
  Future<Result<Manufacturer>> createManufacturer(Manufacturer m) async {
    try {
      final db = await _db;
      await db.insert('manufacturers', {
        'id': m.id.value,
        'name': m.name,
        'contact': m.contact,
        'address': m.address,
        'created_at': m.createdAt.toIso8601String(),
      });
      return Success(m);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save manufacturer: $e'));
    }
  }

  @override
  Future<Result<Manufacturer>> updateManufacturer(Manufacturer m) async {
    try {
      final db = await _db;
      final rows = await db.update(
        'manufacturers',
        {
          'name': m.name,
          'contact': m.contact,
          'address': m.address,
        },
        where: 'id = ?',
        whereArgs: [m.id.value],
      );
      if (rows == 0) return const Failure(NotFoundFailure(message: 'Manufacturer not found.'));
      return Success(m);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update manufacturer: $e'));
    }
  }

  @override
  Future<Result<void>> deleteManufacturer(ManufacturerId id) async {
    try {
      final db = await _db;
      final rows = await db.delete('manufacturers', where: 'id = ?', whereArgs: [id.value]);
      if (rows == 0) return const Failure(NotFoundFailure(message: 'Manufacturer not found.'));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to delete manufacturer: $e'));
    }
  }
}