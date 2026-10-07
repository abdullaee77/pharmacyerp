import 'package:flutter/material.dart';
import '../../../inventory/domain/batch.dart';
import '../../../medicines/domain/medicine.dart';
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

  bool addToCart({required Medicine medicine, required Batch batch, int quantity = 1}) {
    final existingIdx = _items.indexWhere(
          (i) => i.medicine.id == medicine.id && i.batch.id == batch.id,
    );

    if (existingIdx >= 0) {
      final existing = _items[existingIdx];
      final newQty = existing.quantity + quantity;
      _items[existingIdx] = existing.copyWith(quantity: newQty);
      _selectedLine = _items[existingIdx];
    } else {
      final line = CartItem(
        id: CartItemId.generate(),
        medicine: medicine,
        batch: batch,
        quantity: quantity,
        unitPrice: medicine.sellingPrice,
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
    _items[idx] = line.copyWith(batch: newBatch);
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

  // ── Hold & Resume Cart Methods ──
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