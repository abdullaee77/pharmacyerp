import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/inventory_movement.dart';
import '../controllers/inventory_controller.dart';
import '../widgets/adjust_stock_dialog.dart';
import '../widgets/movement_history_dialog.dart';

/// Primary physical inventory level console.
class InventoryListScreen extends StatefulWidget {
  final InventoryController controller;
  final AuthController authController;

  const InventoryListScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadStockLevels();
    });
  }

  Future<void> _openAdjustDialog(InventoryStock stock) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => AdjustStockDialog(
        controller: widget.controller,
        stock: stock,
        operatorName: widget.authController.currentUser?.fullName ?? 'System Operator',
      ),
    );

    if (error != null && mounted) {
      AppToast.error(context, error);
    } else if (error == null && mounted) {
      AppToast.success(context, 'Stock level adjusted successfully.');
    }
  }

  Future<void> _openMovementHistory(InventoryStock stock) async {
    await showDialog(
      context: context,
      builder: (ctx) => MovementHistoryDialog(
        controller: widget.controller,
        stock: stock,
      ),
    );
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
            // Module Header
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inventory Management', style: AppTypography.pageTitle),
                    Text(
                      'Live stock balance sheet and adjustment controls.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Filter Command Row
            Row(
              children: [
                AppSearchBar(
                  hint: 'Search product names or barcode...',
                  shortcutLabel: 'Ctrl+K',
                  maxWidth: 380,
                  onSearch: ctrl.search,
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    value: ctrl.statusFilter,
                    decoration: const InputDecoration(
                      hintText: 'Filter Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Stock States')),
                      DropdownMenuItem(value: 'in', child: Text('In Stock')),
                      DropdownMenuItem(value: 'low', child: Text('Low Stock Alerts')),
                      DropdownMenuItem(value: 'out', child: Text('Out of Stock')),
                    ],
                    onChanged: ctrl.filterByStatus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Stocks Data Table
            Expanded(child: _buildTable(ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildTable(InventoryController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(type: AppLoadingType.spinner, message: 'Loading stock sheets...');
    }

    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry Refresh',
        onAction: ctrl.loadStockLevels,
      );
    }

    if (ctrl.stocks.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No stock metrics matched',
        subtitle: 'Add medicines or clear query constraints.',
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
              DataColumn(label: Text('Medicine Product')),
              DataColumn(label: Text('Generic Name')),
              DataColumn(label: Text('Current Stock'), numeric: true),
              DataColumn(label: Text('Min Limit'), numeric: true),
              DataColumn(label: Text('Unit Price'), numeric: true),
              DataColumn(label: Text('Stock Value'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.stocks.map((s) {
              final val = s.medicine.sellingPrice.paisa * s.currentStock.value;
              final displayVal = Money.fromPaisa(val).display;

              Widget statusBadge = const AppBadge(
                label: 'In Stock',
                variant: AppBadgeVariant.success,
                isDot: true,
              );
              if (s.isOutOfStock) {
                statusBadge = const AppBadge(
                  label: 'Empty',
                  variant: AppBadgeVariant.error,
                  isDot: true,
                );
              } else if (s.isLowStock) {
                statusBadge = const AppBadge(
                  label: 'Low Stock',
                  variant: AppBadgeVariant.warning,
                  isDot: true,
                );
              }

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      s.medicine.name,
                      style: AppTypography.tableCell.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(Text(s.medicine.genericName, style: AppTypography.tableCell)),
                  DataCell(Text('${s.currentStock.value}', style: AppTypography.numeric)),
                  DataCell(Text('${s.medicine.minStockLevel.value}', style: AppTypography.numericSmall)),
                  DataCell(Text(s.medicine.sellingPrice.display, style: AppTypography.numericSmall)),
                  DataCell(Text(displayVal, style: AppTypography.numeric.copyWith(fontWeight: FontWeight.bold))),
                  DataCell(statusBadge),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppButton(
                          label: 'Adjust',
                          icon: Icons.tune_rounded,
                          variant: AppButtonVariant.outlined,
                          size: AppButtonSize.small,
                          onPressed: () => _openAdjustDialog(s),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 18),
                          tooltip: 'Transaction Audit Logs',
                          splashRadius: 18,
                          onPressed: () => _openMovementHistory(s),
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