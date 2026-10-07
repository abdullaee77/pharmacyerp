import '../../../core/result/result.dart';
import 'dashboard_stats.dart';

/// Abstract contract managing telemetry fetches.
///
/// The domain layer defines WHAT is needed.
/// The data layer decides HOW to provide it (SQLite, API, mock, etc.).
abstract class DashboardRepository {
  /// Loads compiled real-time stats overview.
  Future<Result<DashboardStats>> getStatsSummary();
}