import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../domain/dashboard_stats.dart';
import '../../domain/dashboard_repository.dart';
import '../../application/get_dashboard_stats_use_case.dart';

/// Presentation state container managing aggregated home telemetry.
class DashboardController extends ChangeNotifier {
  final GetDashboardStatsUseCase _useCase;
  StreamSubscription<AppEvent>? _eventSubscription;

  DashboardController({
    required DashboardRepository repository,
  }) : _useCase = GetDashboardStatsUseCase(repository) {
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      // Dashboard shows sales, purchases, expenses, inventory, accounts.
      // Refresh on ANY event that affects those.
      if (event == AppEvent.saleCompleted ||
          event == AppEvent.saleReturned ||
          event == AppEvent.purchaseCompleted ||
          event == AppEvent.purchaseReturned ||
          event == AppEvent.expenseAdded ||
          event == AppEvent.inventoryAdjusted ||
          event == AppEvent.batchChanged ||
          event == AppEvent.accountChanged ||
          event == AppEvent.customerPaymentRecorded ||
          event == AppEvent.supplierPaymentRecorded ||
          event == AppEvent.medicineUpdated) {
        fetchSummary(silent: true);
      }
    });
  }

  DashboardStats? _stats;
  bool _isLoading = false;
  String? _error;

  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch compiled business metrics from the application boundary.
  /// Pass [silent] = true to avoid showing the loader spinner (used for
  /// background auto-refresh so the chart does not flash).
  Future<void> fetchSummary({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _useCase.execute();

    result.fold(
      onSuccess: (data) {
        _stats = data;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onFailure: (failure) {
        _error = failure.message;
        _isLoading = false;
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