import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/account.dart';
import '../../domain/financial_transaction.dart';
import '../controllers/account_controller.dart';

class AccountLedgerDialog extends StatefulWidget {
  final AccountController controller;
  final AccountWithBalance account;

  const AccountLedgerDialog({
    super.key,
    required this.controller,
    required this.account,
  });

  @override
  State<AccountLedgerDialog> createState() => _AccountLedgerDialogState();
}

class _AccountLedgerDialogState extends State<AccountLedgerDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadLedger(widget.account.account.id);
    });
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final a = widget.account.account;
        final latest = widget.controller.accounts.firstWhere(
              (x) => x.account.id == a.id,
          orElse: () => widget.account,
        );
        final balance = latest.currentBalance;
        final ledger = widget.controller.activeLedger;

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: AppTypography.sectionTitle),
                          Text(
                            '${a.accountType.label}  ·  Opening: ${a.openingBalance.display}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Current Balance', style: AppTypography.caption),
                          Text(
                            balance.display,
                            style: AppTypography.numericLarge.copyWith(
                              color: balance.paisa >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.md),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _buildLedger(ledger),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLedger(List<FinancialTransactionRow> rows) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Transactions will appear here as expenses and manual entries are recorded.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 46,
            horizontalMargin: AppSpacing.md,
            columnSpacing: AppSpacing.lg,
            headingRowColor: WidgetStatePropertyAll(AppColors.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Debit'), numeric: true),
              DataColumn(label: Text('Credit'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
            ],
            rows: rows.map((row) {
              final tx = row.transaction;
              return DataRow(cells: [
                DataCell(Text(_fmt(tx.createdAt), style: AppTypography.caption)),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tx.description, style: AppTypography.tableCell),
                    Text(tx.source.label,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                )),
                DataCell(Text(
                  tx.debit.paisa == 0 ? '—' : tx.debit.display,
                  style: AppTypography.numericSmall.copyWith(
                    color: tx.debit.paisa > 0
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                )),
                DataCell(Text(
                  tx.credit.paisa == 0 ? '—' : tx.credit.display,
                  style: AppTypography.numericSmall.copyWith(
                    color: tx.credit.paisa > 0
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                )),
                DataCell(Text(
                  row.runningBalance.display,
                  style: AppTypography.numeric.copyWith(fontWeight: FontWeight.w700),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}