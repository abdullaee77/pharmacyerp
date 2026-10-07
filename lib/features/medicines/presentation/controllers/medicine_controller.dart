import 'package:flutter/material.dart';
import 'package:pharmacy/core/data/database_helper.dart'; // Robust absolute package import
import '../../../inventory/domain/batch.dart';
import '../../domain/medicine.dart';
import '../../domain/medicine_repository.dart';
import '../widgets/medicine_form_dialog.dart';

class MedicineController extends ChangeNotifier {
  final MedicineRepository _repository;
  final DatabaseHelper _dbHelper;

  MedicineController({
    required MedicineRepository repository,
    DatabaseHelper? dbHelper,
  })  : _repository = repository,
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  List<Medicine> _medicines = [];
  List<String> _categories = [];
  List<String> _manufacturers = [];
  bool _isLoading = false;
  String? _error;
  String _filter = '';

  List<Medicine> get medicines => _medicines;
  List<String> get categories => _categories;
  List<String> get manufacturers => _manufacturers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filter => _filter;

  Future<void> loadMedicines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Changed from getAllMedicines() to getMedicines() to match MedicineRepository signature
    final result = await _repository.getMedicines();
    result.fold(
      onSuccess: (data) {
        _medicines = data;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadFilterOptions() async {
    final cats = await _repository.getCategories();
    final manufs = await _repository.getManufacturers();
    cats.fold(onSuccess: (d) => _categories = d, onFailure: (_) {});
    manufs.fold(onSuccess: (d) => _manufacturers = d, onFailure: (_) {});
    notifyListeners();
  }

  void search(String query) {
    _filter = query;
    notifyListeners();
  }

  void filterByCategory(String? category) {
    _filter = category ?? '';
    notifyListeners();
  }

  /// Creates a medicine and optionally initializes opening stock.
  /// Returns null on success, or an error message on failure.
  Future<String?> createMedicineWithStock(MedicineCreationResult result) async {
    // 1. Save medicine master record
    final medResult = await _repository.createMedicine(result.medicine);
    final errorMsg = medResult.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;

    // 2. If opening stock info was provided, create batch + inventory stock
    final stock = result.openingStock;
    if (stock != null) {
      try {
        final db = await _dbHelper.database;
        final medId = result.medicine.id.value;
        final now = DateTime.now().toIso8601String();

        await db.transaction((txn) async {
          // Create batch record
          final batchId = BatchId.generate();
          await txn.insert('batches', {
            'id': batchId.value,
            'medicine_id': medId,
            'batch_number': stock.batchNumber,
            'expiry_date': stock.expiryDate.toIso8601String(),
            'quantity': stock.quantity,
            'purchase_price': result.medicine.purchasePrice.paisa,
            'selling_price': result.medicine.sellingPrice.paisa,
            'created_at': now,
            'updated_at': now,
          });

          // Create / update inventory stock
          final existing = await txn.query(
            'inventory_stocks',
            where: 'medicine_id = ?',
            whereArgs: [medId],
          );

          if (existing.isNotEmpty) {
            await txn.update(
              'inventory_stocks',
              {'quantity': (existing.first['quantity'] as int) + stock.quantity},
              where: 'medicine_id = ?',
              whereArgs: [medId],
            );
          } else {
            await txn.insert('inventory_stocks', {
              'medicine_id': medId,
              'quantity': stock.quantity,
            });
          }

          // Write movement log
          await txn.insert('inventory_movements', {
            'id': 'mov_${DateTime.now().microsecondsSinceEpoch}',
            'medicine_id': medId,
            'batch_id': batchId.value,
            'type': 'adjustment',
            'quantity_changed': stock.quantity,
            'reason': 'opening_stock',
            'reference': 'Initial stock on medicine creation',
            'operator_name': 'System',
            'created_at': now,
          });
        });
      } catch (e) {
        return 'Medicine saved but stock init failed: $e';
      }
    }

    await loadMedicines();
    return null;
  }

  /// Legacy method — still works for edits without stock.
  Future<String?> createMedicine(Medicine medicine) async {
    final result = await _repository.createMedicine(medicine);
    final errorMsg = result.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;
    await loadMedicines();
    return null;
  }

  Future<String?> updateMedicine(Medicine medicine) async {
    final result = await _repository.updateMedicine(medicine);
    final errorMsg = result.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;
    await loadMedicines();
    return null;
  }

  Future<String?> deleteMedicine(MedicineId id) async {
    final result = await _repository.deleteMedicine(id);
    final errorMsg = result.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;
    await loadMedicines();
    return null;
  }
}