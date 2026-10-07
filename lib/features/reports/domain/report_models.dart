import '../../medicines/domain/value_objects.dart';

/// Available report types.
enum ReportType {
  sales(label: 'Sales Report', icon: '📈'),
  purchases(label: 'Purchase Report', icon: '🛒'),
  profit(label: 'Profit & Loss', icon: '💰'),
  inventory(label: 'Inventory Valuation', icon: '📦'),
  expiry(label: 'Expiry Report', icon: '⏰'),
  customers(label: 'Customer Report', icon: '👥'),
  suppliers(label: 'Supplier Report', icon: '🏭'),
  accounts(label: 'Account Report', icon: '🏦');

  final String label;
  final String icon;
  const ReportType({required this.label, required this.icon});
}

/// Filter parameters for report generation.
class ReportFilter {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? searchQuery;
  final String? category;
  final String? supplier;
  final String? customer;
  final String? status;

  const ReportFilter({
    this.fromDate,
    this.toDate,
    this.searchQuery,
    this.category,
    this.supplier,
    this.customer,
    this.status,
  });

  ReportFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? searchQuery,
    String? category,
    String? supplier,
    String? customer,
    String? status,
  }) {
    return ReportFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      customer: customer ?? this.customer,
      status: status ?? this.status,
    );
  }

  /// Default: current month.
  factory ReportFilter.thisMonth() {
    final now = DateTime.now();
    return ReportFilter(
      fromDate: DateTime(now.year, now.month, 1),
      toDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }
}

/// A single row in a report result.
class ReportRow {
  final Map<String, dynamic> data;

  const ReportRow(this.data);

  // Safe robust toString conversions prevent _TypeError crashes from DB type mismatches
  String get string0 => data['col0']?.toString() ?? '';
  String get string1 => data['col1']?.toString() ?? '';
  String get string2 => data['col2']?.toString() ?? '';
  String get string3 => data['col3']?.toString() ?? '';
  String get string4 => data['col4']?.toString() ?? '';
  String get string5 => data['col5']?.toString() ?? '';

  int get int0 => (data['col0'] as num?)?.toInt() ?? 0;
  int get int1 => (data['col1'] as num?)?.toInt() ?? 0;

  Money get money0 => Money.fromPaisa((data['col0'] as num?)?.toInt() ?? 0);
  Money get money1 => Money.fromPaisa((data['col1'] as num?)?.toInt() ?? 0);
  Money get money2 => Money.fromPaisa((data['col2'] as num?)?.toInt() ?? 0);
}

/// Complete report result.
class ReportResult {
  final ReportType type;
  final List<String> headers;
  final List<ReportRow> rows;
  final Map<String, Money> summaryTotals;
  final int totalRowCount;

  const ReportResult({
    required this.type,
    required this.headers,
    required this.rows,
    this.summaryTotals = const {},
    this.totalRowCount = 0,
  });
}

/// Business dashboard metrics derived from real data.
class BusinessMetrics {
  final Money todayRevenue;
  final Money monthRevenue;
  final Money monthPurchases;
  final Money monthExpenses;
  final Money monthProfit;
  final Money totalReceivables;
  final Money totalPayables;
  final Money stockValue;
  final int totalMedicines;
  final int lowStockCount;
  final int expiredCount;
  final int expiringSoonCount;
  final int todayTransactions;
  final List<DailyTrend> salesTrend;
  final List<CategoryBreakdown> topSelling;

  const BusinessMetrics({
    required this.todayRevenue,
    required this.monthRevenue,
    required this.monthPurchases,
    required this.monthExpenses,
    required this.monthProfit,
    required this.totalReceivables,
    required this.totalPayables,
    required this.stockValue,
    required this.totalMedicines,
    required this.lowStockCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.todayTransactions,
    required this.salesTrend,
    required this.topSelling,
  });
}

class DailyTrend {
  final String dateLabel;
  final Money revenue;

  const DailyTrend({required this.dateLabel, required this.revenue});
}

class CategoryBreakdown {
  final String name;
  final int quantity;
  final Money revenue;

  const CategoryBreakdown({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}