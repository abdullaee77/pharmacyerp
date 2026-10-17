import 'package:flutter/material.dart';
import '../../../inventory/domain/batch.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../application/pos_use_cases.dart';
import '../../domain/cart_item.dart';
import '../../domain/pos_models.dart';
import '../../domain/pos_repository.dart';

class HeldSale {
  final String id;
  final String customerName;
  final String customerPhone;
  final List<CartItem> items;
  final CartTotals totals;
  final DateTime heldAt;
  final String? note;

  HeldSale({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totals,
    required this.heldAt,
    this.note,
  });
}

class PosCartController extends ChangeNotifier {
  final SearchMedicinesForPosUseCase _search;
  final ResolveBarcodeUseCase _resolveBarcode;
  final GetAvailableBatchesUseCase _getBatches;
  final ValidateCartLineUseCase _validate;

  PosCartController({required PosRepository repository})
      : _search = SearchMedicinesForPosUseCase(repository),
        _resolveBarcode = ResolveBarcodeUseCase(repository),
        _getBatches = GetAvailableBatchesUseCase(repository),
        _validate = const ValidateCartLineUseCase();

  List<PosSearchResult> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  List<PosSearchResult> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;

  final List<CartItem> _items = [];
  final List<HeldSale> _heldSales = [];
  CartItem? _selectedLine;
  String _customerName = 'Walk-in Customer';
  String _customerPhone = '';
  String? _lastMessage;
  bool _lastMessageIsError = false;

  List<CartItem> get items => List.unmodifiable(_items);
  List<HeldSale> get heldSales => List.unmodifiable(_heldSales);
  int get heldSalesCount => _heldSales.length;

  CartItem? get selectedLine => _selectedLine;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String? get lastMessage => _lastMessage;
  bool get lastMessageIsError => _lastMessageIsError;

  CartTotals get totals => CartTotals.fromItems(_items);
  bool get isEmpty => _items.isEmpty;

  Future<void> search(String query) async {
    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    final result = await _search.execute(query);
    result.fold(
      onSuccess: (data) {
        _searchResults = data;
        _isSearching = false;
        notifyListeners();
      },
      onFailure: (f) {
        _searchResults = [];
        _isSearching = false;
        _setMessage(f.message, isError: true);
      },
    );
  }

  Future<void> loadInitial() async => search('');

  Future<PosSearchResult?> scanBarcode(String barcode) async {
    final result = await _resolveBarcode.execute(barcode);
    return result.fold(
      onSuccess: (res) => res,
      onFailure: (f) {
        _setMessage(f.message, isError: true);
        return null;
      },
    );
  }

  Future<List<Batch>> loadBatches(MedicineId medicineId) async {
    final result = await _getBatches.execute(medicineId);
    return result.fold(
      onSuccess: (batches) => batches,
      onFailure: (f) {
        _setMessage(f.message, isError: true);
        return [];
      },
    );
  }

  /// Automated FEFO Multi-Batch Auto Allocator
  /// Sorts batches by expiry date ASC (via daysRemaining), uses earliest expiring stock first,
  /// and splits requested quantity across batches with batch-specific pricing.
  bool addMedicineWithFefo({
    required Medicine medicine,
    required List<Batch> batches,
    required int requestedQuantity,
  }) {
    if (requestedQuantity <= 0) return false;

    // 1. Filter out expired and zero-stock batches, then sort by FEFO (earliest expiring first)
    final activeBatches = batches.where((b) {
      final isExpired = b.status == BatchStatus.expired || b.expiryDate.daysRemaining < 0;
      return !isExpired && b.quantity.value > 0;
    }).toList()
      ..sort((a, b) => a.expiryDate.daysRemaining.compareTo(b.expiryDate.daysRemaining));

    if (activeBatches.isEmpty) {
      _setMessage('No active non-expired stock available for ${medicine.name}.', isError: true);
      return false;
    }

    // 2. Calculate remaining available stock across batches considering items ALREADY in cart
    int totalAvailableInCart = 0;
    for (final b in activeBatches) {
      final existingIdx = _items.indexWhere((i) => i.batch.id == b.id);
      final inCart = existingIdx >= 0 ? _items[existingIdx].quantity : 0;
      totalAvailableInCart += (b.quantity.value - inCart);
    }

    if (totalAvailableInCart < requestedQuantity) {
      _setMessage(
        'Cannot add $requestedQuantity units. Only $totalAvailableInCart units available for ${medicine.name}.',
        isError: true,
      );
      return false;
    }

    // 3. Sequential FEFO Allocation Loop
    int remainingNeeded = requestedQuantity;

    for (final b in activeBatches) {
      final existingIdx = _items.indexWhere((i) => i.batch.id == b.id);
      final currentQtyInCart = existingIdx >= 0 ? _items[existingIdx].quantity : 0;
      final availInBatch = b.quantity.value - currentQtyInCart;

      if (availInBatch <= 0) continue;

      final toTake = remainingNeeded < availInBatch ? remainingNeeded : availInBatch;
      final priceToUse = b.sellingPrice.paisa > 0 ? b.sellingPrice : medicine.sellingPrice;
      final newQty = currentQtyInCart + toTake;

      if (existingIdx >= 0) {
        _items[existingIdx] = _items[existingIdx].copyWith(
          quantity: newQty,
          unitPrice: priceToUse,
        );
        _selectedLine = _items[existingIdx];
      } else {
        final line = CartItem(
          id: CartItemId.generate(),
          medicine: medicine,
          batch: b,
          quantity: toTake,
          unitPrice: priceToUse,
        );
        _items.add(line);
        _selectedLine = line;
      }

      remainingNeeded -= toTake;
      if (remainingNeeded <= 0) break;
    }

    _lastMessage = null;
    notifyListeners();
    return true;
  }

