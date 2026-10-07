import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';

/// Unique domain ID for the dashboard stats ledger.
class DashboardStatsId extends ValueObject {
  final String value;
  const DashboardStatsId(this.value);
}

/// Value object representing dynamic stock notification indicators.
class StockAlert extends ValueObject {
  final String id;
  final String medicineName;
  final int currentStock;
  final int minThreshold;
  final bool isExpired;

  const StockAlert({
    required this.id,
    required this.medicineName,
    required this.currentStock,
    required this.minThreshold,
    this.isExpired = false,
  });

  /// Business rule check for critical low stock status
  bool get isCritical => currentStock == 0;
}

/// Value object modeling an audit ledger event log.
class ActivityLog extends ValueObject {
  final String id;
  final String description;
  final String timestamp;
  final String operatorName;
  final String category; // 'sale', 'inventory', 'user'

  const ActivityLog({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.operatorName,
    required this.category,
  });
}

/// Dynamic Dashboard Stats Domain Entity.
class DashboardStats extends Entity<DashboardStatsId> {
  final double todaySales;
  final int totalTransactions;
  final int lowStockCount;
  final int nearExpiryCount;
  final List<double> salesTrend; // Currency values for sparkline representation
  final List<StockAlert> criticalAlerts;
  final List<ActivityLog> recentActivities;

  const DashboardStats({
    required super.id,
    required this.todaySales,
    required this.totalTransactions,
    required this.lowStockCount,
    required this.nearExpiryCount,
    required this.salesTrend,
    required this.criticalAlerts,
    required this.recentActivities,
  });
}