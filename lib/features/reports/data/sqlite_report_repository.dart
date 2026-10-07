import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../../medicines/domain/value_objects.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';

class SqliteReportRepository implements ReportRepository {
  final DatabaseHelper _dbHelper;

  SqliteReportRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

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
      return Failure(DatabaseFailure(message: 'Report generation failed: $e'));
    }
  }

  // ─── SALES REPORT ──────────────────────────────────────────

  Future<Result<ReportResult>> _salesReport(ReportFilter f) async {
    final db = await _db;
    final dw = _dateWhere('s.created_at', f);
    final da = _dateArgs(f);

    final rows = await db.rawQuery('''
      SELECT s.invoice_number AS col0,
             s.customer_name AS col1,
             s.created_at AS col2,
             s.grand_total AS col3,
             s.discount AS col4,
             s.status AS col5
      FROM sales s
      ${dw != null ? 'WHERE $dw' : ''}
      ORDER BY s.created_at DESC
    ''', da);

    int totalRevenue = 0;
    int totalDiscount = 0;
    final resultRows = rows.map((r) {
      totalRevenue += (r['col3'] as num).toInt();
      totalDiscount += (r['col4'] as num).toInt();
      return ReportRow(r);
    }).toList();

    return Success(ReportResult(
      type: ReportType.sales,
      headers: ['Invoice', 'Customer', 'Date', 'Total', 'Discount', 'Status'],
      rows: resultRows,
      summaryTotals: {
        'Revenue': Money.fromPaisa(totalRevenue),
        'Discount': Money.fromPaisa(totalDiscount),
      },
      totalRowCount: resultRows.length,
    ));
  }

  // ─── PURCHASE REPORT ───────────────────────────────────────

  Future<Result<ReportResult>> _purchaseReport(ReportFilter f) async {
    final db = await _db;
    final dw = _dateWhere('p.created_at', f);
    final da = _dateArgs(f);

    final rows = await db.rawQuery('''
      SELECT p.invoice_number AS col0,
             p.supplier_name AS col1,
             p.created_at AS col2,
             p.grand_total AS col3,
             p.status AS col4
      FROM purchases p
      ${dw != null ? 'WHERE $dw' : ''}
      ORDER BY p.created_at DESC
    ''', da);

    int totalCost = 0;
    final resultRows = rows.map((r) {
      totalCost += (r['col3'] as num).toInt();
      return ReportRow(r);
    }).toList();

    return Success(ReportResult(
      type: ReportType.purchases,
      headers: ['Invoice', 'Supplier', 'Date', 'Total', 'Status'],
      rows: resultRows,
      summaryTotals: {'Total Cost': Money.fromPaisa(totalCost)},
      totalRowCount: resultRows.length,
    ));
  }

  // ─── PROFIT REPORT ─────────────────────────────────────────

  Future<Result<ReportResult>> _profitReport(ReportFilter f) async {
    final db = await _db;
    final dw = _dateWhere('s.created_at', f);
    final da = _dateArgs(f);

    // Revenue per medicine
    final revenueRows = await db.rawQuery('''
      SELECT si.medicine_name AS col0,
             SUM(si.quantity) AS col1,
             SUM(si.line_total) AS col2
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      ${dw != null ? 'WHERE $dw' : ''}
      GROUP BY si.medicine_name
      ORDER BY col2 DESC
    ''', da);

    // COGS per medicine (using batch purchase price)
    final cogsRows = await db.rawQuery('''
      SELECT si.medicine_name AS name,
             SUM(si.quantity * b.purchase_price) AS cogs
      FROM sale_items si
      JOIN batches b ON si.batch_id = b.id
      JOIN sales s ON si.sale_id = s.id
      ${dw != null ? 'WHERE $dw' : ''}
      GROUP BY si.medicine_name
    ''', da);

    final cogsMap = <String, int>{};
    for (final r in cogsRows) {
      cogsMap[r['name'] as String] = (r['cogs'] as num).toInt();
    }

    int totalRevenue = 0;
    int totalCogs = 0;
    final resultRows = <ReportRow>[];

    for (final r in revenueRows) {
      final name = r['col0'] as String;
      final qty = (r['col1'] as num).toInt();
      final rev = (r['col2'] as num).toInt();
      final cogs = cogsMap[name] ?? 0;
      final profit = rev - cogs;

      totalRevenue += rev;
      totalCogs += cogs;

      resultRows.add(ReportRow({
        'col0': name,
        'col1': qty,
        'col2': rev,
        'col3': cogs,
        'col4': profit,
      }));
    }

    return Success(ReportResult(
      type: ReportType.profit,
      headers: ['Medicine', 'Qty Sold', 'Revenue', 'COGS', 'Profit'],
      rows: resultRows,
      summaryTotals: {
        'Revenue': Money.fromPaisa(totalRevenue),
        'COGS': Money.fromPaisa(totalCogs),
        'Gross Profit': Money.fromPaisa(totalRevenue - totalCogs),
      },
      totalRowCount: resultRows.length,
    ));
  }

  // ─── INVENTORY REPORT ──────────────────────────────────────

  Future<Result<ReportResult>> _inventoryReport(ReportFilter f) async {
    final db = await _db;

    final rows = await db.rawQuery('''
      SELECT m.name AS col0,
             m.generic_name AS col1,
             COALESCE(s.quantity, 0) AS col2,
             m.selling_price AS col3,
             m.purchase_price AS col4
      FROM medicines m
      LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
      WHERE m.status = 'active'
      ORDER BY m.name ASC
    ''');

    int totalValue = 0;
    int totalUnits = 0;
    final resultRows = rows.map((r) {
      final qty = (r['col2'] as num).toInt();
      final price = (r['col4'] as num).toInt();
      totalValue += qty * price;
      totalUnits += qty;
      return ReportRow(r);
    }).toList();

    return Success(ReportResult(
      type: ReportType.inventory,
      headers: ['Medicine', 'Generic', 'Stock', 'Sale Price', 'Purchase Price'],
      rows: resultRows,
      summaryTotals: {
        'Total Units': Money.fromPaisa(totalUnits),
        'Stock Value (Cost)': Money.fromPaisa(totalValue),
      },
      totalRowCount: resultRows.length,
    ));
  }

  // ─── EXPIRY REPORT ─────────────────────────────────────────

  Future<Result<ReportResult>> _expiryReport(ReportFilter f) async {
    final db = await _db;

    final rows = await db.rawQuery('''
      SELECT m.name AS col0,
             b.batch_number AS col1,
             b.expiry_date AS col2,
             b.quantity AS col3,
             b.selling_price AS col4
      FROM batches b
      JOIN medicines m ON b.medicine_id = m.id
      WHERE b.quantity > 0
      ORDER BY b.expiry_date ASC
    ''');

    final now = DateTime.now();
    final soon = now.add(const Duration(days: 90));

    int expiredQty = 0;
    int expiringQty = 0;
    final resultRows = rows.map((r) {
      final expDate = DateTime.parse(r['col2'] as String);
      final qty = (r['col3'] as num).toInt();
      if (expDate.isBefore(now)) expiredQty += qty;
      if (!expDate.isBefore(now) && expDate.isBefore(soon)) expiringQty += qty;
      return ReportRow(r);
    }).toList();

    return Success(ReportResult(
      type: ReportType.expiry,
      headers: ['Medicine', 'Batch', 'Expiry', 'Qty', 'Price'],
      rows: resultRows,
      summaryTotals: {
        'Expired Units': Money.fromPaisa(expiredQty),
        'Expiring Soon': Money.fromPaisa(expiringQty),
      },
      totalRowCount: resultRows.length,
    ));
  }

  // ─── CUSTOMER REPORT ───────────────────────────────────────

  Future<Result<ReportResult>> _customerReport(ReportFilter f) async {
    final db = await _db;

    final rows = await db.rawQuery('''
      SELECT c.name AS col0,
             c.phone AS col1,
             COALESCE(SUM(le.debit), 0) - COALESCE(SUM(le.credit), 0) AS col2
      FROM customers c
      LEFT JOIN customer_ledger_entries le ON c.id = le.customer_id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''');

    int totalOutstanding = 0;
    final resultRows = rows.map((r) {
      final out = (r['col2'] as num).toInt();
      totalOutstanding += out > 0 ? out : 0;
      return ReportRow(r);
    }).toList();

    return Success(ReportResult(
      type: ReportType.customers,
      headers: ['Customer', 'Phone', 'Outstanding'],
      rows: resultRows,
      summaryTotals: {'Total Receivable': Money.fromPaisa(totalOutstanding)},
      totalRowCount: resultRows.length,
    ));
  }

  // ─── SUPPLIER REPORT ───────────────────────────────────────

  Future<Result<ReportResult>> _supplierReport(ReportFilter f) async {
    final db = await _db;

    final rows = await db.rawQuery('''
      SELECT s.name AS col0,
             s.phone AS col1,
             COALESCE(SUM(le.credit), 0) - COALESCE(SUM(le.debit), 0) AS col2
      FROM suppliers s
      LEFT JOIN supplier_ledger_entries le ON s.id = le.supplier_id
      GROUP BY s.id
      ORDER BY s.name ASC
    ''');

    int totalPayable = 0;
    final resultRows = rows.map((r) {
      final pay = (r['col2'] as num).toInt();
      totalPayable += pay > 0 ? pay : 0;
      return ReportRow(r);
    }).toList();

    return Success(ReportResult(
      type: ReportType.suppliers,
      headers: ['Supplier', 'Phone', 'Payable'],
      rows: resultRows,
      summaryTotals: {'Total Payable': Money.fromPaisa(totalPayable)},
      totalRowCount: resultRows.length,
    ));
  }

  // ─── ACCOUNT REPORT ────────────────────────────────────────

  Future<Result<ReportResult>> _accountReport(ReportFilter f) async {
    final db = await _db;

    final rows = await db.rawQuery('''
      SELECT a.name AS col0,
             a.account_type AS col1,
             a.opening_balance AS col2,
             COALESCE(SUM(ft.debit), 0) - COALESCE(SUM(ft.credit), 0) AS col3
      FROM accounts a
      LEFT JOIN financial_transactions ft ON a.id = ft.account_id
      GROUP BY a.id
      ORDER BY a.name ASC
    ''');

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
      headers: ['Account', 'Type', 'Opening', 'Current Balance'],
      rows: resultRows,
      totalRowCount: resultRows.length,
    ));
  }

  // ─── BUSINESS METRICS ──────────────────────────────────────

  @override
  Future<Result<BusinessMetrics>> getBusinessMetrics() async {
    try {
      final db = await _db;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      // Revenue
      final todayRev = await _sumColumn(db, 'sales', 'grand_total', 'created_at', startOfDay);
      final monthRev = await _sumColumn(db, 'sales', 'grand_total', 'created_at', startOfMonth);
      final todayTx = await _countRows(db, 'sales', 'created_at', startOfDay);

      // Purchases
      final monthPur = await _sumColumn(db, 'purchases', 'grand_total', 'created_at', startOfMonth);

      // Expenses
      final monthExp = await _sumColumn(db, 'expenses', 'amount', 'expense_date', startOfMonth);

      // Receivables & Payables
      final recRows = await db.rawQuery('''
        SELECT COALESCE(SUM(debit), 0) - COALESCE(SUM(credit), 0) AS bal
        FROM customer_ledger_entries
      ''');
      final receivables = recRows.isEmpty ? 0 : (recRows.first['bal'] as num).toInt();

      final payRows = await db.rawQuery('''
        SELECT COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0) AS bal
        FROM supplier_ledger_entries
      ''');
      final payables = payRows.isEmpty ? 0 : (payRows.first['bal'] as num).toInt();

      // Stock value
      final stockRows = await db.rawQuery('''
        SELECT COALESCE(SUM(s.quantity * m.purchase_price), 0) AS val,
               COUNT(DISTINCT m.id) AS meds
        FROM medicines m
        LEFT JOIN inventory_stocks s ON m.id = s.medicine_id
        WHERE m.status = 'active'
      ''');
      final stockValue = stockRows.isEmpty ? 0 : (stockRows.first['val'] as num).toInt();
      final totalMeds = stockRows.isEmpty ? 0 : (stockRows.first['meds'] as num).toInt();

      // Low stock
      final lowRows = await db.rawQuery('''
        SELECT COUNT(*) AS cnt FROM inventory_stocks s
        JOIN medicines m ON s.medicine_id = m.id
        WHERE s.quantity <= m.min_stock_level AND s.quantity > 0
      ''');
      final lowCount = lowRows.isEmpty ? 0 : (lowRows.first['cnt'] as num).toInt();

      // Expiry
      final expRows = await db.rawQuery('''
        SELECT COUNT(*) AS cnt FROM batches
        WHERE expiry_date < ? AND quantity > 0
      ''', [now.toIso8601String()]);
      final expiredCount = expRows.isEmpty ? 0 : (expRows.first['cnt'] as num).toInt();

      final soonRows = await db.rawQuery('''
        SELECT COUNT(*) AS cnt FROM batches
        WHERE expiry_date >= ? AND expiry_date <= ? AND quantity > 0
      ''', [now.toIso8601String(), now.add(const Duration(days: 90)).toIso8601String()]);
      final expiringCount = soonRows.isEmpty ? 0 : (soonRows.first['cnt'] as num).toInt();

      // Sales trend (last 7 days)
      final trend = <DailyTrend>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day).toIso8601String();
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
        final tRows = await db.rawQuery('''
          SELECT COALESCE(SUM(grand_total), 0) AS total
          FROM sales WHERE created_at >= ? AND created_at <= ?
        ''', [dayStart, dayEnd]);
        final total = tRows.isEmpty ? 0 : (tRows.first['total'] as num).toInt();
        trend.add(DailyTrend(
          dateLabel: '${day.day}/${day.month}',
          revenue: Money.fromPaisa(total),
        ));
      }

      // Top selling (this month)
      final topRows = await db.rawQuery('''
        SELECT si.medicine_name AS name,
               SUM(si.quantity) AS qty,
               SUM(si.line_total) AS rev
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.created_at >= ?
        GROUP BY si.medicine_name
        ORDER BY rev DESC
        LIMIT 5
      ''', [startOfMonth]);

      final topSelling = topRows.map((r) => CategoryBreakdown(
        name: r['name'] as String,
        quantity: (r['qty'] as num).toInt(),
        revenue: Money.fromPaisa((r['rev'] as num).toInt()),
      )).toList();

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
      return Failure(DatabaseFailure(message: 'Failed to compute metrics: $e'));
    }
  }

  Future<int> _sumColumn(
      Database db,
      String table,
      String column,
      String dateCol,
      String since,
      ) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM($column), 0) AS total FROM $table WHERE $dateCol >= ?',
      [since],
    );
    return rows.isEmpty ? 0 : (rows.first['total'] as num).toInt();
  }

  Future<int> _countRows(
      Database db,
      String table,
      String dateCol,
      String since,
      ) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $table WHERE $dateCol >= ?',
      [since],
    );
    return rows.isEmpty ? 0 : (rows.first['cnt'] as num).toInt();
  }
}