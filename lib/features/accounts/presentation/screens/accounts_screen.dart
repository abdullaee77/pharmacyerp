import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../users/domain/role.dart';
import '../../domain/account.dart';
import '../controllers/account_controller.dart';
import '../widgets/account_form_dialog.dart';
import '../widgets/account_ledger_dialog.dart';

class AccountsScreen extends StatefulWidget {
  final AccountController controller;
  final AuthController authController;

  const AccountsScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadAccounts();
    });
  }

  bool get _canAdd => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.accounts, PermissionAction.add);
  bool get _canEdit => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.accounts, PermissionAction.edit);
  bool get _canDelete => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.accounts, PermissionAction.delete);

  Future<void> _add() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => AccountFormDialog(controller: widget.controller),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Account added.');
    }
  }

  Future<void> _edit(Account a) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          AccountFormDialog(controller: widget.controller, existing: a),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Account updated.');
    }
  }

  Future<void> _openLedger(AccountWithBalance awb) async {
    await showDialog(
      context: context,
      builder: (ctx) =>
          AccountLedgerDialog(controller: widget.controller, account: awb),
    );
  }

  Future<void> _delete(Account a) async {
    final ok = await AppDialog.warning(
      context,
      title: 'Delete Account?',
      message: '"${a.name}" and all its transactions will be removed.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      final error = await widget.controller.deleteAccount(a.id);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Account deleted.');
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
                const Icon(Icons.account_balance_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accounts', style: AppTypography.pageTitle),
                    Text('${ctrl.accounts.length} accounts tracked',
                        style: AppTypography.bodySmall),
                  ],
                ),
                const Spacer(),
                if (_canAdd)
                  AppButton(
                    label: 'Add Account',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _add,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchBar(
              hint: 'Search account name...',
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

  Widget _buildTable(AccountController ctrl) {
    if (ctrl.isLoading) return const AppLoading(message: 'Loading accounts...');
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadAccounts,
      );
    }
    if (ctrl.accounts.isEmpty) {
      return AppEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No accounts yet',
        subtitle:
        'Add Cash, Bank, or Expense accounts to track financial activity.',
        actionLabel: _canAdd ? 'Add Account' : null,
        onAction: _canAdd ? _add : null,
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
              DataColumn(label: Text('Account')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Opening'), numeric: true),
              DataColumn(label: Text('Current Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.accounts.map((awb) {
              final a = awb.account;
              final bal = awb.currentBalance;
              final balColor =
              bal.paisa >= 0 ? AppColors.success : AppColors.error;

              return DataRow(
                onSelectChanged: (_) => _openLedger(awb),
                cells: [
                  DataCell(Text(a.name,
                      style: AppTypography.tableCell
                          .copyWith(fontWeight: FontWeight.w600))),
                  DataCell(AppBadge(
                      label: a.accountType.label,
                      variant: AppBadgeVariant.primary)),
                  DataCell(Text(a.openingBalance.display,
                      style: AppTypography.numericSmall)),
                  DataCell(Text(
                    bal.display,
                    style: AppTypography.numeric.copyWith(
                      color: balColor,
                      fontWeight: FontWeight.w800,
                    ),
                  )),
                  DataCell(AppBadge(
                    label: a.status.label,
                    variant: a.status == AccountStatus.active
                        ? AppBadgeVariant.success
                        : AppBadgeVariant.neutral,
                    isDot: true,
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_book_outlined, size: 16),
                        tooltip: 'Ledger',
                        splashRadius: 16,
                        onPressed: () => _openLedger(awb),
                      ),
                      if (_canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit',
                          splashRadius: 16,
                          onPressed: () => _edit(a),
                        ),
                      if (_canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.error),
                          tooltip: 'Delete',
                          splashRadius: 16,
                          onPressed: () => _delete(a),
                        ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}