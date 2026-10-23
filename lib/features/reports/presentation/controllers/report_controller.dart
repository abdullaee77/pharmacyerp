import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:pharmacy/core/services/app_event_bus.dart';
import '../../application/report_use_cases.dart';
import '../../domain/report_models.dart';
import '../../domain/report_repository.dart';

// ─── PUBLIC MODEL FOR DASHBOARD BREAKDOWN ───────────────────────────
class BreakdownRow {
  final String primary;
  final String secondary;
  final String amount;
  const BreakdownRow({
    required this.primary,
    required this.secondary,
    required this.amount,
  });
}

class ReportController extends ChangeNotifier {
  final GenerateReportUseCase _generateReport;
  final GetBusinessMetricsUseCase _getMetrics;
  StreamSubscription<AppEvent>? _eventSubscription;

  ReportController({required ReportRepository repository})
      : _generateReport = GenerateReportUseCase(repository),
        _getMetrics = GetBusinessMetricsUseCase(repository) {
    _eventSubscription = AppEventBus.instance.stream.listen((event) {
      if (event == AppEvent.saleCompleted ||
          event == AppEvent.saleReturned ||
          event == AppEvent.purchaseCompleted ||
          event == AppEvent.purchaseReturned ||
          event == AppEvent.expenseAdded ||
          event == AppEvent.supplierPaymentRecorded ||
          event == AppEvent.customerPaymentRecorded ||
          event == AppEvent.accountChanged ||
          event == AppEvent.inventoryAdjusted ||
          event == AppEvent.batchChanged ||
          event == AppEvent.medicineUpdated) {
        loadMetrics(silent: true);
        if (_currentReport != null) {
          generateReport(silent: true);
        }
      }
    });
  }

  ReportType _selectedType = ReportType.sales;
  ReportFilter _filter = ReportFilter.thisMonth();
  ReportResult? _currentReport;
  BusinessMetrics? _metrics;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _error;

  ReportType get selectedType => _selectedType;
  ReportFilter get filter => _filter;
  ReportResult? get currentReport => _currentReport;
  BusinessMetrics? get metrics => _metrics;
  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
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

  Future<void> generateReport({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _generateReport.execute(_selectedType, _filter);
    result.fold(
      onSuccess: (data) {
        _currentReport = data;
        _error = null;
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

  Future<void> loadMetrics({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getMetrics.execute();
    result.fold(
      onSuccess: (data) {
        _metrics = data;
        _error = null;
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

  // ─── BREAKDOWN DATA FOR DASHBOARD KPI DIALOGS ─────────────────────
  Future<List<BreakdownRow>> exportReportData(
      ReportType type,
      ReportFilter filter,
      ) async {
    final result = await _generateReport.execute(type, filter);
    return result.fold(
      onSuccess: (report) {
        return report.rows.map((row) {
          switch (type) {
            case ReportType.sales:
              final customer =
              row.string1.trim().isEmpty ? 'Walk-in' : row.string1;
              return BreakdownRow(
                primary: customer,
                secondary:
                'Invoice ${row.string0} • ${_shortDate(row.string2)}',
                amount: _paisaToMoney(row.string3),
              );

            case ReportType.purchases:
              final supplier =
              row.string1.trim().isEmpty ? 'Unknown' : row.string1;
              return BreakdownRow(
                primary: supplier,
                secondary:
                'Invoice ${row.string0} • ${_shortDate(row.string2)}',
                amount: _paisaToMoney(row.string3),
              );

            case ReportType.profit:
              return BreakdownRow(
                primary: row.string0,
                secondary:
                'Qty: ${row.string1} • COGS: ${_paisaToMoney(row.string3)}',
                amount: _paisaToMoney(row.string4),
              );

            case ReportType.inventory:
              final qty = int.tryParse(row.string2) ?? 0;
              final pp = int.tryParse(row.string3) ?? 0;
              final value = qty * pp;
              return BreakdownRow(
                primary: row.string0,
                secondary: '${row.string1} • Stock: ${row.string2}',
                amount: _paisaToMoney(value.toString()),
              );

            default:
              return BreakdownRow(
                primary: row.string0,
                secondary: row.string1,
                amount: row.string2,
              );
          }
        }).toList();
      },
      onFailure: (_) => <BreakdownRow>[],
    );
  }

  // ─── EXPORT TO PDF ────────────────────────────────────────────────
  Future<String?> exportToPdf() async {
    final report = _currentReport;
    if (report == null || report.rows.isEmpty) return null;

    _isExporting = true;
    notifyListeners();

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                report.type.label,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Period: ${_fmtDate(_filter.fromDate)} — ${_fmtDate(_filter.toDate)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5, color: PdfColors.blue800),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (pw.Context ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by PharmaSuite ERP',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
          build: (pw.Context ctx) {
            final widgets = <pw.Widget>[];

            if (report.summaryTotals.isNotEmpty) {
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: report.summaryTotals.entries.map((e) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(e.key,
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700)),
                          pw.Text(e.value.display,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 16));
            }

            final headerStyle = pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            );
            final cellStyle = pw.TextStyle(fontSize: 8);

            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                tableWidth: pw.TableWidth.max,
                children: [
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: PdfColors.blue800),
                    children: report.headers.map((h) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 6, horizontal: 6),
                        child: pw.Text(h, style: headerStyle),
                      );
                    }).toList(),
                  ),
                  for (var i = 0; i < report.rows.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color:
                        i.isEven ? PdfColors.white : PdfColors.grey50,
                      ),
                      children:
                      _rowValues(report.rows[i], report.headers.length)
                          .map((val) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 4, horizontal: 6),
                          child: pw.Text(val, style: cellStyle),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );

            widgets.add(pw.SizedBox(height: 12));
            widgets.add(
              pw.Text(
                'Total rows: ${report.totalRowCount}',
                style:
                pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            );

            return widgets;
          },
        ),
      );

      final bytes = await doc.save();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${report.type.name}_report_$timestamp.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Printing.sharePdf(bytes: bytes, filename: fileName);

      _isExporting = false;
      notifyListeners();
      return file.path;
    } catch (e) {
      _isExporting = false;
      _error = 'PDF export failed: $e';
      notifyListeners();
      return null;
    }
  }

