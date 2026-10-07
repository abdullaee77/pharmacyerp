import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../application/customer_use_cases.dart';
import '../../domain/customer.dart';
import '../../domain/customer_ledger.dart';
import '../../domain/customer_repository.dart';

class CustomerController extends ChangeNotifier {
  final GetCustomersUseCase _getCustomers;
  final CreateCustomerUseCase _createCustomer;
  final UpdateCustomerUseCase _updateCustomer;
  final DeleteCustomerUseCase _deleteCustomer;
  final GetCustomerLedgerUseCase _getLedger;
  final RecordCustomerPaymentUseCase _recordPayment;

  StreamSubscription<AppEvent>? _eventSubscription;
  CustomerId? _activeCustomerId; // Tracks active customer to refresh ledger dynamically

  CustomerController({required CustomerRepository repository})
      : _getCustomers = GetCustomersUseCase(repository),
        _createCustomer = CreateCustomerUseCase(repository),
        _updateCustomer = UpdateCustomerUseCase(repository),
        _deleteCustomer = DeleteCustomerUseCase(repository),
        _getLedger = GetCustomerLedgerUseCase(repository),
        _recordPayment = RecordCustomerPaymentUseCase(repository) {

    // ── Listen to Event Bus for Automatic Updates ──
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      if (event == AppEvent.saleCompleted || event == AppEvent.customerUpdated) {
        loadCustomers();
        // If viewing a ledger, auto-update it with the new sales record
        if (_activeCustomerId != null) {
          _reloadActiveLedger();
        }
      }
    });
  }

  List<CustomerWithBalance> _customers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<LedgerRow> _activeLedger = [];

  List<CustomerWithBalance> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LedgerRow> get activeLedger => _activeLedger;
  CustomerId? get activeCustomerId => _activeCustomerId;

  Future<void> loadCustomers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _getCustomers.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    result.fold(
      onSuccess: (data) {
        _customers = data;
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
    loadCustomers();
  }

  Future<String?> createCustomer(Customer c) async {
    final result = await _createCustomer.execute(c);
    return result.fold(
      onSuccess: (_) {
        AppEventBus.instance.fire(AppEvent.customerUpdated);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> updateCustomer(Customer c) async {
    final result = await _updateCustomer.execute(c);
    return result.fold(
      onSuccess: (_) {
        AppEventBus.instance.fire(AppEvent.customerUpdated);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteCustomer(CustomerId id) async {
    final result = await _deleteCustomer.execute(id);
    return result.fold(
      onSuccess: (_) {
        if (_activeCustomerId == id) {
          _activeCustomerId = null;
          _activeLedger = [];
        }
        AppEventBus.instance.fire(AppEvent.customerUpdated);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<void> loadLedger(CustomerId id) async {
    _activeCustomerId = id;
    _activeLedger = [];
    notifyListeners();
    await _reloadActiveLedger();
  }

  // Reloads active ledger without resetting the tracking target ID
  Future<void> _reloadActiveLedger() async {
    if (_activeCustomerId == null) return;
    final result = await _getLedger.execute(_activeCustomerId!);
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
    required CustomerId customerId,
    required Money amount,
    required String paymentMethod,
    String? reference,
    String? note,
    required String operatorName,
  }) async {
    final result = await _recordPayment.execute(
      customerId: customerId,
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
      note: note,
      operatorName: operatorName,
    );
    return result.fold(
      onSuccess: (_) {
        AppEventBus.instance.fire(AppEvent.customerUpdated);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel(); // Cancel subscription to prevent memory leaks
    super.dispose();
  }
}