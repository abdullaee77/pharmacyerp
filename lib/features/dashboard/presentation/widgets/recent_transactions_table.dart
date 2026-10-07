import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/dashboard_summary.dart';

/// Compact data table displaying the most recent pharmacy transactions.
class RecentTransactionsTable extends StatelessWidget {
  final List<RecentTransaction> transactions;

  const RecentTransactionsTable({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Recent Transactions', style: AppTypography.subtitle),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.surfaceVariant,
            child: const Row(
              children: [
                SizedBox(width: 140, child: Text('Reference', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3))),
                SizedBox(width: 90, child: Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3))),
                Expanded(child: Text('Party', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3))),
                SizedBox(width: 120, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3))),
                SizedBox(width: 80, child: Text('Time', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3))),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
              itemBuilder: (context, index) {
                final txn = transactions[index];
                return _TransactionRow(txn: txn);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final RecentTransaction txn;

  const _TransactionRow({required this.txn});

  Color get _typeColor {
    switch (txn.type) {
      case TransactionType.sale:
        return AppColors.success;
      case TransactionType.purchase:
        return AppColors.info;
      case TransactionType.saleReturn:
        return AppColors.warning;
      case TransactionType.purchaseReturn:
        return AppColors.warning;
      case TransactionType.expense:
        return AppColors.error;
    }
  }

  Color get _amountColor {
    switch (txn.type) {
      case TransactionType.sale:
        return AppColors.success;
      case TransactionType.purchase:
        return AppColors.textPrimary;
      case TransactionType.saleReturn:
        return AppColors.error;
      case TransactionType.purchaseReturn:
        return AppColors.success;
      case TransactionType.expense:
        return AppColors.error;
    }
  }

  String get _amountPrefix {
    switch (txn.type) {
      case TransactionType.sale:
        return '+';
      case TransactionType.purchase:
        return '−';
      case TransactionType.saleReturn:
        return '−';
      case TransactionType.purchaseReturn:
        return '+';
      case TransactionType.expense:
        return '−';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: AppColors.surfaceHover,
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Reference
            SizedBox(
              width: 140,
              child: Text(
                txn.referenceNumber,
                style: AppTypography.numericSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Type Badge
            SizedBox(
              width: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  txn.typeLabel,
                  style: AppTypography.caption.copyWith(
                    color: _typeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            // Party Name
            Expanded(
              child: Text(
                txn.partyName,
                style: AppTypography.tableCell,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Amount
            SizedBox(
              width: 120,
              child: Text(
                '$_amountPrefix ${txn.amount.formatted}',
                textAlign: TextAlign.right,
                style: AppTypography.numeric.copyWith(
                  color: _amountColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Time
            SizedBox(
              width: 80,
              child: Text(
                _formatTime(txn.timestamp),
                textAlign: TextAlign.right,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}