  // ─── EXPORT TO EXCEL ──────────────────────────────────────────────
  Future<String?> exportToExcel() async {
    final report = _currentReport;
    if (report == null || report.rows.isEmpty) return null;

    _isExporting = true;
    notifyListeners();

    try {
      final excel = Excel.createExcel();
      final sheetName = report.type.label;
      final sheet = excel[sheetName];

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(
            columnIndex: report.headers.length - 1, rowIndex: 0),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue(report.type.label);

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(
            columnIndex: report.headers.length - 1, rowIndex: 1),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = TextCellValue(
          'Period: ${_fmtDate(_filter.fromDate)} — ${_fmtDate(_filter.toDate)}');

      int rowIdx = 3;
      if (report.summaryTotals.isNotEmpty) {
        for (final entry in report.summaryTotals.entries) {
          sheet
              .cell(CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: rowIdx))
              .value = TextCellValue(entry.key);
          sheet
              .cell(CellIndex.indexByColumnRow(
              columnIndex: 1, rowIndex: rowIdx))
              .value = TextCellValue(entry.value.display);
          rowIdx++;
        }
        rowIdx++;
      }

      for (int c = 0; c < report.headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));
        cell.value = TextCellValue(report.headers[c]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
          fontColorHex: ExcelColor.white,
        );
      }
      rowIdx++;

      for (final row in report.rows) {
        final values = _rowValues(row, report.headers.length);
        for (int c = 0; c < values.length; c++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));

          final numVal = num.tryParse(values[c].replaceAll(',', ''));
          if (numVal != null && values[c].trim().isNotEmpty) {
            cell.value = numVal is int
                ? IntCellValue(numVal)
                : DoubleCellValue(numVal.toDouble());
          } else {
            cell.value = TextCellValue(values[c]);
          }
        }
        rowIdx++;
      }

      for (int c = 0; c < report.headers.length; c++) {
        sheet.setColumnWidth(c, 18.0);
      }

      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        _error = 'Excel encoding returned null';
        _isExporting = false;
        notifyListeners();
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${report.type.name}_report_$timestamp.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      _isExporting = false;
      notifyListeners();
      return file.path;
    } catch (e) {
      _isExporting = false;
      _error = 'Excel export failed: $e';
      notifyListeners();
      return null;
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────
  List<String> _rowValues(ReportRow row, int colCount) {
    final allValues = [
      row.string0,
      row.string1,
      row.string2,
      row.string3,
      row.string4,
      row.string5,
    ];
    return List.generate(
      colCount,
          (i) => i < allValues.length ? allValues[i] : '',
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _paisaToMoney(String paisaStr) {
    final paisa = int.tryParse(paisaStr.replaceAll(',', '')) ?? 0;
    final rupees = paisa / 100;
    final formatted = rupees.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
    return 'PKR $formatted';
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}