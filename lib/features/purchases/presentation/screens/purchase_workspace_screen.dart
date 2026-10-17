import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../accounts/presentation/controllers/account_controller.dart'; // REQUIRED
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../inventory/presentation/controllers/batch_controller.dart';
import '../../../users/domain/role.dart';
import '../../domain/purchase.dart';
import '../controllers/purchase_controller.dart';
import '../widgets/purchase_form_dialog.dart';
import '../widgets/purchase_return_dialog.dart';

class _PurchasedBatchRow {
  final Purchase purchase;
  final PurchaseItem item;

  _PurchasedBatchRow({required this.purchase, required this.item});
}

class PurchaseWorkspaceScreen extends StatefulWidget {
  final PurchaseController controller;
  final BatchController batchController;
  final AuthController authController;
  final AccountController? accountController; // Added AccountController

  const PurchaseWorkspaceScreen({
    super.key,
    required this.controller,
    required this.batchController,
    required this.authController,
    this.accountController,
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
      widget.accountController?.loadAccounts(); // Load accounts for purchases
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _canAdd => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.purchases, PermissionAction.add);

  bool get _canReturn => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.purchases, PermissionAction.returnAction);

  Future<void> _openReceiveForm() async {
    await widget.accountController?.loadAccounts(silent: true);
    final accounts = widget.accountController?.accounts ?? const [];

    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => PurchaseFormDialog(
        controller: widget.controller,
        accounts: accounts, // PASS ACCOUNTS HERE
      ),
    );
    if (!mounted) return;
    if (result is String) {
      AppToast.error(context, result);
    } else if (result == true) {
      widget.accountController?.loadAccounts(); // Refresh account balances
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
        operatorName:
        widget.authController.currentUser?.fullName ?? 'Operator',
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
                if (_canAdd)
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
                Tab(text: 'Purchased Batches'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProcurementTab(ctrl),
                  _buildPurchasedBatchesTab(ctrl),
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

  Widget _buildPurchasedBatchesTab(PurchaseController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(message: 'Loading purchased batch records...');
    }

    final List<_PurchasedBatchRow> rows = [];
    final query = ctrl.searchQuery.toLowerCase().trim();

    for (final purchase in ctrl.purchases) {
      for (final item in purchase.items) {
        if (query.isNotEmpty) {
          final match = item.medicineName.toLowerCase().contains(query) ||
              item.batchNumber.toLowerCase().contains(query) ||
              purchase.invoiceNumber.value.toLowerCase().contains(query) ||
              purchase.supplierName.toLowerCase().contains(query);
          if (!match) continue;
        }
        rows.add(_PurchasedBatchRow(purchase: purchase, item: item));
      }
    }

    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.layers_outlined,
        title: 'No purchased batch records found',
        subtitle:
        'Received purchase line items will appear here as permanent bought records.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchBar(
          hint: 'Search batch number, medicine, invoice...',
          maxWidth: 400,
          onSearch: ctrl.search,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Container(
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
                    DataColumn(label: Text('Medicine Name')),
                    DataColumn(label: Text('Batch No.')),
                    DataColumn(label: Text('Expiry Date')),
                    DataColumn(
                      label: Text(
                        'Bought Qty',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      tooltip:
                      'Original quantity purchased on receipt (Immutable)',
                      numeric: true,
                    ),
                    DataColumn(label: Text('Unit Cost'), numeric: true),
                    DataColumn(label: Text('MRP'), numeric: true),
                    DataColumn(label: Text('Sell Price'), numeric: true),
                    DataColumn(label: Text('Total Cost'), numeric: true),
                    DataColumn(label: Text('Invoice No.')),
                    DataColumn(label: Text('Date Received')),
                  ],
                  rows: rows.map((r) {
                    final item = r.item;
                    final p = r.purchase;
                    final dateStr =
                        '${p.createdAt.day.toString().padLeft(2, '0')}/'
                        '${p.createdAt.month.toString().padLeft(2, '0')}/'
                        '${p.createdAt.year}';
                    final expStr =
                        '${item.expiryDate.month.toString().padLeft(2, '0')}/'
                        '${item.expiryDate.year}';

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item.medicineName,
                            style: AppTypography.tableCell.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.batchNumber,
                            style: AppTypography.numericSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(Text(expStr, style: AppTypography.tableCell)),
                        DataCell(
                          Text(
                            '${item.quantity}',
                            style: AppTypography.numeric.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.purchasePrice.display,
                            style: AppTypography.numericSmall,
                          ),
                        ),
                        DataCell(
                          Text(
                            item.mrp.display,
                            style: AppTypography.numericSmall,
                          ),
                        ),
                        DataCell(
                          Text(
                            item.sellingPrice.display,
                            style: AppTypography.numericSmall,
                          ),
                        ),
                        DataCell(
                          Text(
                            item.lineTotal.display,
                            style: AppTypography.numeric.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            p.invoiceNumber.value,
                            style:
                            AppTypography.subtitle.copyWith(fontSize: 13),
                          ),
                        ),
                        DataCell(
                          Text(dateStr, style: AppTypography.tableCell),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(PurchaseController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(message: 'Loading procurement files...');
    }
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
              final variant = switch (p.status) {
                PurchaseStatus.completed => AppBadgeVariant.success,
                PurchaseStatus.partiallyReturned => AppBadgeVariant.warning,
                PurchaseStatus.returned => AppBadgeVariant.error,
                PurchaseStatus.cancelled => AppBadgeVariant.neutral,
              };

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
                    _canReturn
                        ? AppButton(
                      label: 'Supplier Return',
                      icon: Icons.assignment_return_outlined,
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      onPressed: p.status == PurchaseStatus.returned ||
                          p.status == PurchaseStatus.cancelled
                          ? null
                          : () => _openReturn(p),
                    )
                        : const SizedBox.shrink(),
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