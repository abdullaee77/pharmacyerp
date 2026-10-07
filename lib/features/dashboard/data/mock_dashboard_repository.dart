import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';

/// Mock storage adapter satisfying the [DashboardRepository] contract.
///
/// Will be replaced by SqliteDashboardRepository in a future phase.
class MockDashboardRepository implements DashboardRepository {
  @override
  Future<Result<DashboardStats>> getStatsSummary() async {
    // Simulates localized database query delay
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      final stats = DashboardStats(
        id: const DashboardStatsId('today_ledger'),
        todaySales: 4829.50,
        totalTransactions: 84,
        lowStockCount: 5,
        nearExpiryCount: 12,
        salesTrend: const [
          210.0, 480.0, 320.0, 780.0, 610.0,
          940.0, 1150.0, 840.0, 1310.0, 1480.0,
        ],
        criticalAlerts: const [
          StockAlert(
            id: 'alt_1',
            medicineName: 'Amoxicillin 500mg Caps',
            currentStock: 0,
            minThreshold: 50,
          ),
          StockAlert(
            id: 'alt_2',
            medicineName: 'Atorvastatin 20mg Tab (B.No: AT392)',
            currentStock: 12,
            minThreshold: 40,
            isExpired: true,
          ),
          StockAlert(
            id: 'alt_3',
            medicineName: 'Paracetamol 500mg Rapid',
            currentStock: 8,
            minThreshold: 100,
          ),
          StockAlert(
            id: 'alt_4',
            medicineName: 'Metformin 850mg (Sandoz)',
            currentStock: 0,
            minThreshold: 60,
          ),
        ],
        recentActivities: const [
          ActivityLog(
            id: 'act_1',
            description: 'POS Sale #INV-2024-0092 processed',
            timestamp: '10 mins ago',
            operatorName: 'Dr. Alexander Dev',
            category: 'sale',
          ),
          ActivityLog(
            id: 'act_2',
            description: 'Stock adjustment (Physical audit)',
            timestamp: '34 mins ago',
            operatorName: 'Sarah Jenkins, PharmD',
            category: 'inventory',
          ),
          ActivityLog(
            id: 'act_3',
            description: 'New Medicine "Ibuprofen 400mg Liquid" registered',
            timestamp: '1 hour ago',
            operatorName: 'Dr. Alexander Dev',
            category: 'inventory',
          ),
          ActivityLog(
            id: 'act_4',
            description: 'Cashier checkout register balance reset',
            timestamp: '2 hours ago',
            operatorName: 'John Smith',
            category: 'user',
          ),
        ],
      );

      return Success(stats);
    } catch (_) {
      return const Failure(
        DatabaseFailure(message: 'Failed to aggregate dashboard stats.'),
      );
    }
  }
}