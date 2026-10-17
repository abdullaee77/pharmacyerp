import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../../inventory/domain/batch_repository.dart';
import '../../../inventory/domain/inventory_repository.dart';
import '../../../suppliers/domain/supplier_repository.dart';
import '../../application/purchase_use_cases.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_repository.dart';
import '../../domain/purchase_return.dart';

class PurchaseController extends ChangeNotifier {
  final ReceivePurchaseUseCase _receive;
  final GetPurchasesUseCase _getPurchases;
  final CreatePurchaseReturnUseCase _createReturn;
  final PurchaseRepository _purchaseRepository;

  StreamSubscription<AppEvent>? _eventSubscription;

  PurchaseController({
    required PurchaseRepository purchaseRepository,
    required InventoryRepository inventoryRepository,
    required BatchRepository batchRepository,
    SupplierRepository? supplierRepository,
  })  : _purchaseRepository = purchaseRepository,
        _receive = ReceivePurchaseUseCase(
          purchaseRepository: purchaseRepository,
          inventoryRepository: inventoryRepository,
          batchRepository: batchRepository,
          supplierRepository: supplierRepository,
        ),
        _getPurchases = GetPurchasesUseCase(purchaseRepository),
        _createReturn = CreatePurchaseReturnUseCase(
          purchaseRepository: purchaseRepository,
          inventoryRepository: inventoryRepository,
        ) {
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      if (event == AppEvent.purchaseCompleted ||
          event == AppEvent.purchaseReturned ||
          event == AppEvent.supplierPaymentRecorded) {
        loadPurchases(silent: true);
      }
    });
  }

  List<Purchase> _purchases = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  Future<void> loadPurchases({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getPurchases.execute(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery);
    result.fold(
      onSuccess: (data) {
        _purchases = data;
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

  void search(String query) {
    _searchQuery = query;
    loadPurchases();
  }

  Future<String?> receivePurchase(
      Purchase purchase, {
        String? accountId,
        int amountPaidPaisa = 0,
      }) async {
    final result = await _receive.execute(
      purchase,
      accountId: accountId,
      amountPaidPaisa: amountPaidPaisa,
    );
    return result.fold(
      onSuccess: (_) {
        loadPurchases();
        // Broadcast: inventory/dashboard/suppliers/accounts all react
        AppEventBus.instance.fire(AppEvent.purchaseCompleted);
        AppEventBus.instance.fire(AppEvent.inventoryAdjusted);
        AppEventBus.instance.fire(AppEvent.batchChanged);
        if (accountId != null && amountPaidPaisa > 0) {
          AppEventBus.instance.fire(AppEvent.accountChanged);
          AppEventBus.instance.fire(AppEvent.supplierPaymentRecorded);
        } else {
          AppEventBus.instance.fire(AppEvent.supplierUpdated);
        }
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> createReturn({
    required Purchase originalPurchase,
    required PurchaseReturn returnDoc,
  }) async {
    final result = await _createReturn.execute(
        originalPurchase: originalPurchase, returnDoc: returnDoc);
    return result.fold(
      onSuccess: (_) {
        loadPurchases();
        AppEventBus.instance.fire(AppEvent.purchaseReturned);
        AppEventBus.instance.fire(AppEvent.inventoryAdjusted);
        AppEventBus.instance.fire(AppEvent.batchChanged);
        AppEventBus.instance.fire(AppEvent.supplierUpdated);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<Map<String, int>> loadReturnedQuantities(PurchaseId id) async {
    final result = await _purchaseRepository.getReturnedQuantities(id);
    return result.fold(
      onSuccess: (d) => d,
      onFailure: (_) => {},
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}