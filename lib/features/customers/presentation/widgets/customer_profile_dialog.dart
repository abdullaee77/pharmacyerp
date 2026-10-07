import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/customer.dart';
import '../../domain/customer_ledger.dart';
import '../controllers/customer_controller.dart';
import 'customer_payment_dialog.dart';

class CustomerProfileDialog extends StatefulWidget {
  final CustomerController controller;
  final CustomerWithBalance customer;
  final String operatorName;
  final VoidCallback onEdit;

  const CustomerProfileDialog({
    super.key,
    required this.controller,
    required this.customer,
    required this.operatorName,
    required this.onEdit,
  });

  @override
  State<CustomerProfileDialog> createState() => _CustomerProfileDialogState();
}

class _CustomerProfileDialogState extends State<CustomerProfileDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadLedger(widget.customer.customer.id);
    });
  }

  Future<void> _openPayment() async {
    // Recompute outstanding from controller's loaded customers to catch latest.
    final latest = widget.controller.customers.firstWhere(
      (c) => c.customer.id == widget.customer.customer.id,
      orElse: () => widget.customer,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomerPaymentDialog(
        controller: widget.controller,
        customer: latest.customer,
        currentOutstanding: latest.outstanding,
        operatorName: widget.operatorName,
      ),
    );

    if (result == true && mounted) {
      AppToast.success(context, 'Payment recorded.');
    }
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final latest = widget.controller.customers.firstWhere(
          (c) => c.customer.id == widget.customer.customer.id,
          orElse: () => widget.customer,
        );
        final c = latest.customer;
        final outstanding = latest.outstanding;
        final ledger = widget.controller.activeLedger;

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: AppTypography.sectionTitle.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(c.name, style: AppTypography.sectionTitle),
                                const SizedBox(width: 8),
                                AppBadge(
                                  label: c.status.label,
                                  variant: c.status == CustomerStatus.active
                                      ? AppBadgeVariant.success
                                      : AppBadgeVariant.neutral,
                                  isDot: true,
                                ),
                              ],
                            ),
                            if (c.phone.isNotEmpty || c.email.isNotEmpty)
                              Text(
                                [
                                  c.phone,
                                  c.email,
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: AppTypography.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Record Payment',
                        icon: Icons.payments_rounded,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        onPressed: _openPayment,
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        variant: AppButtonVariant.outlined,
                        size: AppButtonSize.small,
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Summary cards
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          'Outstanding',
                          outstanding.display,
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _summaryCard(
                          'Credit Limit',
                          c.creditLimit.display,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _summaryCard(
                          'Last Activity',
                          latest.lastActivityAt == null
                              ? '—'
                              : _fmtDate(latest.lastActivityAt!),
                          AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ledger
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Ledger', style: AppTypography.subtitle),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(child: _buildLedger(ledger)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.numericLarge.copyWith(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedger(List<LedgerRow> rows) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No ledger entries yet',
        subtitle: 'Credit sales and payments will show here.',
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
            dataRowMaxHeight: 44,
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
              final e = row.entry;
              return DataRow(
                cells: [
                  DataCell(
                    Text(_fmtDate(e.createdAt), style: AppTypography.caption),
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
                  DataCell(
                    Text(
                      e.debit.paisa == 0 ? '—' : e.debit.display,
                      style: AppTypography.numericSmall.copyWith(
                        color: e.debit.paisa > 0
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      e.credit.paisa == 0 ? '—' : e.credit.display,
                      style: AppTypography.numericSmall.copyWith(
                        color: e.credit.paisa > 0
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      row.runningBalance.display,
                      style: AppTypography.numeric.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
