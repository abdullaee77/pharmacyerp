import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/medicine.dart';
import '../../domain/value_objects.dart';

class _ParsedRow {
  final int rowNumber;
  final Medicine? medicine;
  final String? error;
  final Map<String, String> raw;

  _ParsedRow.ok(this.rowNumber, Medicine this.medicine, this.raw) : error = null;
  _ParsedRow.err(this.rowNumber, this.error, this.raw) : medicine = null;

  bool get isOk => medicine != null;
}

class MedicineBulkImportDialog extends StatefulWidget {
  const MedicineBulkImportDialog({super.key});

  @override
  State<MedicineBulkImportDialog> createState() =>
      _MedicineBulkImportDialogState();
}

class _MedicineBulkImportDialogState extends State<MedicineBulkImportDialog> {
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

  static const _sampleAssetPath = 'assets/templates/medicines_import.csv';

  static const _headers = [
    'name',
    'generic_name',
    'formula',
    'manufacturer',
    'dosage_form',
    'strength',
    'category',
    'unit',
    'rack_location',
    'purchase_price',
    'selling_price',
    'mrp',
    'box_size',
    'min_stock',
    'barcode',
    'prescription_required',
  ];

  /// Fallback sample rows if asset is missing.
  static const _sampleDataRows = [
    [
      'Panadol',
      'Paracetamol',
      'Paracetamol 500mg',
      'GSK',
      'Tablet',
      '500mg',
      'Analgesic',
      'Tab',
      'A-01',
      '2.50',
      '4.00',
      '5.00',
      '20',
      '10',
      '',
      'no',
    ],
    [
      'Augmentin',
      'Amoxicillin + Clavulanic Acid',
      'Amoxicillin 500mg + Clavulanic Acid 125mg',
      'GSK',
      'Tablet',
      '625mg',
      'Antibiotic',
      'Tab',
      'B-03',
      '25.00',
      '35.00',
      '40.00',
      '14',
      '5',
      '',
      'yes',
    ],
    [
      'Disprin',
      'Aspirin',
      'Aspirin 300mg',                        // ← ADD THIS

      'Reckitt',
      'Tablet',
      '300mg',
      'Analgesic',
      'Tab',
      'A-02',
      '1.20',
      '2.00',
      '2.50',
      '10',
      '20',
      '',
      'no',
    ],
  ];

  static const List<double> _columnWidths = [
    150, // name
    170, // generic_name
    170, // formula
    130, // manufacturer
    100, // dosage_form
    90, // strength
    120, // category
    70, // unit
    110, // rack_location
    110, // purchase_price
    110, // selling_price
    90, // mrp
    80, // box_size
    80, // min_stock
    150, // barcode
    150, // prescription_required
  ];

  static const double _rowNumColWidth = 48;
  static const double _statusColWidth = 44;

  bool get _isBusy => _loading || _previewingSample || _downloadingSample;
  bool get _hasData => _rows.isNotEmpty;

