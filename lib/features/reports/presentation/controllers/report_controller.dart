// lib/features/reports/presentation/controllers/report_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharmacy/core/services/app_event_bus.dart'; // Import Event Bus
import '../../application/report_use_cases.dart';
import '../../domain/report_models.dart';
import '../../domain/report_repository.dart';

class ReportController extends ChangeNotifier {
  final GenerateReportUseCase _generateReport;
  final GetBusinessMetricsUseCase _getMetrics;
  StreamSubscription<AppEvent>? _eventSubscription; // Stream subscription tracker

  ReportController({required ReportRepository repository})
      : _generateReport = GenerateReportUseCase(repository),
        _getMetrics = GetBusinessMetricsUseCase(repository) {
    // ── Listen to Event Bus reactively ──
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      if (event == AppEvent.saleCompleted ||
          event == AppEvent.purchaseCompleted ||
          event == AppEvent.expenseAdded) {
        loadMetrics(); // Auto-refresh metrics instantly!
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

  Future<void> generateReport() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _generateReport.execute(_selectedType, _filter);
    result.fold(
      onSuccess: (data) {
        _currentReport = data;
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

  Future<void> loadMetrics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _getMetrics.execute();
    result.fold(
      onSuccess: (data) {
        _metrics = data;
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
    _eventSubscription?.cancel(); // Prevent memory leaks on controller teardown
    super.dispose();
  }
}