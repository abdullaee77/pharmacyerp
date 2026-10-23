import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../inventory/domain/batch.dart';
import '../../../inventory/presentation/controllers/batch_controller.dart';
import '../../../inventory/presentation/widgets/batch_bulk_import_dialog.dart';
import '../../../users/domain/role.dart';
import '../../domain/medicine.dart';
import '../../domain/value_objects.dart';
import '../controllers/medicine_controller.dart';
import '../widgets/medicine_form_dialog.dart';
import '../widgets/medicine_bulk_import_dialog.dart';

/// Holds draft values while a row is being inline-edited.
class _RowDraft {
  String category;
  String manufacturer;
  String sellingPrice; // PKR text
  String boxSize;
  String rackLocation;

  _RowDraft({
    required this.category,
    required this.manufacturer,
    required this.sellingPrice,
    required this.boxSize,
    required this.rackLocation,
  });

  factory _RowDraft.fromMedicine(Medicine m) => _RowDraft(
    category: m.category,
    manufacturer: m.manufacturer,
    sellingPrice: m.sellingPrice.pkr.toStringAsFixed(2),
    boxSize: '${m.boxSize}',
    rackLocation: m.rackLocation,
  );
}

class MedicineListScreen extends StatefulWidget {
  final MedicineController controller;
  final BatchController batchController;
  final AuthController authController;

  const MedicineListScreen({
    super.key,
    required this.controller,
    required this.batchController,
    required this.authController,
  });

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  String? _selectedCategory;
  final Set<String> _selectedIds = {};