  @override
  void initState() {
    super.initState();
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
  // Shared parsing logic
  // ---------------------------------------------------------------------
  List<_ParsedRow> _parseTable(List<List<String>> table) {
    if (table.isEmpty) return [];

    final headerRow = table.first.map((e) => e.trim().toLowerCase()).toList();
    final dataRows = table.skip(1).toList();

    final parsed = <_ParsedRow>[];
    for (var i = 0; i < dataRows.length; i++) {
      final rowNum = i + 2;
      final raw = <String, String>{};
      for (var c = 0; c < headerRow.length && c < dataRows[i].length; c++) {
        raw[headerRow[c]] = dataRows[i][c].trim();
      }
      if (raw.values.every((v) => v.isEmpty)) continue;

      try {
        final med = _buildMedicine(raw);
        parsed.add(_ParsedRow.ok(rowNum, med, raw));
      } catch (e) {
        parsed.add(_ParsedRow.err(rowNum, e.toString(), raw));
      }
    }
    return parsed;
  }

  Future<String> _buildSampleCsvContent() async {
    // Prefer the asset template if present; otherwise generate headers + samples.
    try {
      final content = await rootBundle.loadString(_sampleAssetPath);
      if (content.trim().isNotEmpty) return content;
    } catch (_) {}

    final table = <List<String>>[
      List<String>.from(_headers),
      ..._sampleDataRows.map((r) => List<String>.from(r)),
    ];
    return const ListToCsvConverter().convert(table);
  }

  Future<void> _downloadSample() async {
    setState(() {
      _downloadingSample = true;
      _error = null;
    });

    try {
      final csvContent = await _buildSampleCsvContent();

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save medicines import template',
        fileName: 'medicines_import_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath == null) {
        // User cancelled
        setState(() => _downloadingSample = false);
        return;
      }

      final path = savePath.toLowerCase().endsWith('.csv')
          ? savePath
          : '$savePath.csv';

      final file = File(path);
      await file.writeAsString(csvContent);

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
      final content = await _buildSampleCsvContent();
      final raw = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);
      final table =
      raw.map((r) => r.map((c) => (c ?? '').toString()).toList()).toList();

      final parsed = _parseTable(table);

      setState(() {
        _fileName = 'Sample Medicines';
        _rows = parsed;
        _isSampleLoaded = true;
        _previewingSample = false;
      });
    } catch (e) {
      setState(() {
        _previewingSample = false;
        _error = 'Could not load sample data. Make sure '
            '$_sampleAssetPath is declared under pubspec.yaml > flutter > '
            'assets, or use Download Sample Template.';
      });
    }
  }

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
          'isn\'t supported. In Excel: select your data → "Table Design" tab '
          '→ "Convert to Range" → save, then try again. Or save as CSV.';
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

  Medicine _buildMedicine(Map<String, String> row) {
    final name = row['name'] ?? '';
    if (name.isEmpty) {
      throw 'Column "name" is required';
    }

    final purchase = double.tryParse(row['purchase_price'] ?? '') ?? 0.0;
    final selling = double.tryParse(row['selling_price'] ?? '') ?? 0.0;
    final mrp = double.tryParse(row['mrp'] ?? '') ?? selling;
    final boxSize = int.tryParse(row['box_size'] ?? '') ?? 1;
    final minStock = int.tryParse(row['min_stock'] ?? '') ?? 0;
    final rxReq = _parseBool(row['prescription_required']);

    final now = DateTime.now();
    return Medicine(
      id: MedicineId.generate(),
      name: name,
      genericName: row['generic_name'] ?? '',
      formula: row['formula'] ?? '',          // ← ADD THIS
      manufacturer: row['manufacturer'] ?? '',
      dosageForm: _parseDosage(row['dosage_form']),
      strength: row['strength'] ?? '',
      category: row['category'] ?? '',
      unit: (row['unit']?.isNotEmpty ?? false) ? row['unit']! : 'Tab',
      rackLocation: row['rack_location'] ?? '',
      drugSchedule: DrugSchedule.none,
      storageInstructions: '',
      barcode: (row['barcode']?.isNotEmpty ?? false)
          ? Barcode.unsafe(row['barcode']!)
          : null,
      prescriptionRequired: rxReq,
      minStockLevel: Quantity.create(minStock),
      purchasePrice: Money.fromPkr(purchase),
      sellingPrice: Money.fromPkr(selling),
      mrp: Money.fromPkr(mrp),
      boxSize: boxSize > 0 ? boxSize : 1,
      boxPrice: Money.fromPkr(selling * (boxSize > 0 ? boxSize : 1)),
      status: MedicineStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool _parseBool(String? v) {
    if (v == null) return false;
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y';
  }

  DosageForm _parseDosage(String? v) {
    if (v == null || v.isEmpty) return DosageForm.tablet;
    final s = v.trim().toLowerCase();
    return DosageForm.values.firstWhere(
          (e) => e.name.toLowerCase() == s || e.label.toLowerCase() == s,
      orElse: () => DosageForm.other,
    );
  }

  void _import() {
    final valid = _rows.where((r) => r.isOk).map((r) => r.medicine!).toList();
    Navigator.of(context).pop(valid);
  }

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
            child: const Icon(Icons.upload_file_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Import Medicines',
                  style: AppTypography.pageTitle
                      .copyWith(color: Colors.white, fontSize: 18),
                ),
                Text(
                  'Add many medicines at once from a CSV or Excel file',
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

                  // Preview + Download side by side
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
                    'Preview in-app, or download a CSV template to fill and import',
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
            // Also allow download while reviewing sample
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
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
              border:
              Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only "name" is required — every other column is optional.',
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _headers.join(', '),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Excel tip: avoid "Format as Table" (Ctrl+T) — convert to '
                      'a normal range before saving, or just use CSV.',
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
                ? 'Import $okCount Medicine${okCount == 1 ? '' : 's'}'
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