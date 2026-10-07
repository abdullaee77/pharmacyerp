import '../../../core/result/result.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';

/// Orchestrates retrieving system aggregates for home space viewports.
class GetDashboardStatsUseCase {
  final DashboardRepository _repository;

  const GetDashboardStatsUseCase(this._repository);

  /// Delegates directly to the repository abstraction.
  /// Future business rules (date filtering, branch scoping) go here.
  Future<Result<DashboardStats>> execute() async {
    return _repository.getStatsSummary();
  }
}