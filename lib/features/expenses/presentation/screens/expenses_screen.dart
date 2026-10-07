import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../accounts/presentation/controllers/account_controller.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/expense.dart';
import '../controllers/expense_controller.dart';
import '../widgets/expense_form_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  final ExpenseController controller;
  final AccountController accountController;
  final AuthController authController;

  const ExpensesScreen({
    super.key,
    required this.controller,
    required this.accountController,
    required this.authController,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadAll();
      widget.accountController.loadAccounts();
    });
  }

  Future<void> _add() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => ExpenseFormDialog(
        controller: widget.controller,
        operatorName: widget.authController.currentUser?.fullName ?? 'Operator',
        accounts: widget.accountController.accounts,
      ),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Expense recorded.');
    }
  }

  Future<void> _delete(Expense e) async {
    final ok = await AppDialog.warning(
      context,
      title: 'Delete Expense?',
      message:
          'This expense will be removed. Linked account transactions will remain.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      final error = await widget.controller.deleteExpense(e.id);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Expense deleted.');
      }
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final summary = ctrl.summary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.money_off_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expenses', style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.expenses.length} expense entries',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  label: 'Record Expense',
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _add,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Summary cards
            if (summary != null)
              Row(
                children: [
                  Expanded(
                    child: _sumCard(
                      'TODAY',
                      summary.today.display,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _sumCard(
                      'THIS MONTH',
                      summary.thisMonth.display,
                      AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _sumCard(
                      'TOTAL',
                      summary.total.display,
                      AppColors.warning,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                AppSearchBar(
                  hint: 'Search description or category...',
                  maxWidth: 380,
                  onSearch: ctrl.search,
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    value: ctrl.categoryFilter,
                    decoration: const InputDecoration(
                      hintText: 'Filter Category',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...ctrl.categories.map(
                        (c) => DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: ctrl.filterByCategory,
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

  Widget _sumCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.numericLarge.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(ExpenseController ctrl) {
    if (ctrl.isLoading) return const AppLoading(message: 'Loading expenses...');
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadAll,
      );
    }
    if (ctrl.expenses.isEmpty) {
      return AppEmptyState(
        icon: Icons.money_off_outlined,
        title: 'No expenses yet',
        subtitle: 'Record your first expense to start tracking spending.',
        actionLabel: 'Record Expense',
        onAction: _add,
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
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Method')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.expenses.map((e) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(_fmt(e.expenseDate), style: AppTypography.tableCell),
                  ),
                  DataCell(
                    AppBadge(
                      label: e.category,
                      variant: AppBadgeVariant.primary,
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(e.description, style: AppTypography.tableCell),
                        if (e.reference != null)
                          Text(e.reference!, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  DataCell(Text(e.paymentMethod, style: AppTypography.caption)),
                  DataCell(
                    Text(
                      e.amount.display,
                      style: AppTypography.numeric.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.error,
                      ),
                      tooltip: 'Delete',
                      splashRadius: 16,
                      onPressed: () => _delete(e),
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
