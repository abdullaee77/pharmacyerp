import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/sale.dart';
import '../controllers/sales_controller.dart';
import '../widgets/sales_return_dialog.dart';

class SalesHistoryScreen extends StatefulWidget {
  final SalesController controller;
  final AuthController authController;

  const SalesHistoryScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadHistory();
    });
  }

  Future<void> _openReturn(Sale sale) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => SalesReturnDialog(
        sale: sale,
        controller: widget.controller,
        operatorName:
        widget.authController.currentUser?.fullName ?? 'Operator',
      ),
    );
    if (result == true && mounted) {
      AppToast.success(context, 'Return processed successfully.');
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
                const Icon(Icons.history_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales History', style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.history.length} invoices on record',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchBar(
              hint: 'Search invoice number or customer name...',
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

  Widget _buildTable(SalesController ctrl) {
    if (ctrl.isLoading) return const AppLoading(message: 'Loading sales...');
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadHistory,
      );
    }
    if (ctrl.history.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No sales recorded yet',
        subtitle: 'Completed sales will appear here with return options.',
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
            headingRowColor:
            WidgetStatePropertyAll(AppColors.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Invoice')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Items'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.history.map((s) {
              AppBadgeVariant badgeVariant;
              switch (s.status) {
                case SaleStatus.completed:
                  badgeVariant = AppBadgeVariant.success;
                case SaleStatus.held:
                  badgeVariant = AppBadgeVariant.warning;
                case SaleStatus.partiallyReturned:
                  badgeVariant = AppBadgeVariant.warning;
                case SaleStatus.returned:
                  badgeVariant = AppBadgeVariant.error;
                case SaleStatus.cancelled:
                  badgeVariant = AppBadgeVariant.neutral;
              }
              return DataRow(
                cells: [
                  DataCell(Text(s.invoiceNumber.value,
                      style: AppTypography.subtitle.copyWith(fontSize: 13))),
                  DataCell(Text(s.customerName,
                      style: AppTypography.tableCell)),
                  DataCell(Text(
                    '${s.createdAt.day.toString().padLeft(2, '0')}/'
                        '${s.createdAt.month.toString().padLeft(2, '0')}/'
                        '${s.createdAt.year} '
                        '${s.createdAt.hour.toString().padLeft(2, '0')}:'
                        '${s.createdAt.minute.toString().padLeft(2, '0')}',
                    style: AppTypography.tableCell,
                  )),
                  DataCell(Text('${s.items.length}',
                      style: AppTypography.numeric)),
                  DataCell(Text(
                    s.grandTotal.display,
                    style: AppTypography.numeric
                        .copyWith(fontWeight: FontWeight.w700),
                  )),
                  DataCell(AppBadge(
                      label: s.status.label,
                      variant: badgeVariant,
                      isDot: true)),
                  DataCell(
                    AppButton(
                      label: 'Return',
                      icon: Icons.assignment_return_outlined,
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      onPressed: () => _openReturn(s),
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