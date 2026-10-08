import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';

class HttpReportRepository implements ReportRepository {
  final ApiClient _api;

  HttpReportRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  String? _dateWhere(String column, ReportFilter f) {
    final parts = <String>[];
    if (f.fromDate != null) parts.add('$column >= ?');
    if (f.toDate != null) parts.add('$column <= ?');
    return parts.isEmpty ? null : parts.join(' AND ');
  }

  List<dynamic> _dateArgs(ReportFilter f) {
    final args = <dynamic>[];
    if (f.fromDate != null) args.add(f.fromDate!.toIso8601String());
    if (f.toDate != null) args.add(f.toDate!.toIso8601String());
    return args;
  }

  @override
  Future<Result<ReportResult>> generateReport(
      ReportType type,
      ReportFilter filter,
      ) async {
    try {
      switch (type) {
        case ReportType.sales:
          return await _salesReport(filter);
        case ReportType.purchases:
          return await _purchaseReport(filter);
        case ReportType.profit:
          return await _profitReport(filter);
        case ReportType.inventory:
          return await _inventoryReport(filter);
        case ReportType.expiry:
          return await _expiryReport(filter);
        case ReportType.customers:
          return await _customerReport(filter);
        case ReportType.suppliers:
          return await _supplierReport(filter);
        case ReportType.accounts:
          return await _accountReport(filter);
      }
    } catch (e) {
      return Failure(ServerFailure(message: 'Report generation failed: $e'));
    }
  }

