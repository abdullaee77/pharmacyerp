import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../inventory/presentation/controllers/batch_controller.dart';
import '../../../inventory/presentation/screens/batch_list_screen.dart';
import '../../domain/purchase.dart';
import '../controllers/purchase_controller.dart';
import '../widgets/purchase_form_dialog.dart';
import '../widgets/purchase_return_dialog.dart';

class PurchaseWorkspaceScreen extends StatefulWidget {
  final PurchaseController controller;
  final BatchController batchController;
  final AuthController authController;

  const PurchaseWorkspaceScreen({
    super.key,
    required this.controller,
    required this.batchController,
    required this.authController,
  });

  @override
  State<PurchaseWorkspaceScreen> createState() =>
      _PurchaseWorkspaceScreenState();
}

class _PurchaseWorkspaceScreenState extends State<PurchaseWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadPurchases();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openReceiveForm() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => PurchaseFormDialog(controller: widget.controller),
    );
    if (error != null && mounted) {
      AppToast.error(context, error);
    } else if (error == null && mounted) {
      AppToast.success(
        context,
        'Purchase received and physical stock levels increased.',
      );
    }
  }

  Future<void> _openReturn(Purchase p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => PurchaseReturnDialog(
        purchase: p,
        controller: widget.controller,
        operatorName: widget.authController.currentUser?.fullName ?? 'Operator',
      ),
    );
    if (result == true && mounted) {
      AppToast.success(
        context,
        'Stock deducted and purchase return processed.',
      );
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
                  Icons.shopping_bag_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchasing & Procurement',
                      style: AppTypography.pageTitle,
                    ),
                    Text(
                      '${ctrl.purchases.length} stock receipts on file',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  label: 'Receive Purchase',
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _openReceiveForm,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Procurement History'),
                Tab(text: 'Physical Batches / Expiry'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProcurementTab(ctrl),
                  BatchListScreen(controller: widget.batchController),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProcurementTab(PurchaseController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchBar(
          hint: 'Search invoice or supplier name...',
          maxWidth: 400,
          onSearch: ctrl.search,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: _buildTable(ctrl)),
      ],
    );
  }

  Widget _buildTable(PurchaseController ctrl) {
    if (ctrl.isLoading)
      return const AppLoading(message: 'Loading procurement files...');
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadPurchases,
      );
    }
    if (ctrl.purchases.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No purchases recorded',
        subtitle: 'Receive purchase invoices to add inventory stocks.',
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
              DataColumn(label: Text('Invoice ID')),
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Date Received')),
              DataColumn(label: Text('Line Items'), numeric: true),
              DataColumn(label: Text('Total Cost'), numeric: true),
              DataColumn(label: Text('Procurement Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.purchases.map((p) {
              AppBadgeVariant variant;
              switch (p.status) {
                case PurchaseStatus.completed:
                  variant = AppBadgeVariant.success;
                case PurchaseStatus.partiallyReturned:
                  variant = AppBadgeVariant.warning;
                case PurchaseStatus.returned:
                  variant = AppBadgeVariant.error;
              }

              final dateStr =
                  '${p.createdAt.day.toString().padLeft(2, '0')}/'
                  '${p.createdAt.month.toString().padLeft(2, '0')}/'
                  '${p.createdAt.year}';

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      p.invoiceNumber.value,
                      style: AppTypography.subtitle.copyWith(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(p.supplierName, style: AppTypography.tableCell),
                  ),
                  DataCell(Text(dateStr, style: AppTypography.tableCell)),
                  DataCell(
                    Text('${p.items.length}', style: AppTypography.numeric),
                  ),
                  DataCell(
                    Text(
                      p.grandTotal.display,
                      style: AppTypography.numeric.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    AppBadge(
                      label: p.status.label,
                      variant: variant,
                      isDot: true,
                    ),
                  ),
                  DataCell(
                    AppButton(
                      label: 'Supplier Return',
                      icon: Icons.assignment_return_outlined,
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      onPressed: p.status == PurchaseStatus.returned
                          ? null
                          : () => _openReturn(p),
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
