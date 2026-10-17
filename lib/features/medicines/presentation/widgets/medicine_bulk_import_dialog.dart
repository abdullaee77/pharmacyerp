import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  String? _error;

  // Expected CSV/Excel headers (case-insensitive, flexible)
  static const _headers = [
    'name',
    'generic_name',
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

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
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

      final headerRow =
      table.first.map((e) => e.trim().toLowerCase()).toList();
      final dataRows = table.skip(1).toList();

      final parsed = <_ParsedRow>[];
      for (var i = 0; i < dataRows.length; i++) {
        final rowNum = i + 2; // +1 for header, +1 to make human-friendly
        final raw = <String, String>{};
        for (var c = 0; c < headerRow.length && c < dataRows[i].length; c++) {
          raw[headerRow[c]] = dataRows[i][c].trim();
        }
        if (raw.values.every((v) => v.isEmpty)) continue; // skip blank line

        try {
          final med = _buildMedicine(raw);
          parsed.add(_ParsedRow.ok(rowNum, med, raw));
        } catch (e) {
          parsed.add(_ParsedRow.err(rowNum, e.toString(), raw));
        }
      }

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
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables[excel.tables.keys.first]!;
    final out = <List<String>>[];
    for (final row in sheet.rows) {
      out.add(row
          .map((c) => c?.value?.toString().trim() ?? '')
          .toList());
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_rounded,
                      color: Colors.white, size: 26),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Bulk Import Medicines',
                    style: AppTypography.pageTitle
                        .copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInstructions(),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        AppButton(
                          label: 'Choose File (CSV / Excel)',
                          icon: Icons.folder_open_rounded,
                          variant: AppButtonVariant.primary,
                          onPressed: _loading ? null : _pickFile,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        if (_fileName != null)
                          Flexible(
                            child: Text(
                              _fileName!,
                              style: AppTypography.body,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        if (_rows.isNotEmpty) ...[
                          _chip('$okCount OK', AppColors.success),
                          const SizedBox(width: 8),
                          if (errCount > 0)
                            _chip('$errCount Error', AppColors.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(_error!,
                            style: AppTypography.body
                                .copyWith(color: AppColors.error)),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(child: _buildPreview()),
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                    label: 'Import $okCount Medicines',
                    icon: Icons.check_circle_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: okCount > 0 ? _import : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.info),
              const SizedBox(width: 6),
              Text('Required column: name. Other columns optional.',
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Headers (row 1): ${_headers.join(", ")}',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color),
      ),
      child: Text(text,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPreview() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.table_chart_outlined,
                  size: 64, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.sm),
              Text('No file selected',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              AppColors.primary.withValues(alpha: 0.08),
            ),
            columns: const [
              DataColumn(label: Text('Row')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Generic')),
              DataColumn(label: Text('Manufacturer')),
              DataColumn(label: Text('Strength')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Purchase')),
              DataColumn(label: Text('Selling')),
              DataColumn(label: Text('Error')),
            ],
            rows: _rows.map((r) {
              final m = r.medicine;
              return DataRow(cells: [
                DataCell(Text('${r.rowNumber}')),
                DataCell(r.isOk
                    ? _chip('OK', AppColors.success)
                    : _chip('ERR', AppColors.error)),
                DataCell(Text(m?.name ?? r.raw['name'] ?? '')),
                DataCell(Text(m?.genericName ?? '')),
                DataCell(Text(m?.manufacturer ?? '')),
                DataCell(Text(m?.strength ?? '')),
                DataCell(Text(m?.category ?? '')),
                DataCell(
                    Text(m != null ? m.purchasePrice.pkr.toStringAsFixed(2) : '')),
                DataCell(
                    Text(m != null ? m.sellingPrice.pkr.toStringAsFixed(2) : '')),
                DataCell(Text(
                  r.error ?? '',
                  style:
                  AppTypography.caption.copyWith(color: AppColors.error),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}