// lib/features/inventory/presentation/widgets/batch_bulk_import_dialog.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/batch.dart';

class _ParsedRow {
  final int rowNumber;
  final Batch? batch;
  final String? error;
  final Map<String, String> raw;

  _ParsedRow.ok(this.rowNumber, Batch this.batch, this.raw) : error = null;
  _ParsedRow.err(this.rowNumber, this.error, this.raw) : batch = null;

  bool get isOk => batch != null;
}

/// Bulk batch import. Each row is matched to an existing medicine by
/// NAME + STRENGTH. Pops with a List<Batch> of the valid rows.
class BatchBulkImportDialog extends StatefulWidget {
  final List<Medicine> medicines;

  const BatchBulkImportDialog({super.key, required this.medicines});

  @override
  State<BatchBulkImportDialog> createState() => _BatchBulkImportDialogState();
}

class _BatchBulkImportDialogState extends State<BatchBulkImportDialog> {
  List<_ParsedRow> _rows = [];
  String? _fileName;
  bool _loading = false;
  bool _previewingSample = false;
  bool _downloadingSample = false;
  bool _isSampleLoaded = false;
  bool _showFormatHelp = false;
  String? _error;

  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  bool _isSyncingScroll = false;

  // Medicine lookup indexes (built once)
  final Map<String, List<Medicine>> _byName = {};
  final Map<String, List<Medicine>> _byCombined = {};

  static const _headers = [
    'medicine_name',
    'strength',
    'formula',           // ← ADD THIS
    'batch_number',
    'expiry_date',
    'quantity',
    'purchase_price',
    'selling_price',
  ];

  static const List<double> _columnWidths = [
    190, // medicine_name
    100, // strength
    160, // formula          // ← ADD THIS
    150, // batch_number
    120, // expiry_date
    90, // quantity
    120, // purchase_price
    120, // selling_price
  ];

  static const double _rowNumColWidth = 48;
  static const double _statusColWidth = 44;

