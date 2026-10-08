import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../users/domain/role.dart';
import '../../domain/batch.dart';
import '../controllers/batch_controller.dart';
import '../widgets/batch_form_dialog.dart';

/// Batch & Expiry tracking workspace.
class BatchListScreen extends StatefulWidget {
  final BatchController controller;
  final AuthController authController;

  const BatchListScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadBatches();
    });
  }

  bool get _canAdd => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.inventory, PermissionAction.add);
  bool get _canEdit => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.inventory, PermissionAction.edit);
  bool get _canDelete => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.inventory, PermissionAction.delete);

  Future<void> _openAddBatch() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => BatchFormDialog(controller: widget.controller),
    );
    if (error != null && mounted) {
      AppToast.error(context, error);
    } else if (error == null && mounted) {
      AppToast.success(context, 'Batch registered successfully.');
    }
  }

  Future<void> _openEditBatch(Batch batch) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          BatchFormDialog(controller: widget.controller, existingBatch: batch),
    );
    if (error != null && mounted) {
      AppToast.error(context, error);
    } else if (error == null && mounted) {
      AppToast.success(context, 'Batch updated successfully.');
    }
  }

  Future<void> _confirmDelete(Batch batch) async {
    final confirmed = await AppDialog.warning(
      context,
      title: 'Delete Batch?',
      message:
      'Batch "${batch.batchNumber.value}" of ${batch.medicineName} will be permanently removed.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      final error = await widget.controller.deleteBatch(batch.id);
      if (error != null && mounted) {
        AppToast.error(context, error);
      } else if (mounted) {
        AppToast.success(context, 'Batch deleted.');
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
                const Icon(Icons.layers_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batch & Expiry Tracking',
                        style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.batches.length} active batches  |  FEFO-ordered',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                if (_canAdd)
                  AppButton(
                    label: 'Register Batch',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _openAddBatch,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                AppSearchBar(
                  hint: 'Search batch number, medicine name...',
                  maxWidth: 380,
                  onSearch: ctrl.search,
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<BatchStatus?>(
                    value: ctrl.statusFilter,
                    decoration: const InputDecoration(
                      hintText: 'Expiry Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Batches')),
                      DropdownMenuItem(
                          value: BatchStatus.normal, child: Text('Normal')),
                      DropdownMenuItem(
                          value: BatchStatus.expiringSoon,
                          child: Text('Expiring Soon')),
                      DropdownMenuItem(
                          value: BatchStatus.expired, child: Text('Expired')),
                    ],
                    onChanged: ctrl.filterByStatus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Expanded(child: _buildTable(ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildTable(BatchController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(
        type: AppLoadingType.spinner,
        message: 'Loading batches...',
      );
    }

    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadBatches,
      );
    }

    if (ctrl.batches.isEmpty) {
      return AppEmptyState(
        icon: Icons.layers_outlined,
        title: ctrl.statusFilter == null
            ? 'No batches registered'
            : 'No batches match this filter',
        subtitle:
        'Register a batch to begin tracking expiry and FEFO dispensing.',
        actionLabel:
        (ctrl.statusFilter == null && _canAdd) ? 'Register Batch' : null,
        onAction:
        (ctrl.statusFilter == null && _canAdd) ? _openAddBatch : null,
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
              DataColumn(label: Text('Medicine')),
              DataColumn(label: Text('Batch No.')),
              DataColumn(label: Text('Expiry')),
              DataColumn(label: Text('Days Left'), numeric: true),
              DataColumn(label: Text('Qty'), numeric: true),
              DataColumn(label: Text('Purchase'), numeric: true),
              DataColumn(label: Text('Sale'), numeric: true),
              DataColumn(label: Text('Value'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.batches.map((b) {
              AppBadgeVariant statusVariant;
              switch (b.status) {
                case BatchStatus.normal:
                  statusVariant = AppBadgeVariant.success;
                case BatchStatus.expiringSoon:
                  statusVariant = AppBadgeVariant.warning;
                case BatchStatus.expired:
                  statusVariant = AppBadgeVariant.error;
              }

              final daysLeft = b.expiryDate.daysRemaining;
              final daysColor = daysLeft < 0
                  ? AppColors.error
                  : daysLeft <= 90
                  ? AppColors.warning
                  : AppColors.textPrimary;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      b.medicineName,
                      style: AppTypography.tableCell.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      b.batchNumber.value,
                      style: AppTypography.numericSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(b.expiryDate.display, style: AppTypography.tableCell),
                  ),
                  DataCell(
                    Text(
                      daysLeft < 0 ? '${daysLeft.abs()}d ago' : '${daysLeft}d',
                      style: AppTypography.numericSmall.copyWith(
                        color: daysColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text('${b.quantity.value}', style: AppTypography.numeric),
                  ),
                  DataCell(
                    Text(b.purchasePrice.display,
                        style: AppTypography.numericSmall),
                  ),
                  DataCell(
                    Text(b.sellingPrice.display,
                        style: AppTypography.numericSmall),
                  ),
                  DataCell(
                    Text(
                      b.totalValue.display,
                      style: AppTypography.numeric.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    AppBadge(
                      label: b.status.label,
                      variant: statusVariant,
                      isDot: true,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            tooltip: 'Edit Batch',
                            splashRadius: 16,
                            onPressed: () => _openEditBatch(b),
                          ),
                        if (_canDelete)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            tooltip: 'Delete',
                            splashRadius: 16,
                            onPressed: () => _confirmDelete(b),
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