  Future<Result<ReportResult>> _salesReport(ReportFilter f) async {
    final dw = _dateWhere('s.created_at', f);
    final da = _dateArgs(f);
    final sql = '''
      SELECT s.invoice_number AS col0,
             s.customer_name AS col1,
             s.created_at AS col2,
             s.grand_total AS col3,
             s.discount AS col4,
             s.status AS col5
      FROM sales s
      ${dw != null ? 'WHERE $dw' : ''}
      ORDER BY s.created_at DESC
    ''';
    final res = await _api.rawQuery(sql: sql, args: da.isEmpty ? null : da);
    return res.fold(
      onSuccess: (rows) {
        int totalRevenue = 0, totalDiscount = 0;
        final resultRows = rows.map((r) {
          totalRevenue += (r['col3'] as num).toInt();
          totalDiscount += (r['col4'] as num).toInt();
          return ReportRow(r);
        }).toList();
        return Success(ReportResult(
          type: ReportType.sales,
          headers: const ['Invoice', 'Customer', 'Date', 'Total', 'Discount', 'Status'],
          rows: resultRows,
          summaryTotals: {
            'Revenue': Money.fromPaisa(totalRevenue),
            'Discount': Money.fromPaisa(totalDiscount),
          },
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _purchaseReport(ReportFilter f) async {
    final dw = _dateWhere('p.created_at', f);
    final da = _dateArgs(f);
    final sql = '''
      SELECT p.invoice_number AS col0,
             p.supplier_name AS col1,
             p.created_at AS col2,
             p.grand_total AS col3,
             p.status AS col4
      FROM purchases p
      ${dw != null ? 'WHERE $dw' : ''}
      ORDER BY p.created_at DESC
    ''';
    final res = await _api.rawQuery(sql: sql, args: da.isEmpty ? null : da);
    return res.fold(
      onSuccess: (rows) {
        int totalCost = 0;
        final resultRows = rows.map((r) {
          totalCost += (r['col3'] as num).toInt();
          return ReportRow(r);
        }).toList();
        return Success(ReportResult(
          type: ReportType.purchases,
          headers: const ['Invoice', 'Supplier', 'Date', 'Total', 'Status'],
          rows: resultRows,
          summaryTotals: {'Total Cost': Money.fromPaisa(totalCost)},
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _profitReport(ReportFilter f) async {
    final dw = _dateWhere('s.created_at', f);
    final da = _dateArgs(f);

    final revSql = '''
      SELECT si.medicine_name AS col0,
             SUM(si.quantity) AS col1,
             SUM(si.line_total) AS col2
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      ${dw != null ? 'WHERE $dw' : ''}
      GROUP BY si.medicine_name
      ORDER BY col2 DESC
    ''';
    final cogsSql = '''
      SELECT si.medicine_name AS name,
             SUM(si.quantity * b.purchase_price) AS cogs
      FROM sale_items si
      JOIN batches b ON si.batch_id = b.id
      JOIN sales s ON si.sale_id = s.id
      ${dw != null ? 'WHERE $dw' : ''}
      GROUP BY si.medicine_name
    ''';

    final revRes = await _api.rawQuery(sql: revSql, args: da.isEmpty ? null : da);
    final cogsRes = await _api.rawQuery(sql: cogsSql, args: da.isEmpty ? null : da);
    if (revRes.isFailure) return Failure(revRes.failureOrNull!);

    final cogsMap = <String, int>{};
    cogsRes.fold(
      onSuccess: (rows) {
        for (final r in rows) {
          cogsMap[r['name'] as String] = (r['cogs'] as num).toInt();
        }
      },
      onFailure: (_) {},
    );

    return revRes.fold(
      onSuccess: (rows) {
        int totalRevenue = 0, totalCogs = 0;
        final resultRows = <ReportRow>[];
        for (final r in rows) {
          final name = r['col0'] as String;
          final qty = (r['col1'] as num).toInt();
          final rev = (r['col2'] as num).toInt();
          final cogs = cogsMap[name] ?? 0;
          totalRevenue += rev;
          totalCogs += cogs;
          resultRows.add(ReportRow({
            'col0': name,
            'col1': qty,
            'col2': rev,
            'col3': cogs,
            'col4': rev - cogs,
          }));
        }
        return Success(ReportResult(
          type: ReportType.profit,
          headers: const ['Medicine', 'Qty Sold', 'Revenue', 'COGS', 'Profit'],
          rows: resultRows,
          summaryTotals: {
            'Revenue': Money.fromPaisa(totalRevenue),
            'COGS': Money.fromPaisa(totalCogs),
            'Gross Profit': Money.fromPaisa(totalRevenue - totalCogs),
          },
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _inventoryReport(ReportFilter f) async {
    const sql = '''
      SELECT m.name AS col0,
             m.generic_name AS col1,
             COALESCE(s.quantity, 0) AS col2,
             m.selling_price AS col3,
             m.purchase_price AS col4
      FROM medicines m
      LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
      WHERE m.status = 'active'
      ORDER BY m.name ASC
    ''';
    final res = await _api.rawQuery(sql: sql);
    return res.fold(
      onSuccess: (rows) {
        int totalValue = 0, totalUnits = 0;
        final resultRows = rows.map((r) {
          final qty = (r['col2'] as num).toInt();
          final price = (r['col4'] as num).toInt();
          totalValue += qty * price;
          totalUnits += qty;
          return ReportRow(r);
        }).toList();
        return Success(ReportResult(
          type: ReportType.inventory,
          headers: const ['Medicine', 'Generic', 'Stock', 'Sale Price', 'Purchase Price'],
          rows: resultRows,
          summaryTotals: {
            'Total Units': Money.fromPaisa(totalUnits),
            'Stock Value (Cost)': Money.fromPaisa(totalValue),
          },
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _expiryReport(ReportFilter f) async {
    const sql = '''
      SELECT m.name AS col0,
             b.batch_number AS col1,
             b.expiry_date AS col2,
             b.quantity AS col3,
             b.selling_price AS col4
      FROM batches b
      JOIN medicines m ON b.medicine_id = m.id
      WHERE b.quantity > 0
      ORDER BY b.expiry_date ASC
    ''';
    final res = await _api.rawQuery(sql: sql);
    return res.fold(
      onSuccess: (rows) {
        final now = DateTime.now();
        final soon = now.add(const Duration(days: 90));
        int expiredQty = 0, expiringQty = 0;
        final resultRows = rows.map((r) {
          final expDate = DateTime.parse(r['col2'] as String);
          final qty = (r['col3'] as num).toInt();
          if (expDate.isBefore(now)) expiredQty += qty;
          if (!expDate.isBefore(now) && expDate.isBefore(soon)) expiringQty += qty;
          return ReportRow(r);
        }).toList();
        return Success(ReportResult(
          type: ReportType.expiry,
          headers: const ['Medicine', 'Batch', 'Expiry', 'Qty', 'Price'],
          rows: resultRows,
          summaryTotals: {
            'Expired Units': Money.fromPaisa(expiredQty),
            'Expiring Soon': Money.fromPaisa(expiringQty),
          },
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _customerReport(ReportFilter f) async {
    const sql = '''
      SELECT c.name AS col0,
             c.phone AS col1,
             COALESCE(SUM(le.debit), 0) - COALESCE(SUM(le.credit), 0) AS col2
      FROM customers c
      LEFT JOIN customer_ledger_entries le ON c.id = le.customer_id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''';
    final res = await _api.rawQuery(sql: sql);
    return res.fold(
      onSuccess: (rows) {
        int totalOutstanding = 0;
        final resultRows = rows.map((r) {
          final out = (r['col2'] as num).toInt();
          totalOutstanding += out > 0 ? out : 0;
          return ReportRow(r);
        }).toList();
        return Success(ReportResult(
          type: ReportType.customers,
          headers: const ['Customer', 'Phone', 'Outstanding'],
          rows: resultRows,
          summaryTotals: {'Total Receivable': Money.fromPaisa(totalOutstanding)},
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _supplierReport(ReportFilter f) async {
    const sql = '''
      SELECT s.name AS col0,
             s.phone AS col1,
             COALESCE(SUM(le.credit), 0) - COALESCE(SUM(le.debit), 0) AS col2
      FROM suppliers s
      LEFT JOIN supplier_ledger_entries le ON s.id = le.supplier_id
      GROUP BY s.id
      ORDER BY s.name ASC
    ''';
    final res = await _api.rawQuery(sql: sql);
    return res.fold(
      onSuccess: (rows) {
        int totalPayable = 0;
        final resultRows = rows.map((r) {
          final pay = (r['col2'] as num).toInt();
          totalPayable += pay > 0 ? pay : 0;
          return ReportRow(r);
        }).toList();
        return Success(ReportResult(
          type: ReportType.suppliers,
          headers: const ['Supplier', 'Phone', 'Payable'],
          rows: resultRows,
          summaryTotals: {'Total Payable': Money.fromPaisa(totalPayable)},
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<ReportResult>> _accountReport(ReportFilter f) async {
    const sql = '''
      SELECT a.name AS col0,
             a.account_type AS col1,
             a.opening_balance AS col2,
             COALESCE(SUM(ft.debit), 0) - COALESCE(SUM(ft.credit), 0) AS col3
      FROM accounts a
      LEFT JOIN financial_transactions ft ON a.id = ft.account_id
      GROUP BY a.id
      ORDER BY a.name ASC
    ''';
    final res = await _api.rawQuery(sql: sql);
    return res.fold(
      onSuccess: (rows) {
        final resultRows = rows.map((r) {
          final opening = (r['col2'] as num).toInt();
          final movement = (r['col3'] as num).toInt();
          return ReportRow({
            'col0': r['col0'],
            'col1': r['col1'],
            'col2': opening,
            'col3': opening + movement,
          });
        }).toList();
        return Success(ReportResult(
          type: ReportType.accounts,
          headers: const ['Account', 'Type', 'Opening', 'Current Balance'],
          rows: resultRows,
          totalRowCount: resultRows.length,
        ));
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<BusinessMetrics>> getBusinessMetrics() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      Future<int> sumCol(String table, String col, String dateCol, String since) async {
        final r = await _api.rawQuery(
          sql: 'SELECT COALESCE(SUM($col), 0) AS total FROM $table WHERE $dateCol >= ?',
          args: [since],
        );
        return r.fold(
          onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['total'] as num).toInt(),
          onFailure: (_) => 0,
        );
      }

      Future<int> countRows(String table, String dateCol, String since) async {
        final r = await _api.rawQuery(
          sql: 'SELECT COUNT(*) AS cnt FROM $table WHERE $dateCol >= ?',
          args: [since],
        );
        return r.fold(
          onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as num).toInt(),
          onFailure: (_) => 0,
        );
      }

      final todayRev = await sumCol('sales', 'grand_total', 'created_at', startOfDay);
      final monthRev = await sumCol('sales', 'grand_total', 'created_at', startOfMonth);
      final todayTx = await countRows('sales', 'created_at', startOfDay);
      final monthPur = await sumCol('purchases', 'grand_total', 'created_at', startOfMonth);
      final monthExp = await sumCol('expenses', 'amount', 'expense_date', startOfMonth);

      final recRes = await _api.rawQuery(
        sql: 'SELECT COALESCE(SUM(debit), 0) - COALESCE(SUM(credit), 0) AS bal FROM customer_ledger_entries',
      );
      final receivables = recRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['bal'] as num).toInt(),
        onFailure: (_) => 0,
      );

      final payRes = await _api.rawQuery(
        sql: 'SELECT COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0) AS bal FROM supplier_ledger_entries',
      );
      final payables = payRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['bal'] as num).toInt(),
        onFailure: (_) => 0,
      );

      final stockRes = await _api.rawQuery(sql: '''
        SELECT COALESCE(SUM(s.quantity * m.purchase_price), 0) AS val,
               COUNT(DISTINCT m.id) AS meds
        FROM medicines m
        LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
        WHERE m.status = 'active'
      ''');
      final stockValue = stockRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['val'] as num).toInt(),
        onFailure: (_) => 0,
      );
      final totalMeds = stockRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['meds'] as num).toInt(),
        onFailure: (_) => 0,
      );

      final lowRes = await _api.rawQuery(sql: '''
        SELECT COUNT(*) AS cnt FROM inventory_stocks s
        JOIN medicines m ON s.medicine_id = m.id
        WHERE s.quantity <= m.min_stock_level AND s.quantity > 0
      ''');
      final lowCount = lowRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as num).toInt(),
        onFailure: (_) => 0,
      );

      final expRes = await _api.rawQuery(
        sql: 'SELECT COUNT(*) AS cnt FROM batches WHERE expiry_date < ? AND quantity > 0',
        args: [now.toIso8601String()],
      );
      final expiredCount = expRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as num).toInt(),
        onFailure: (_) => 0,
      );

      final soonRes = await _api.rawQuery(
        sql: 'SELECT COUNT(*) AS cnt FROM batches WHERE expiry_date >= ? AND expiry_date <= ? AND quantity > 0',
        args: [now.toIso8601String(), now.add(const Duration(days: 90)).toIso8601String()],
      );
      final expiringCount = soonRes.fold(
        onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as num).toInt(),
        onFailure: (_) => 0,
      );

      final trend = <DailyTrend>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day).toIso8601String();
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
        final tRes = await _api.rawQuery(
          sql: 'SELECT COALESCE(SUM(grand_total), 0) AS total FROM sales WHERE created_at >= ? AND created_at <= ?',
          args: [dayStart, dayEnd],
        );
        final total = tRes.fold(
          onSuccess: (rows) => rows.isEmpty ? 0 : (rows.first['total'] as num).toInt(),
          onFailure: (_) => 0,
        );
        trend.add(DailyTrend(
          dateLabel: '${day.day}/${day.month}',
          revenue: Money.fromPaisa(total),
        ));
      }

      final topRes = await _api.rawQuery(
        sql: '''
          SELECT si.medicine_name AS name,
                 SUM(si.quantity) AS qty,
                 SUM(si.line_total) AS rev
          FROM sale_items si
          JOIN sales s ON si.sale_id = s.id
          WHERE s.created_at >= ?
          GROUP BY si.medicine_name
          ORDER BY rev DESC
          LIMIT 5
        ''',
        args: [startOfMonth],
      );
      final topSelling = topRes.fold(
        onSuccess: (rows) => rows
            .map((r) => CategoryBreakdown(
          name: r['name'] as String,
          quantity: (r['qty'] as num).toInt(),
          revenue: Money.fromPaisa((r['rev'] as num).toInt()),
        ))
            .toList(),
        onFailure: (_) => <CategoryBreakdown>[],
      );

      final profit = monthRev - monthPur - monthExp;

      return Success(BusinessMetrics(
        todayRevenue: Money.fromPaisa(todayRev),
        monthRevenue: Money.fromPaisa(monthRev),
        monthPurchases: Money.fromPaisa(monthPur),
        monthExpenses: Money.fromPaisa(monthExp),
        monthProfit: Money.fromPaisa(profit),
        totalReceivables: Money.fromPaisa(receivables > 0 ? receivables : 0),
        totalPayables: Money.fromPaisa(payables > 0 ? payables : 0),
        stockValue: Money.fromPaisa(stockValue),
        totalMedicines: totalMeds,
        lowStockCount: lowCount,
        expiredCount: expiredCount,
        expiringSoonCount: expiringCount,
        todayTransactions: todayTx,
        salesTrend: trend,
        topSelling: topSelling,
      ));
    } catch (e) {
      return Failure(ServerFailure(message: 'Failed to compute metrics: $e'));
    }
  }
}