import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/batch.dart';
import '../controllers/batch_controller.dart';

/// Inventory FEFO Batch & Expiry tracking workspace.
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
                  Icons.layers_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batch & Expiry Tracking',
                        style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.batches.length} active physical batches  |  FEFO-ordered',
                      style: AppTypography.bodySmall,
                    ),
                  ],
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
        message: 'Loading physical batches...',
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
      return const AppEmptyState(
        icon: Icons.layers_outlined,
        title: 'No active batches found',
        subtitle:
        'Batches are created automatically when you receive stock via Purchase Invoices.',
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
              DataColumn(label: Text('Medicine Name')),
              DataColumn(label: Text('Batch No.')),
              DataColumn(label: Text('Expiry')),
              DataColumn(label: Text('Days Left'), numeric: true),
              DataColumn(
                label: Text(
                  'Remaining Qty',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                tooltip: 'Actual physical stock left on shelf',
                numeric: true,
              ),
              DataColumn(label: Text('Unit Cost'), numeric: true),
              DataColumn(label: Text('Sell Price'), numeric: true),
              DataColumn(label: Text('Total Value'), numeric: true),
              DataColumn(label: Text('Status')),
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
                    Text(
                      '${b.quantity.value}',
                      style: AppTypography.numeric
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
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
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}