import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/supplier.dart';
import '../controllers/supplier_controller.dart';
import '../widgets/supplier_form_dialog.dart';
import '../widgets/supplier_profile_dialog.dart';

class SupplierListScreen extends StatefulWidget {
  final SupplierController controller;
  final AuthController authController;

  const SupplierListScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadSuppliers();
    });
  }

  Future<void> _addSupplier() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => SupplierFormDialog(controller: widget.controller),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Supplier added.');
    }
  }

  Future<void> _editSupplier(Supplier s) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          SupplierFormDialog(controller: widget.controller, existing: s),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Supplier updated.');
    }
  }

  Future<void> _openProfile(SupplierWithBalance swb) async {
    await showDialog(
      context: context,
      builder: (ctx) => SupplierProfileDialog(
        controller: widget.controller,
        supplier: swb,
        operatorName: widget.authController.currentUser?.fullName ?? 'Operator',
        onEdit: () {
          Navigator.of(ctx).pop();
          _editSupplier(swb.supplier);
        },
      ),
    );
  }

  Future<void> _deleteSupplier(Supplier s) async {
    final ok = await AppDialog.warning(
      context,
      title: 'Delete Supplier?',
      message:
          '"${s.name}" and all their ledger entries will be removed permanently.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      final error = await widget.controller.deleteSupplier(s.id);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Supplier deleted.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suppliers', style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.suppliers.length} suppliers on file',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  label: 'Add Supplier',
                  icon: Icons.add_business_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: _addSupplier,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchBar(
              hint: 'Search by name, contact person, or phone...',
              maxWidth: 420,
              onSearch: ctrl.search,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildTable(ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildTable(SupplierController ctrl) {
    if (ctrl.isLoading)
      return const AppLoading(message: 'Loading suppliers...');
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadSuppliers,
      );
    }
    if (ctrl.suppliers.isEmpty) {
      return AppEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No suppliers yet',
        subtitle: 'Add a supplier to track purchases and payments.',
        actionLabel: 'Add Supplier',
        onAction: _addSupplier,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 52,
            horizontalMargin: AppSpacing.lg,
            columnSpacing: AppSpacing.xl,
            headingRowColor: WidgetStatePropertyAll(AppColors.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Contact Person')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('We Owe'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.suppliers.map((swb) {
              final s = swb.supplier;
              final payable = swb.payable;
              final payableColor = payable.paisa > 0
                  ? AppColors.error
                  : AppColors.textPrimary;

              return DataRow(
                onSelectChanged: (_) => _openProfile(swb),
                cells: [
                  DataCell(
                    Text(
                      s.name,
                      style: AppTypography.tableCell.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      s.contactPerson.isEmpty ? '—' : s.contactPerson,
                      style: AppTypography.tableCell,
                    ),
                  ),
                  DataCell(
                    Text(
                      s.phone.isEmpty ? '—' : s.phone,
                      style: AppTypography.tableCell,
                    ),
                  ),
                  DataCell(
                    Text(
                      payable.paisa == 0 ? '—' : payable.display,
                      style: AppTypography.numeric.copyWith(
                        color: payableColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DataCell(
                    AppBadge(
                      label: s.status.label,
                      variant: s.status == SupplierStatus.active
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.neutral,
                      isDot: true,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          tooltip: 'View / Pay',
                          splashRadius: 16,
                          onPressed: () => _openProfile(swb),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit',
                          splashRadius: 16,
                          onPressed: () => _editSupplier(s),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          tooltip: 'Delete',
                          splashRadius: 16,
                          onPressed: () => _deleteSupplier(s),
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
    );
  }
}
