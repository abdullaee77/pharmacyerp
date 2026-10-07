import '../../../core/domain/value_object.dart';

// ── Value Objects ──────────────────────────────────────────────

/// Represents a monetary amount with currency context.
/// Reusable across Sales, Purchases, Accounts, and Reports.
class Money extends ValueObject {
  final double amount;
  final String currencySymbol;

  const Money({
    required this.amount,
    this.currencySymbol = '₹',
  });

  String get formatted =>
      '$currencySymbol ${amount.toStringAsFixed(2)}';

  String get formattedCompact {
    if (amount >= 10000000) {
      return '$currencySymbol ${(amount / 10000000).toStringAsFixed(1)} Cr';
    }
    if (amount >= 100000) {
      return '$currencySymbol ${(amount / 100000).toStringAsFixed(1)} L';
    }
    if (amount >= 1000) {
      return '$currencySymbol ${(amount / 1000).toStringAsFixed(1)} K';
    }
    return formatted;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Money &&
              runtimeType == other.runtimeType &&
              amount == other.amount &&
              currencySymbol == other.currencySymbol;

  @override
  int get hashCode => Object.hash(amount, currencySymbol);
}

/// Count of items triggering a stock alert.
class StockAlertCount extends ValueObject {
  final int value;
  const StockAlertCount(this.value);

  bool get hasAlerts => value > 0;
  bool get isCritical => value > 20;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockAlertCount &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Count of batches approaching or past expiry.
class ExpiryAlertCount extends ValueObject {
  final int nearExpiry;
  final int expired;

  const ExpiryAlertCount({
    required this.nearExpiry,
    required this.expired,
  });

  int get total => nearExpiry + expired;
  bool get hasAlerts => total > 0;
  bool get isCritical => expired > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ExpiryAlertCount &&
              runtimeType == other.runtimeType &&
              nearExpiry == other.nearExpiry &&
              expired == other.expired;

  @override
  int get hashCode => Object.hash(nearExpiry, expired);
}

// ── Enums ──────────────────────────────────────────────────────

/// Domain-level severity classification for alerts.
enum AlertSeverity {
  critical,
  warning,
  info,
}

/// Transaction type for the recent activity feed.
enum TransactionType {
  sale,
  purchase,
  saleReturn,
  purchaseReturn,
  expense,
}

// ── Alert & Transaction Models ─────────────────────────────────

/// A single actionable alert surfaced on the dashboard.
class AlertItem {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final DateTime timestamp;

  const AlertItem({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
  });
}

/// A recent transaction record for the dashboard activity feed.
class RecentTransaction {
  final String id;
  final String referenceNumber;
  final TransactionType type;
  final String partyName;
  final Money amount;
  final DateTime timestamp;

  const RecentTransaction({
    required this.id,
    required this.referenceNumber,
    required this.type,
    required this.partyName,
    required this.amount,
    required this.timestamp,
  });

  String get typeLabel {
    switch (type) {
      case TransactionType.sale:
        return 'Sale';
      case TransactionType.purchase:
        return 'Purchase';
      case TransactionType.saleReturn:
        return 'Sale Return';
      case TransactionType.purchaseReturn:
        return 'Purchase Return';
      case TransactionType.expense:
        return 'Expense';
    }
  }
}

// ── Dashboard Summary Aggregate ────────────────────────────────

/// Read-model aggregate representing the complete dashboard state.
///
/// Assembled by the repository from multiple data sources.
/// This is NOT a persisted entity — it is a projection.
class DashboardSummary {
  final Money todayRevenue;
  final int todayTransactionCount;
  final Money averageBillValue;
  final StockAlertCount lowStockCount;
  final ExpiryAlertCount expiryAlerts;
  final int totalMedicines;
  final int totalCustomers;
  final List<AlertItem> alerts;
  final List<RecentTransaction> recentTransactions;
  final DateTime generatedAt;

  const DashboardSummary({
    required this.todayRevenue,
    required this.todayTransactionCount,
    required this.averageBillValue,
    required this.lowStockCount,
    required this.expiryAlerts,
    required this.totalMedicines,
    required this.totalCustomers,
    required this.alerts,
    required this.recentTransactions,
    required this.generatedAt,
  });
}