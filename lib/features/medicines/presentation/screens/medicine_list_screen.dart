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
    final result = await showDialog<MedicineCreationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineFormDialog(
        existingCategories: widget.controller.categories,
        existingManufacturers: widget.controller.manufacturers,
      ),
    );

    if (result != null && mounted) {
      final error = await widget.controller.createMedicineWithStock(result);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        final stockMsg = result.openingStock != null
            ? ' with ${result.openingStock!.quantity} units stock'
            : '';
        AppToast.success(
            context, 'Medicine "${result.medicine.name}" added$stockMsg.');
      }
    }
  }

  Future<void> _openEditDialog(Medicine m) async {
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
              _selectedCategory!.isEmpty ||
              m.category == _selectedCategory;

          return matchesQuery && matchesCategory;
        }).toList();

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
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Filter by Category',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(AppRadius.sm)),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('All Categories')),
                        ...ctrl.categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _selectedCategory = v == '' ? null : v;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (_canAdd)
                    AppButton(
                      label: 'Add Medicine',
                      icon: Icons.add_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: _openAddDialog,
                    ),
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
                subtitle: 'Create a new medicine to get started.',
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
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    horizontalMargin: AppSpacing.lg,
                    columnSpacing: AppSpacing.lg,
                    headingRowColor: WidgetStatePropertyAll(
                        AppColors.surfaceVariant),
                    columns: const [
                      DataColumn(label: Text('Medicine Name')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Company')),
                      DataColumn(
                          label: Text('Retail Price (PKR)'),
                          numeric: true),
                      DataColumn(
                          label: Text('Box Size'), numeric: true),
                      DataColumn(label: Text('Rack')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.map((m) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${m.name} ${m.strength}',
                                  style: AppTypography.subtitle
                                      .copyWith(fontSize: 13),
                                ),
                                if (m.genericName.isNotEmpty)
                                  Text(m.genericName,
                                      style: AppTypography.caption),
                              ],
                            ),
                          ),
                          DataCell(Text(
                              m.category.isEmpty ? '—' : m.category,
                              style: AppTypography.tableCell)),
                          DataCell(Text(
                              m.manufacturer.isEmpty
                                  ? '—'
                                  : m.manufacturer,
                              style: AppTypography.tableCell)),
                          DataCell(Text(m.sellingPrice.display,
                              style: AppTypography.numeric)),
                          DataCell(Text('${m.boxSize}s',
                              style: AppTypography.numeric)),
                          DataCell(
                            Text(
                              m.rackLocation.isEmpty
                                  ? '—'
                                  : m.rackLocation,
                              style:
                              AppTypography.tableCell.copyWith(
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
                                    icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: AppColors.primary),
                                    splashRadius: 16,
                                    onPressed: () =>
                                        _openEditDialog(m),
                                  ),
                                if (_canDelete)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: AppColors.error),
                                    splashRadius: 16,
                                    onPressed: () =>
                                        _deleteMedicine(m),
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