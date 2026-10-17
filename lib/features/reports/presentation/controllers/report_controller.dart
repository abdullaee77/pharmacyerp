import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../application/report_use_cases.dart';
import '../../domain/report_models.dart';
import '../../domain/report_repository.dart';

class ReportController extends ChangeNotifier {
  final GenerateReportUseCase _generateReport;
  final GetBusinessMetricsUseCase _getMetrics;
  StreamSubscription<AppEvent>? _eventSubscription;

  ReportController({required ReportRepository repository})
      : _generateReport = GenerateReportUseCase(repository),
        _getMetrics = GetBusinessMetricsUseCase(repository) {
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      // Refresh dashboard metrics on ANY financial or inventory change
      if (event == AppEvent.saleCompleted ||
          event == AppEvent.saleReturned ||
          event == AppEvent.purchaseCompleted ||
          event == AppEvent.purchaseReturned ||
          event == AppEvent.expenseAdded ||
          event == AppEvent.supplierPaymentRecorded ||
          event == AppEvent.customerPaymentRecorded ||
          event == AppEvent.accountChanged ||
          event == AppEvent.inventoryAdjusted ||
          event == AppEvent.batchChanged ||
          event == AppEvent.medicineUpdated) {
        loadMetrics(silent: true);
        // Also refresh the currently-open report if any
        if (_currentReport != null) {
          generateReport(silent: true);
        }
      }
    });
  }

  ReportType _selectedType = ReportType.sales;
  ReportFilter _filter = ReportFilter.thisMonth();
  ReportResult? _currentReport;
  BusinessMetrics? _metrics;
  bool _isLoading = false;
  String? _error;

  ReportType get selectedType => _selectedType;
  ReportFilter get filter => _filter;
  ReportResult? get currentReport => _currentReport;
  BusinessMetrics? get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectReportType(ReportType type) {
    _selectedType = type;
    _currentReport = null;
    notifyListeners();
    generateReport();
  }

  void updateFilter(ReportFilter filter) {
    _filter = filter;
    generateReport();
  }

  Future<void> generateReport({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _generateReport.execute(_selectedType, _filter);
    result.fold(
      onSuccess: (data) {
        _currentReport = data;
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

  Future<void> loadMetrics({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getMetrics.execute();
    result.fold(
      onSuccess: (data) {
        _metrics = data;
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

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}