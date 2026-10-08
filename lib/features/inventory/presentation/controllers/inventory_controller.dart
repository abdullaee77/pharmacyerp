import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../../medicines/domain/medicine.dart';
import '../../domain/inventory_movement.dart';
import '../../domain/inventory_repository.dart';
import '../../application/inventory_use_cases.dart';

class InventoryController extends ChangeNotifier {
  final GetStockLevelsUseCase _getStockLevels;
  final AdjustStockUseCase _adjustStock;
  final GetMovementsUseCase _getMovements;

  StreamSubscription<AppEvent>? _eventSubscription;
  MedicineId? _activeMedicineId;

  InventoryController({required InventoryRepository repository})
      : _getStockLevels = GetStockLevelsUseCase(repository),
        _adjustStock = AdjustStockUseCase(repository),
        _getMovements = GetMovementsUseCase(repository) {
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      if (event == AppEvent.saleCompleted ||
          event == AppEvent.purchaseCompleted ||
          event == AppEvent.medicineUpdated) {
        loadStockLevels(silent: true);
        if (_activeMedicineId != null) {
          _reloadActiveMovements();
        }
      }
    });
  }

  List<InventoryStock> _stocks = [];
  List<InventoryMovement> _activeMovements = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _statusFilter;

  List<InventoryStock> get stocks => _stocks;
  List<InventoryMovement> get activeMovements => _activeMovements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get statusFilter => _statusFilter;
  MedicineId? get activeMedicineId => _activeMedicineId;

  Future<void> loadStockLevels({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getStockLevels.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      statusFilter: _statusFilter,
    );

    result.fold(
      onSuccess: (data) {
        _stocks = data;
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void search(String query) {
    _searchQuery = query;
    loadStockLevels();
  }

  void filterByStatus(String? status) {
    _statusFilter = status;
    loadStockLevels();
  }

  Future<String?> adjustStock({
    required MedicineId medicineId,
    required int quantityChange,
    required AdjustmentReason reason,
    String? reference,
    required String operatorName,
  }) async {
    final result = await _adjustStock.execute(
      medicineId: medicineId,
      quantityChange: quantityChange,
      reason: reason,
      reference: reference,
      operatorName: operatorName,
    );

    return result.fold(
      onSuccess: (_) {
        AppEventBus.instance.fire(AppEvent.medicineUpdated);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<void> loadMovements(MedicineId medicineId) async {
    _activeMedicineId = medicineId;
    _activeMovements = [];
    notifyListeners();
    await _reloadActiveMovements();
  }

  Future<void> _reloadActiveMovements() async {
    if (_activeMedicineId == null) return;
    final result = await _getMovements.execute(_activeMedicineId!);
    result.fold(
      onSuccess: (data) {
        _activeMovements = data;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}