import 'package:flutter/material.dart';
import '../../domain/category.dart';
import '../../domain/manufacturer.dart';
import '../../domain/category_repository.dart';
import '../../application/category_use_cases.dart';

class CategoryController extends ChangeNotifier {
  final GetCategoriesUseCase _getCategories;
  final SaveCategoryUseCase _saveCategory;
  final DeleteCategoryUseCase _deleteCategory;
  final GetManufacturersUseCase _getManufacturers;
  final SaveManufacturerUseCase _saveManufacturer;
  final DeleteManufacturerUseCase _deleteManufacturer;

  CategoryController({required CategoryRepository repository})
      : _getCategories = GetCategoriesUseCase(repository),
        _saveCategory = SaveCategoryUseCase(repository),
        _deleteCategory = DeleteCategoryUseCase(repository),
        _getManufacturers = GetManufacturersUseCase(repository),
        _saveManufacturer = SaveManufacturerUseCase(repository),
        _deleteManufacturer = DeleteManufacturerUseCase(repository);

  List<Category> _categories = [];
  List<Manufacturer> _manufacturers = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  List<Manufacturer> get manufacturers => _manufacturers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final catResult = await _getCategories.execute();
    final mfrResult = await _getManufacturers.execute();

    catResult.fold(
      onSuccess: (d) => _categories = d,
      onFailure: (f) => _error = f.message,
    );
    mfrResult.fold(
      onSuccess: (d) => _manufacturers = d,
      onFailure: (f) => _error = f.message,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> saveCategory(Category c, {bool isNew = true}) async {
    final result = await _saveCategory.execute(c, isNew: isNew);
    return result.fold(
      onSuccess: (_) {
        loadAll();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteCategory(CategoryId id) async {
    final result = await _deleteCategory.execute(id);
    return result.fold(
      onSuccess: (_) {
        loadAll();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> saveManufacturer(Manufacturer m, {bool isNew = true}) async {
    final result = await _saveManufacturer.execute(m, isNew: isNew);
    return result.fold(
      onSuccess: (_) {
        loadAll();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteManufacturer(ManufacturerId id) async {
    final result = await _deleteManufacturer.execute(id);
    return result.fold(
      onSuccess: (_) {
        loadAll();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }
}