  bool addToCart({
    required Medicine medicine,
    required Batch batch,
    int quantity = 1,
  }) {
    final priceToUse = batch.sellingPrice.paisa > 0
        ? batch.sellingPrice
        : medicine.sellingPrice;

    final existingIdx = _items.indexWhere(
          (i) => i.medicine.id == medicine.id && i.batch.id == batch.id,
    );

    final currentQtyInCart = existingIdx >= 0 ? _items[existingIdx].quantity : 0;
    final totalRequested = currentQtyInCart + quantity;

    if (totalRequested > batch.quantity.value) {
      _setMessage(
        'Cannot add. Only ${batch.quantity.value} units available in Batch ${batch.batchNumber.value}.',
        isError: true,
      );
      return false;
    }

    if (existingIdx >= 0) {
      final existing = _items[existingIdx];
      _items[existingIdx] = existing.copyWith(
        quantity: totalRequested,
        unitPrice: priceToUse,
      );
      _selectedLine = _items[existingIdx];
    } else {
      final line = CartItem(
        id: CartItemId.generate(),
        medicine: medicine,
        batch: batch,
        quantity: quantity,
        unitPrice: priceToUse,
      );
      _items.add(line);
      _selectedLine = line;
    }

    notifyListeners();
    return true;
  }

  bool updateQuantity(CartItemId id, int newQuantity) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return false;
    final line = _items[idx];

    if (newQuantity <= 0) {
      removeLine(id);
      return true;
    }

    if (newQuantity > line.batch.quantity.value) {
      _setMessage(
        'Cannot exceed available stock in Batch ${line.batch.batchNumber.value} (${line.batch.quantity.value} units).',
        isError: true,
      );
      return false;
    }

    _items[idx] = line.copyWith(quantity: newQuantity);
    if (_selectedLine?.id == id) _selectedLine = _items[idx];
    notifyListeners();
    return true;
  }

  bool updateDiscount(CartItemId id, int percent) {
    final clamped = percent.clamp(0, 100);
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return false;
    _items[idx] = _items[idx].copyWith(discountPercent: clamped);
    if (_selectedLine?.id == id) _selectedLine = _items[idx];
    notifyListeners();
    return true;
  }

  bool changeBatch(CartItemId id, Batch newBatch) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return false;
    final line = _items[idx];

    final priceToUse = newBatch.sellingPrice.paisa > 0
        ? newBatch.sellingPrice
        : line.medicine.sellingPrice;

    if (line.quantity > newBatch.quantity.value) {
      _setMessage(
        'Selected Batch ${newBatch.batchNumber.value} only has ${newBatch.quantity.value} units available.',
        isError: true,
      );
      return false;
    }

    _items[idx] = line.copyWith(
      batch: newBatch,
      unitPrice: priceToUse,
    );
    if (_selectedLine?.id == id) _selectedLine = _items[idx];
    notifyListeners();
    return true;
  }

  void removeLine(CartItemId id) {
    _items.removeWhere((i) => i.id == id);
    if (_selectedLine?.id == id) _selectedLine = null;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _selectedLine = null;
    _customerName = 'Walk-in Customer';
    _customerPhone = '';
    _lastMessage = null;
    notifyListeners();
  }

  void setCustomer(String name, {String phone = ''}) {
    _customerName = name.trim().isEmpty ? 'Walk-in Customer' : name.trim();
    _customerPhone = phone.trim();
    notifyListeners();
  }

  bool holdCurrentSale({String? note}) {
    if (_items.isEmpty) return false;

    final held = HeldSale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: _customerName,
      customerPhone: _customerPhone,
      items: List.from(_items),
      totals: totals,
      heldAt: DateTime.now(),
      note: note,
    );

    _heldSales.insert(0, held);
    _items.clear();
    _selectedLine = null;
    _customerName = 'Walk-in Customer';
    _customerPhone = '';
    _lastMessage = null;
    notifyListeners();
    return true;
  }

  bool resumeSale(HeldSale held) {
    _items.clear();
    _items.addAll(held.items);
    _selectedLine = _items.isNotEmpty ? _items.first : null;
    _customerName = held.customerName;
    _customerPhone = held.customerPhone;
    _heldSales.removeWhere((h) => h.id == held.id);
    _lastMessage = null;
    notifyListeners();
    return true;
  }

  void deleteHeldSale(String id) {
    _heldSales.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  void showOutOfStockError(String medName) {
    _setMessage('Out of Stock! Cannot add $medName to sale.', isError: true);
  }

  void _setMessage(String message, {required bool isError}) {
    _lastMessage = message;
    _lastMessageIsError = isError;
    notifyListeners();
  }

  void clearMessage() {
    if (_lastMessage != null) {
      _lastMessage = null;
      notifyListeners();
    }
  }
}