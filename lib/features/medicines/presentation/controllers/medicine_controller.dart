import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/data/database_helper.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../../categories/data/sqlite_category_repository.dart';  // ← NEW
import '../../../categories/domain/category_repository.dart';        // ← NEW
import '../../../inventory/domain/batch.dart';
import '../../domain/medicine.dart';
import '../../domain/medicine_repository.dart';
import '../widgets/medicine_form_dialog.dart';

class MedicineController extends ChangeNotifier {
  final MedicineRepository _repository;
  final DatabaseHelper _dbHelper;
  late final CategoryRepository _categoryRepo;  // ← NEW

  StreamSubscription<AppEvent>? _eventSubscription;

  MedicineController({
    required MedicineRepository repository,
    DatabaseHelper? dbHelper,
  })  : _repository = repository,
        _dbHelper = dbHelper ?? DatabaseHelper.instance {
    _categoryRepo = SqliteCategoryRepository(dbHelper: _dbHelper);  // ← NEW

    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      if (event == AppEvent.medicineUpdated ||
          event == AppEvent.purchaseCompleted ||
          event == AppEvent.inventoryAdjusted) {
        loadMedicines(silent: true);
      }
    });
  }

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

  Future<void> loadMedicines({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _repository.getMedicines();
    await loadFilterOptions();

    result.fold(
      onSuccess: (data) {
        _medicines = data;
        _error = null;
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

  // ─── NEW: Sync category & manufacturer to master tables ────────────────

  Future<void> _syncMasterData(Medicine medicine) async {
    if (medicine.category.trim().isNotEmpty) {
      await _categoryRepo.ensureCategoryByName(medicine.category);
    }
    if (medicine.manufacturer.trim().isNotEmpty) {
      await _categoryRepo.ensureManufacturerByName(medicine.manufacturer);
    }
  }

  // ─── BULK OPERATIONS ───────────────────────────────────────────────────

  Future<String> bulkCreateMedicines(List<Medicine> medicinesList) async {
    var ok = 0;
    var fail = 0;
    final errors = <String>[];

    for (final m in medicinesList) {
      await _syncMasterData(m);  // ← NEW
      final result = await _repository.createMedicine(m);
      result.fold(
        onSuccess: (_) => ok++,
        onFailure: (f) {
          fail++;
          errors.add('${m.name}: ${f.message}');
        },
      );
    }

    await loadMedicines();
    AppEventBus.instance.fire(AppEvent.medicineUpdated);

    if (fail == 0) {
      return 'Imported $ok medicines successfully.';
    }
    return 'Imported $ok, failed $fail.\n${errors.take(3).join("\n")}';
  }

  Future<String> bulkUpdateMedicines(List<Medicine> medicinesList) async {
    var ok = 0;
    for (final m in medicinesList) {
      await _syncMasterData(m);  // ← NEW
      final result = await _repository.updateMedicine(m);
      if (result.isSuccess) ok++;
    }
    await loadMedicines();
    AppEventBus.instance.fire(AppEvent.medicineUpdated);
    return 'Successfully updated $ok medicines.';
  }

  // ─── SINGLE CREATE / UPDATE ────────────────────────────────────────────

  Future<String?> createMedicineWithStock(MedicineCreationResult result) async {
    await _syncMasterData(result.medicine);  // ← NEW

    final medResult = await _repository.createMedicine(result.medicine);
    final errorMsg = medResult.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;

    final stock = result.openingStock;
    if (stock != null) {
      try {
        final db = await _dbHelper.database;
        final medId = result.medicine.id.value;
        final now = DateTime.now().toIso8601String();

        await db.transaction((txn) async {
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
    AppEventBus.instance.fire(AppEvent.medicineUpdated);
    if (stock != null) {
      AppEventBus.instance.fire(AppEvent.inventoryAdjusted);
      AppEventBus.instance.fire(AppEvent.batchChanged);
    }
    return null;
  }

  Future<String?> createMedicine(Medicine medicine) async {
    await _syncMasterData(medicine);  // ← NEW

    final result = await _repository.createMedicine(medicine);
    final errorMsg = result.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;
    await loadMedicines();
    AppEventBus.instance.fire(AppEvent.medicineUpdated);
    return null;
  }

  Future<String?> updateMedicine(Medicine medicine) async {
    await _syncMasterData(medicine);  // ← NEW

    final result = await _repository.updateMedicine(medicine);
    final errorMsg = result.fold(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (errorMsg != null) return errorMsg;
    await loadMedicines();
    AppEventBus.instance.fire(AppEvent.medicineUpdated);
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
    AppEventBus.instance.fire(AppEvent.medicineUpdated);
    return null;
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}