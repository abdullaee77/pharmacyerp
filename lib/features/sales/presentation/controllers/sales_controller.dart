import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart'; // Import Event Bus
import '../../../customers/domain/customer_repository.dart';
import '../../../inventory/domain/inventory_repository.dart';
import '../../application/complete_sale_use_case.dart';
import '../../application/sales_return_use_cases.dart';
import '../../domain/payment.dart';
import '../../domain/sale.dart';
import '../../domain/sales_repository.dart';
import '../../domain/sales_return.dart';

class SalesController extends ChangeNotifier {
  final CompleteSaleUseCase _completeSale;
  final GetSalesHistoryUseCase _getHistory;
  final CreateSalesReturnUseCase _createReturn;
  final SalesRepository _salesRepository;

  SalesController({
    required SalesRepository salesRepository,
    required InventoryRepository inventoryRepository,
    CustomerRepository? customerRepository,
  })  : _salesRepository = salesRepository,
        _completeSale = CompleteSaleUseCase(
          salesRepository: salesRepository,
          inventoryRepository: inventoryRepository,
          customerRepository: customerRepository,
        ),
        _getHistory = GetSalesHistoryUseCase(salesRepository),
        _createReturn = CreateSalesReturnUseCase(
          salesRepository: salesRepository,
          inventoryRepository: inventoryRepository,
        );

  List<Sale> _history = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Sale> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  Future<String?> completeSale({
    required Sale sale,
    required List<PaymentTender> tenders,
    String? customerPhone,
  }) async {
    final result = await _completeSale.execute(
      sale: sale,
      tenders: tenders,
      customerPhone: customerPhone,
    );
    return result.fold(
      onSuccess: (_) {
        loadHistory();
        // ── Fire sale event to update dashboard and customer ledgers instantly ──
        AppEventBus.instance.fire(AppEvent.saleCompleted);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _getHistory.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    result.fold(
      onSuccess: (data) {
        _history = data;
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
    loadHistory();
  }

  Future<String?> createReturn({
    required Sale originalSale,
    required SalesReturn returnDoc,
  }) async {
    final result = await _createReturn.execute(
      originalSale: originalSale,
      returnDoc: returnDoc,
    );
    return result.fold(
      onSuccess: (_) {
        loadHistory();
        // ── Fire sale event on returns too since balance and profits decrease ──
        AppEventBus.instance.fire(AppEvent.saleCompleted);
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<Map<String, int>> loadReturnedQuantities(SaleId id) async {
    final result = await _salesRepository.getReturnedQuantities(id);
    return result.fold(
      onSuccess: (data) => data,
      onFailure: (_) => {},
    );
  }
}