import 'package:flutter/material.dart';
import '../../domain/dashboard_stats.dart';
import '../../domain/dashboard_repository.dart';
import '../../application/get_dashboard_stats_use_case.dart';

/// Presentation state container managing aggregated home telemetry.
class DashboardController extends ChangeNotifier {
  final GetDashboardStatsUseCase _useCase;

  DashboardController({
    required DashboardRepository repository,
  }) : _useCase = GetDashboardStatsUseCase(repository);

  DashboardStats? _stats;
  bool _isLoading = false;
  String? _error;

  /// The loaded dashboard statistics, or null if not yet fetched.
  DashboardStats? get stats => _stats;

  /// Whether a fetch operation is currently in progress.
  bool get isLoading => _isLoading;

  /// The most recent error message, or null if no error.
  String? get error => _error;

  /// Fetch compiled business metrics from the application boundary.
  Future<void> fetchSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _useCase.execute();

    result.fold(
      onSuccess: (data) {
        _stats = data;
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
}