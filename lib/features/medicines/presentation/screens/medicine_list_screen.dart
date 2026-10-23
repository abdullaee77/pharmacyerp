import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../users/domain/role.dart';
import '../../domain/medicine.dart';
import '../controllers/medicine_controller.dart';
import '../widgets/medicine_form_dialog.dart';
import '../widgets/medicine_bulk_import_dialog.dart';

class MedicineListScreen extends StatefulWidget {
  final MedicineController controller;
  final AuthController authController;

  const MedicineListScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  String? _selectedCategory;
  final Set<String> _selectedIds = {};

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

  Future<void> _openAddDialog() async {
    await widget.controller.loadFilterOptions();

    final result = await showDialog<MedicineCreationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineFormDialog(
        existingCategories: widget.controller.categories,
        existingManufacturers: widget.controller.manufacturers,
      ),
    );

    if (result != null && mounted) {
      final error = await widget.controller.createMedicine(result.medicine);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(
          context,
          'Medicine "${result.medicine.name}" added successfully.',
        );
      }
    }
  }

  Future<void> _openBulkImport() async {
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

  Future<void> _openBulkEditDialog(List<Medicine> selectedMeds) async {
    String? newCategory;
    String? newRack;
    String? newManufacturer;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bulk Edit ${selectedMeds.length} Medicines'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Leave a field blank to keep the original value.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Change Category'),
                value: newCategory,
                items: [
                  const DropdownMenuItem(value: null, child: Text('No Change')),
                  ...widget.controller.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => newCategory = v,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Change Manufacturer'),
                value: newManufacturer,
                items: [
                  const DropdownMenuItem(value: null, child: Text('No Change')),
                  ...widget.controller.manufacturers.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => newManufacturer = v,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Change Rack Location',
                hint: 'e.g., A-1 (Leave blank to keep original)',
                onChanged: (v) => newRack = v.trim().isEmpty ? null : v.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply Changes')),
        ],
      ),
    );

    if (result == true && mounted) {
      if (newCategory == null && newRack == null && newManufacturer == null) return;

      final updatedList = selectedMeds.map((m) {
        return m.copyWith(
          category: newCategory ?? m.category,
          rackLocation: newRack ?? m.rackLocation,
          manufacturer: newManufacturer ?? m.manufacturer,
          updatedAt: DateTime.now(),
        );
      }).toList();

      final msg = await widget.controller.bulkUpdateMedicines(updatedList);
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      AppToast.success(context, msg);
    }
  }

  Future<void> _openEditDialog(Medicine m) async {
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

          final matchesCategory = _selectedCategory == null ||
              m.category == _selectedCategory;

          return matchesQuery && matchesCategory;
        }).toList();

        final selectedMeds = filtered.where((m) => _selectedIds.contains(m.id.value)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                      onPressed: () => _openBulkEditDialog(selectedMeds),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text('Edit (${_selectedIds.length})'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
              ),
            ),
            const SizedBox(height: AppSpacing.md),

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
                    showCheckboxColumn: true,
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    horizontalMargin: AppSpacing.lg,
                    columnSpacing: AppSpacing.lg,
                    headingRowColor: WidgetStatePropertyAll(AppColors.surfaceVariant),
                    onSelectAll: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.addAll(filtered.map((m) => m.id.value));
                        } else {
                          _selectedIds.clear();
                        }
                      });
                    },
                    columns: const [
                      DataColumn(label: Text('Medicine Name')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Company')),
                      DataColumn(label: Text('Retail Price (PKR)'), numeric: true),
                      DataColumn(label: Text('Box Size'), numeric: true),
                      DataColumn(label: Text('Rack')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.map((m) {
                      return DataRow(
                        selected: _selectedIds.contains(m.id.value),
                        onSelectChanged: (val) {
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
                            Row(
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
}