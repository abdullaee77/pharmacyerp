import 'package:flutter/material.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../application/supplier_use_cases.dart';
import '../../domain/supplier.dart';
import '../../domain/supplier_ledger.dart';
import '../../domain/supplier_repository.dart';

class SupplierController extends ChangeNotifier {
  final GetSuppliersUseCase _getSuppliers;
  final CreateSupplierUseCase _createSupplier;
  final UpdateSupplierUseCase _updateSupplier;
  final DeleteSupplierUseCase _deleteSupplier;
  final GetSupplierLedgerUseCase _getLedger;
  final RecordSupplierPaymentUseCase _recordPayment;

  SupplierController({required SupplierRepository repository})
      : _getSuppliers = GetSuppliersUseCase(repository),
        _createSupplier = CreateSupplierUseCase(repository),
        _updateSupplier = UpdateSupplierUseCase(repository),
        _deleteSupplier = DeleteSupplierUseCase(repository),
        _getLedger = GetSupplierLedgerUseCase(repository),
        _recordPayment = RecordSupplierPaymentUseCase(repository);

  List<SupplierWithBalance> _suppliers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<SupplierLedgerRow> _activeLedger = [];

  List<SupplierWithBalance> get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SupplierLedgerRow> get activeLedger => _activeLedger;

  Future<void> loadSuppliers({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getSuppliers.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    result.fold(
      onSuccess: (data) {
        _suppliers = data;
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
    loadSuppliers();
  }

  Future<String?> createSupplier(Supplier s) async {
    final result = await _createSupplier.execute(s);
    return result.fold(
      onSuccess: (_) {
        loadSuppliers();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> updateSupplier(Supplier s) async {
    final result = await _updateSupplier.execute(s);
    return result.fold(
      onSuccess: (_) {
        loadSuppliers();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteSupplier(SupplierId id) async {
    final result = await _deleteSupplier.execute(id);
    return result.fold(
      onSuccess: (_) {
        loadSuppliers();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<void> loadLedger(SupplierId id) async {
    _activeLedger = [];
    notifyListeners();
    final result = await _getLedger.execute(id);
    result.fold(
      onSuccess: (data) {
        _activeLedger = data;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        notifyListeners();
      },
    );
  }

  Future<String?> recordPayment({
    required SupplierId supplierId,
    required Money amount,
    required String paymentMethod,
    String? reference,
    String? note,
    required String operatorName,
  }) async {
    final result = await _recordPayment.execute(
      supplierId: supplierId,
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
      note: note,
      operatorName: operatorName,
    );
    return result.fold(
      onSuccess: (_) {
        loadSuppliers();
        loadLedger(supplierId);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }
}