  /// When non-null, bulk inline-edit mode is active.
  bool _isBulkEditing = false;
  final Map<String, _RowDraft> _drafts = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadMedicines();
      widget.controller.loadFilterOptions();
    });
  }

  bool get _canAdd => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.medicines, PermissionAction.add);
  bool get _canEdit => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.medicines, PermissionAction.edit);
  bool get _canDelete => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.medicines, PermissionAction.delete);

  // ─── INLINE BULK EDIT ────────────────────────────────────────────────────

  void _enterBulkEditMode(List<Medicine> selectedMeds) {
    if (selectedMeds.isEmpty) return;
    setState(() {
      _isBulkEditing = true;
      _drafts.clear();
      for (final m in selectedMeds) {
        _drafts[m.id.value] = _RowDraft.fromMedicine(m);
      }
    });
  }

  void _cancelBulkEdit() {
    setState(() {
      _isBulkEditing = false;
      _drafts.clear();
      _isSaving = false;
    });
  }

  Future<void> _saveBulkEdit(List<Medicine> allFiltered) async {
    if (_drafts.isEmpty) {
      _cancelBulkEdit();
      return;
    }

    setState(() => _isSaving = true);

    final updated = <Medicine>[];
    for (final m in allFiltered) {
      final draft = _drafts[m.id.value];
      if (draft == null) continue;

      final price = double.tryParse(draft.sellingPrice.trim()) ?? m.sellingPrice.pkr;
      final box = int.tryParse(draft.boxSize.trim()) ?? m.boxSize;

      updated.add(m.copyWith(
        category: draft.category.trim(),
        manufacturer: draft.manufacturer.trim(),
        sellingPrice: Money.fromPkr(price < 0 ? 0 : price),
        boxSize: box < 1 ? 1 : box,
        rackLocation: draft.rackLocation.trim(),
        updatedAt: DateTime.now(),
      ));
    }

    final msg = await widget.controller.bulkUpdateMedicines(updated);
    if (!mounted) return;

    setState(() {
      _isBulkEditing = false;
      _drafts.clear();
      _selectedIds.clear();
      _isSaving = false;
    });
    AppToast.success(context, msg);
  }

  // ─── SINGLE / IMPORT DIALOGS ─────────────────────────────────────────────

  Future<void> _openAddDialog() async {
    if (_isBulkEditing) return;
    await widget.controller.loadFilterOptions();

    final result = await showDialog<MedicineCreationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineFormDialog(
        existingCategories: widget.controller.categories,
        existingManufacturers: widget.controller.manufacturers,
      ),
    );

    if (result == null || !mounted) return;

    final error = await widget.controller.createMedicine(result.medicine);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    // Optional opening batch entered in the form
    final stock = result.openingStock;
    if (stock == null) {
      AppToast.success(
        context,
        'Medicine "${result.medicine.name}" added successfully.',
      );
      return;
    }

    final med = result.medicine;
    final now = DateTime.now();
    final expiry = ExpiryDate(stock.expiryDate);
    final batch = Batch(
      id: BatchId.generate(),
      medicineId: med.id,
      medicineName: '${med.name} ${med.strength}'.trim(),
      batchNumber: BatchNumber.unsafe(stock.batchNumber),
      expiryDate: expiry,
      quantity: Quantity.create(stock.quantity),
      purchasePrice: stock.purchasePrice ?? med.purchasePrice,
      sellingPrice: stock.sellingPrice ?? med.sellingPrice,
      status: Batch.deriveStatus(expiry),
      createdAt: now,
      updatedAt: now,
    );

    final batchError = await widget.batchController.createBatch(batch);
    if (!mounted) return;
    if (batchError != null) {
      AppToast.error(
        context,
        'Medicine added, but the batch failed: $batchError',
      );
    } else {
      AppToast.success(
        context,
        'Medicine "${med.name}" and batch "${stock.batchNumber}" added.',
      );
    }
  }

  Future<void> _openBulkImport() async {
    if (_isBulkEditing) return;
    final result = await showDialog<List<Medicine>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MedicineBulkImportDialog(),
    );

    if (result == null || result.isEmpty || !mounted) return;

    final summary = await widget.controller.bulkCreateMedicines(result);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _openBatchBulkImport() async {
    if (_isBulkEditing) return;

    if (widget.controller.medicines.isEmpty) {
      AppToast.info(context, 'Add medicines first, then import their batches.');
      return;
    }

    final result = await showDialog<List<Batch>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchBulkImportDialog(
        medicines: widget.controller.medicines,
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    final summary = await widget.batchController.bulkCreateBatches(result);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _openEditDialog(Medicine m) async {
    if (_isBulkEditing) return;
    await widget.controller.loadFilterOptions();

    final result = await showDialog<MedicineCreationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineFormDialog(
        medicine: m,
        existingCategories: widget.controller.categories,
        existingManufacturers: widget.controller.manufacturers,
      ),
    );

    if (result != null && mounted) {
      final error = await widget.controller.updateMedicine(result.medicine);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Medicine updated successfully.');
      }
    }
  }

  Future<void> _deleteMedicine(Medicine m) async {
    if (_isBulkEditing) return;
    final confirmed = await AppDialog.warning(
      context,
      title: 'Delete Medicine?',
      message: 'Are you sure you want to permanently delete "${m.name}"?',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      final error = await widget.controller.deleteMedicine(m.id);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Medicine deleted.');
      }
    }
  }

  // ─── CELL BUILDERS ───────────────────────────────────────────────────────

  InputDecoration _cellDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _editableText({
    required String initial,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextAlign align = TextAlign.start,
    double width = 100,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: initial,
        style: AppTypography.tableCell.copyWith(fontSize: 13),
        textAlign: align,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: _cellDecoration(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _editableDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    double width = 140,
  }) {
    // Unique, non-empty options only. The blank choice is added separately,
    // so '' can never appear twice.
    final items = <String>{
      if (value.isNotEmpty) value,
      ...options.where((o) => o.trim().isNotEmpty),
    }.toList()
      ..sort();

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value, // '' is always a valid item below
        isExpanded: true,
        decoration: _cellDecoration(),
        style: AppTypography.tableCell
            .copyWith(fontSize: 13, color: AppColors.textPrimary),
        items: [
          const DropdownMenuItem(value: '', child: Text('—')),
          ...items.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  DataRow _buildReadOnlyRow(Medicine m) {
    return DataRow(
      selected: _selectedIds.contains(m.id.value),
      onSelectChanged: _isBulkEditing
          ? null
          : (val) {
        setState(() {
          if (val == true) {
            _selectedIds.add(m.id.value);
          } else {
            _selectedIds.remove(m.id.value);
          }
        });
      },
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${m.name} ${m.strength}',
                style: AppTypography.subtitle.copyWith(fontSize: 13),
              ),
              if (m.genericName.isNotEmpty)
                Text(m.genericName, style: AppTypography.caption),
            ],
          ),
        ),
        DataCell(Text(m.category.isEmpty ? '—' : m.category, style: AppTypography.tableCell)),
        DataCell(Text(m.manufacturer.isEmpty ? '—' : m.manufacturer, style: AppTypography.tableCell)),
        DataCell(Text(m.sellingPrice.display, style: AppTypography.numeric)),
        DataCell(Text('${m.boxSize}s', style: AppTypography.numeric)),
        DataCell(
          Text(
            m.rackLocation.isEmpty ? '—' : m.rackLocation,
            style: AppTypography.tableCell.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        DataCell(
          _isBulkEditing
              ? const SizedBox.shrink()
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  splashRadius: 16,
                  onPressed: () => _openEditDialog(m),
                ),
              if (_canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                  splashRadius: 16,
                  onPressed: () => _deleteMedicine(m),
                ),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _buildEditableRow(Medicine m, _RowDraft draft, List<String> cats, List<String> mfrs) {
    return DataRow(
      selected: true,
      color: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.04)),
      cells: [
        // Name — read-only (full edit via single dialog)
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${m.name} ${m.strength}',
                style: AppTypography.subtitle.copyWith(fontSize: 13),
              ),
              if (m.genericName.isNotEmpty)
                Text(m.genericName, style: AppTypography.caption),
            ],
          ),
        ),
        // Category
        DataCell(
          _editableDropdown(
            value: draft.category,
            options: cats,
            width: 150,
            onChanged: (v) => setState(() => draft.category = v),
          ),
        ),
        // Company
        DataCell(
          _editableDropdown(
            value: draft.manufacturer,
            options: mfrs,
            width: 140,
            onChanged: (v) => setState(() => draft.manufacturer = v),
          ),
        ),
        // Retail price
        DataCell(
          _editableText(
            initial: draft.sellingPrice,
            width: 90,
            align: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (v) => draft.sellingPrice = v,
          ),
        ),
        // Box size
        DataCell(
          _editableText(
            initial: draft.boxSize,
            width: 60,
            align: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => draft.boxSize = v,
          ),
        ),
        // Rack
        DataCell(
          _editableText(
            initial: draft.rackLocation,
            width: 80,
            onChanged: (v) => draft.rackLocation = v,
          ),
        ),
        // Actions — empty while bulk editing
        const DataCell(SizedBox.shrink()),
      ],
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        final filtered = ctrl.medicines.where((m) {
          final matchesQuery = ctrl.filter.isEmpty ||
              m.name.toLowerCase().contains(ctrl.filter.toLowerCase()) ||
              m.genericName.toLowerCase().contains(ctrl.filter.toLowerCase()) ||
              m.manufacturer.toLowerCase().contains(ctrl.filter.toLowerCase());

          final matchesCategory =
              _selectedCategory == null || m.category == _selectedCategory;

          return matchesQuery && matchesCategory;
        }).toList();

        final selectedMeds =
        filtered.where((m) => _selectedIds.contains(m.id.value)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Toolbar ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _isBulkEditing
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _isBulkEditing ? AppColors.primary : AppColors.border,
                ),
              ),
              child: _isBulkEditing
                  ? _buildEditToolbar(filtered)
                  : _buildNormalToolbar(ctrl, selectedMeds),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Table ──────────────────────────────────────────────────────
            Expanded(
              child: ctrl.isLoading
                  ? const AppLoading(message: 'Loading medicine catalog...')
                  : filtered.isEmpty
                  ? const AppEmptyState(
                icon: Icons.medication_rounded,
                title: 'No medicines found',
                subtitle: 'Adjust filters or create a new medicine.',
              )
                  : Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: DataTable(
                    showCheckboxColumn: !_isBulkEditing,
                    headingRowHeight: 44,
                    dataRowMinHeight: _isBulkEditing ? 56 : 48,
                    dataRowMaxHeight: _isBulkEditing ? 64 : 56,
                    horizontalMargin: AppSpacing.lg,
                    columnSpacing: AppSpacing.lg,
                    headingRowColor:
                    WidgetStatePropertyAll(AppColors.surfaceVariant),
                    onSelectAll: _isBulkEditing
                        ? null
                        : (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.addAll(
                              filtered.map((m) => m.id.value));
                        } else {
                          _selectedIds.clear();
                        }
                      });
                    },
                    columns: const [
                      DataColumn(label: Text('Medicine Name')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Company')),
                      DataColumn(
                          label: Text('Retail Price (PKR)'), numeric: true),
                      DataColumn(label: Text('Box Size'), numeric: true),
                      DataColumn(label: Text('Rack')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.map((m) {
                      final draft = _drafts[m.id.value];
                      if (_isBulkEditing && draft != null) {
                        return _buildEditableRow(
                          m,
                          draft,
                          ctrl.categories,
                          ctrl.manufacturers,
                        );
                      }
                      return _buildReadOnlyRow(m);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNormalToolbar(MedicineController ctrl, List<Medicine> selectedMeds) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AppSearchBar(
            hint: 'Search medicine name, generic formula...',
            onSearch: ctrl.search,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String?>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Filter by Category',
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              ...ctrl.categories.map((cat) => DropdownMenuItem(
                value: cat,
                child: Text(cat.isEmpty ? 'Uncategorized' : cat),
              )),
            ],
            onChanged: (v) {
              setState(() {
                _selectedCategory = v;
                _selectedIds.clear();
              });
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (_canEdit && _selectedIds.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () => _enterBulkEditMode(selectedMeds),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text('Edit (${_selectedIds.length})'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (_canAdd) ...[
          OutlinedButton.icon(
            onPressed: _openBulkImport,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Bulk Import'),
            style: OutlinedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _openBatchBulkImport,
            icon: const Icon(Icons.layers_rounded, size: 18),
            label: const Text('Bulk Import Batches'),
            style: OutlinedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Add Medicine',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.primary,
            onPressed: _openAddDialog,
          ),
        ],
      ],
    );
  }

  Widget _buildEditToolbar(List<Medicine> filtered) {
    return Row(
      children: [
        Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Editing ${_drafts.length} medicine${_drafts.length == 1 ? '' : 's'}',
          style: AppTypography.subtitle.copyWith(color: AppColors.primary),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _cancelBulkEdit,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton(
          label: _isSaving ? 'Saving…' : 'Save Changes',
          icon: _isSaving ? null : Icons.save_rounded,
          variant: AppButtonVariant.primary,
          onPressed: _isSaving ? null : () => _saveBulkEdit(filtered),
        ),
      ],
    );
  }
}