  bool get _isBusy => _loading || _previewingSample || _downloadingSample;
  bool get _hasData => _rows.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final m in widget.medicines) {
      _byName.putIfAbsent(_normName(m.name), () => []).add(m);
      _byCombined
          .putIfAbsent(_normName('${m.name} ${m.strength}'), () => [])
          .add(m);
    }
    _bodyHScroll.addListener(_onBodyScroll);
    _headerHScroll.addListener(_onHeaderScroll);
  }

  void _onBodyScroll() {
    if (_isSyncingScroll) return;
    if (!_headerHScroll.hasClients) return;
    _isSyncingScroll = true;
    _headerHScroll.jumpTo(
      _bodyHScroll.offset.clamp(
        _headerHScroll.position.minScrollExtent,
        _headerHScroll.position.maxScrollExtent,
      ),
    );
    _isSyncingScroll = false;
  }

  void _onHeaderScroll() {
    if (_isSyncingScroll) return;
    if (!_bodyHScroll.hasClients) return;
    _isSyncingScroll = true;
    _bodyHScroll.jumpTo(
      _headerHScroll.offset.clamp(
        _bodyHScroll.position.minScrollExtent,
        _bodyHScroll.position.maxScrollExtent,
      ),
    );
    _isSyncingScroll = false;
  }

  @override
  void dispose() {
    _headerHScroll.removeListener(_onHeaderScroll);
    _bodyHScroll.removeListener(_onBodyScroll);
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Matching helpers
  // ---------------------------------------------------------------------
  static String _normName(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _normStrength(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  Medicine _findMedicine(String name, String strength) {
    final n = _normName(name);
    final s = _normStrength(strength);

    List<Medicine> matches = (_byName[n] ?? const <Medicine>[])
        .where((m) => s.isEmpty || _normStrength(m.strength) == s)
        .toList();

    // Fallback: "Panadol 500mg" typed fully inside the name column.
    if (matches.isEmpty && s.isEmpty) {
      matches = _byCombined[n] ?? const <Medicine>[];
    }

    final label = strength.isEmpty ? name : '$name $strength';
    if (matches.isEmpty) {
      throw 'No medicine "$label" found in catalog';
    }
    if (matches.length > 1) {
      throw 'More than one medicine matches "$label" — fill the strength column';
    }
    return matches.first;
  }

  // ---------------------------------------------------------------------
  // Date parsing: dd/MM/yyyy, yyyy-MM-dd, MM/yyyy, dd-MM-yyyy, Excel serial
  // ---------------------------------------------------------------------
  static DateTime? _parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // Excel serial number (e.g. 46022)
    final serial = double.tryParse(s);
    if (serial != null && serial > 20000 && serial < 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    }

    // Excel DateCellValue(year: 2026, month: 12, day: 31 ...)
    final cell = RegExp(r'year:\s*(\d{4}).*?month:\s*(\d{1,2}).*?day:\s*(\d{1,2})')
        .firstMatch(s);
    if (cell != null) {
      return _safeDate(int.parse(cell.group(1)!), int.parse(cell.group(2)!),
          int.parse(cell.group(3)!));
    }

    // yyyy-MM-dd (also with time part)
    final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
    if (iso != null) {
      return _safeDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }

    final parts = s.split(RegExp(r'[\/\-\.]')).map((e) => e.trim()).toList();

    // MM/yyyy or yyyy-MM  -> last day of that month
    if (parts.length == 2) {
      int? a = int.tryParse(parts[0]);
      int? b = int.tryParse(parts[1]);
      if (a == null || b == null) return null;
      int year, month;
      if (parts[0].length == 4) {
        year = a;
        month = b;
      } else {
        month = a;
        year = parts[1].length == 2 ? 2000 + b : b;
      }
      if (month < 1 || month > 12) return null;
      return DateTime(year, month + 1, 0);
    }

    // dd/MM/yyyy
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      var y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) return null;
      if (parts[2].length == 2) y += 2000;
      return _safeDate(y, m, d);
    }
    return null;
  }

  static DateTime? _safeDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    if (dt.month != m) return null; // e.g. 31 Feb
    return dt;
  }

  // ---------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------
  List<_ParsedRow> _parseTable(List<List<String>> table) {
    if (table.isEmpty) return [];

    final headerRow = table.first
        .map((e) => e.trim().toLowerCase().replaceAll(' ', '_'))
        .toList();
    final dataRows = table.skip(1).toList();

    final seen = <String>{};
    final parsed = <_ParsedRow>[];
    for (var i = 0; i < dataRows.length; i++) {
      final rowNum = i + 2;
      final raw = <String, String>{};
      for (var c = 0; c < headerRow.length && c < dataRows[i].length; c++) {
        raw[headerRow[c]] = dataRows[i][c].trim();
      }
      if (raw.values.every((v) => v.isEmpty)) continue;

      try {
        final batch = _buildBatch(raw, seen);
        parsed.add(_ParsedRow.ok(rowNum, batch, raw));
      } catch (e) {
        parsed.add(_ParsedRow.err(rowNum, e.toString(), raw));
      }
    }
    return parsed;
  }

  Batch _buildBatch(Map<String, String> row, Set<String> seen) {
    final name = row['medicine_name'] ?? '';
    if (name.isEmpty) throw 'Column "medicine_name" is required';

    final med = _findMedicine(name, row['strength'] ?? '');

    final batchNo = BatchNumber.create(row['batch_number'] ?? '');
    if (batchNo == null) {
      throw 'Column "batch_number" is required (max 40 characters)';
    }

    final expiryRaw = row['expiry_date'] ?? '';
    if (expiryRaw.isEmpty) throw 'Column "expiry_date" is required';
    final expiryDt = _parseDate(expiryRaw);
    if (expiryDt == null) {
      throw 'Invalid expiry_date "$expiryRaw" (use dd/MM/yyyy or MM/yyyy)';
    }

    final qd = double.tryParse(row['quantity'] ?? '');
    if (qd == null || qd < 0 || qd != qd.roundToDouble()) {
      throw 'Column "quantity" must be a whole number (0 or more)';
    }

    final purchase = _parsePrice(row['purchase_price'], med.purchasePrice);
    final selling = _parsePrice(row['selling_price'], med.sellingPrice);

    final dupKey = '${med.id.value}|${batchNo.value.toLowerCase()}';
    if (!seen.add(dupKey)) {
      throw 'Duplicate batch "${batchNo.value}" for this medicine in the file';
    }

    final now = DateTime.now();
    final expiry = ExpiryDate(expiryDt);
    return Batch(
      id: BatchId.generate(),
      medicineId: med.id,
      medicineName: '${med.name} ${med.strength}'.trim(),
      batchNumber: batchNo,
      expiryDate: expiry,
      quantity: Quantity.create(qd.toInt()),
      purchasePrice: purchase,
      sellingPrice: selling,
      status: Batch.deriveStatus(expiry),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Blank price -> falls back to the medicine's own price.
  Money _parsePrice(String? raw, Money fallback) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return fallback;
    final v = double.tryParse(t);
    if (v == null || v < 0) throw 'Invalid price "$t"';
    return Money.fromPkr(v);
  }

  // ---------------------------------------------------------------------
  // Sample
  // ---------------------------------------------------------------------
  List<List<String>> _sampleTable() {
    final now = DateTime.now();
    final table = <List<String>>[List<String>.from(_headers)];
    final meds = widget.medicines.take(3).toList();

    if (meds.isEmpty) {
      table.addAll([
        ['Panadol', '500mg', 'Paracetamol 500mg', 'BN-001', '31/12/${now.year + 2}', '100', '2.50', '4.00'],
        ['Augmentin', '625mg', 'Amoxicillin 500mg + Clavulanic Acid 125mg', 'BN-002', '30/06/${now.year + 2}', '50', '25.00', '35.00'],
      ]);
      return table;
    }

    for (var i = 0; i < meds.length; i++) {
      final m = meds[i];
      table.add([
        m.name,
        m.strength,
        m.formula,     // ← ADD THIS
        'BN-${now.year}-00${i + 1}',
        '31/12/${now.year + 2}',
        '100',
        m.purchasePrice.pkr.toStringAsFixed(2),
        m.sellingPrice.pkr.toStringAsFixed(2),
      ]);
    }
    return table;
  }

  Future<void> _downloadSample() async {
    setState(() {
      _downloadingSample = true;
      _error = null;
    });

    try {
      final csvContent = const ListToCsvConverter().convert(_sampleTable());

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save batches import template',
        fileName: 'batches_import_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath == null) {
        setState(() => _downloadingSample = false);
        return;
      }

      final path =
      savePath.toLowerCase().endsWith('.csv') ? savePath : '$savePath.csv';
      await File(path).writeAsString(csvContent);

      if (!mounted) return;
      setState(() => _downloadingSample = false);
      AppToast.success(context, 'Sample template saved to:\n$path');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingSample = false;
        _error = 'Failed to download sample: $e';
      });
    }
  }

  Future<void> _previewSample() async {
    setState(() {
      _previewingSample = true;
      _error = null;
      _rows = [];
    });

    try {
      final parsed = _parseTable(_sampleTable());
      setState(() {
        _fileName = 'Sample Batches';
        _rows = parsed;
        _isSampleLoaded = true;
        _previewingSample = false;
      });
    } catch (e) {
      setState(() {
        _previewingSample = false;
        _error = 'Could not build sample data: $e';
      });
    }
  }

  // ---------------------------------------------------------------------
  // File reading
  // ---------------------------------------------------------------------
  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
      _isSampleLoaded = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }

      final path = result.files.single.path!;
      final name = result.files.single.name;
      _fileName = name;

      List<List<String>> table;
      if (name.toLowerCase().endsWith('.csv')) {
        table = await _readCsv(path);
      } else {
        table = await _readExcel(path);
      }

      if (table.isEmpty) {
        setState(() {
          _error = 'File is empty.';
          _loading = false;
        });
        return;
      }

      final parsed = _parseTable(table);
      setState(() {
        _rows = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to read file: $e';
        _loading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _rows = [];
      _fileName = null;
      _isSampleLoaded = false;
      _error = null;
    });
    if (_headerHScroll.hasClients) _headerHScroll.jumpTo(0);
    if (_bodyHScroll.hasClients) _bodyHScroll.jumpTo(0);
  }

  Future<List<List<String>>> _readCsv(String path) async {
    final content = await File(path).readAsString();
    final raw = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);
    return raw
        .map((r) => r.map((c) => (c ?? '').toString()).toList())
        .toList();
  }

  Future<List<List<String>>> _readExcel(String path) async {
    final bytes = await File(path).readAsBytes();

    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw 'This Excel file uses formatting (like Tables/AutoFilter) that '
          'isn\'t supported. Convert the table to a normal range and save '
          'again, or save the file as CSV.';
    }

    if (excel.tables.isEmpty) return [];

    Sheet? sheet;
    for (final key in excel.tables.keys) {
      final candidate = excel.tables[key];
      if (candidate != null && candidate.rows.isNotEmpty) {
        sheet = candidate;
        break;
      }
    }
    if (sheet == null) return [];

    final out = <List<String>>[];
    for (final row in sheet.rows) {
      out.add(row.map((c) {
        final v = c?.value;
        if (v == null) return '';
        return v.toString().trim();
      }).toList());
    }
    return out;
  }

  void _import() {
    final valid = _rows.where((r) => r.isOk).map((r) => r.batch!).toList();
    Navigator.of(context).pop(valid);
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final okCount = _rows.where((r) => r.isOk).length;
    final errCount = _rows.length - okCount;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: _isBusy
                    ? const Center(child: CircularProgressIndicator())
                    : _hasData
                    ? _buildReviewState(okCount, errCount)
                    : _buildUploadState(),
              ),
            ),
            _buildFooter(okCount),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.layers_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Import Batches',
                  style: AppTypography.pageTitle
                      .copyWith(color: Colors.white, fontSize: 18),
                ),
                Text(
                  'Add many batches at once — matched to medicines by name + strength',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                        horizontal: AppSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cloud_upload_rounded,
                                size: 36, color: AppColors.primary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Click to browse a file',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports .csv, .xlsx, .xls',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ),
                      Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Preview Sample',
                          icon: Icons.visibility_rounded,
                          variant: AppButtonVariant.outlined,
                          isFullWidth: true,
                          onPressed: _previewSample,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: 'Download Sample',
                          icon: Icons.download_rounded,
                          variant: AppButtonVariant.outlined,
                          isFullWidth: true,
                          onPressed: _downloadSample,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The sample uses medicines from your catalog',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) _buildErrorBanner(),
        _buildFormatHelpToggle(),
      ],
    );
  }

  Widget _buildReviewState(int okCount, int errCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _isSampleLoaded
                  ? Icons.auto_awesome_rounded
                  : Icons.description_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _fileName ?? '',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppButton(
              label: 'Download',
              icon: Icons.download_rounded,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: _downloadSample,
            ),
            AppButton(
              label: 'Start Over',
              icon: Icons.restart_alt_rounded,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: _reset,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.format_list_numbered_rounded,
                label: 'Total Rows',
                value: '${_rows.length}',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _statCard(
                icon: Icons.check_circle_rounded,
                label: 'Ready to Import',
                value: '$okCount',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _statCard(
                icon: Icons.error_rounded,
                label: 'Errors (Skipped)',
                value: '$errCount',
                color: errCount > 0 ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null) _buildErrorBanner(),
        Expanded(child: _buildSpreadsheetTable()),
        const SizedBox(height: AppSpacing.sm),
        _buildFormatHelpToggle(),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.pageTitle.copyWith(
                  fontSize: 18,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetTable() {
    final totalWidth = _rowNumColWidth +
        _statusColWidth +
        _columnWidths.fold<double>(0, (a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            controller: _headerHScroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              child: _buildColumnNameRow(),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                controller: _bodyHScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    children: List.generate(_rows.length, (index) {
                      return _buildDataRow(_rows[index], index);
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnNameRow() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          _gridCell(
            width: _rowNumColWidth,
            child: Text('#',
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          _gridCell(
            width: _statusColWidth,
            child: Icon(Icons.flag_outlined,
                size: 14, color: AppColors.textSecondary),
          ),
          for (var i = 0; i < _headers.length; i++)
            _gridCell(
              width: _columnWidths[i],
              child: Text(
                _headers[i],
                style:
                AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(_ParsedRow r, int index) {
    final isEven = index % 2 == 0;
    final bg = !r.isOk
        ? AppColors.error.withValues(alpha: 0.07)
        : (isEven
        ? Colors.transparent
        : AppColors.border.withValues(alpha: 0.12));

    return Container(
      color: bg,
      child: Row(
        children: [
          _gridCell(
            width: _rowNumColWidth,
            child: Text(
              '${r.rowNumber}',
              textAlign: TextAlign.center,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          _gridCell(
            width: _statusColWidth,
            child: Center(
              child: Tooltip(
                message: r.isOk ? 'Row OK' : (r.error ?? 'Invalid row'),
                child: Icon(
                  r.isOk ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 16,
                  color: r.isOk ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ),
          for (var i = 0; i < _headers.length; i++)
            _gridCell(
              width: _columnWidths[i],
              child: Text(
                r.raw[_headers[i]] ?? '',
                style: AppTypography.body.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _gridCell({required double width, required Widget child}) {
    return Container(
      width: width,
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
        ),
      ),
      child: child,
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatHelpToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _showFormatHelp = !_showFormatHelp),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  _showFormatHelp
                      ? 'Hide required format'
                      : 'View required column format',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                Icon(
                  _showFormatHelp
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_showFormatHelp)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required: medicine_name, batch_number, expiry_date, quantity. '
                      'Optional: strength, purchase_price, selling_price.',
                  style:
                  AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _headers.join(', '),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Medicine is matched by name + strength (spaces and capital '
                      'letters are ignored). If a name is unique you may leave '
                      'strength empty. Blank prices use the medicine\'s own prices.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Expiry formats: 31/12/2027, 2027-12-31 or 12/2027 '
                      '(month only = last day of that month). CSV is the most '
                      'reliable for dates.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(int okCount) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            label: _hasData
                ? 'Import $okCount Batch${okCount == 1 ? '' : 'es'}'
                : 'Import',
            icon: Icons.check_circle_rounded,
            variant: AppButtonVariant.primary,
            onPressed: okCount > 0 ? _import : null,
          ),
        ],
      ),
    );
  }
}