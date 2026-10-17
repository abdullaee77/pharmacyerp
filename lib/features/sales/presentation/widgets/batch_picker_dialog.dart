import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../inventory/domain/batch.dart';
import '../../../medicines/domain/medicine.dart';

/// Dialog for selecting a specific physical batch.
class BatchPickerDialog extends StatelessWidget {
  final Medicine medicine;
  final List<Batch> batches;
  final BatchId? currentBatchId;

  const BatchPickerDialog({
    super.key,
    required this.medicine,
    required this.batches,
    this.currentBatchId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Specific Batch',
                            style: AppTypography.sectionTitle),
                        Text(
                          '${medicine.name} ${medicine.strength}  •  Select batch to apply batch-specific price & stock deduction',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Batch list
            Expanded(
              child: batches.isEmpty
                  ? const AppEmptyState(
                icon: Icons.layers_outlined,
                title: 'No active stock batches available',
                subtitle:
                'Receive a purchase invoice for this medicine to create physical batches.',
              )
                  : ListView.separated(
                padding:
                const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: batches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final b = batches[i];
                  final isCurrent = currentBatchId == b.id;
                  final isFefo = i == 0;
                  final isDisabled =
                      b.status == BatchStatus.expired ||
                          b.quantity.value <= 0;

                  AppBadgeVariant statusVariant;
                  switch (b.status) {
                    case BatchStatus.normal:
                      statusVariant = AppBadgeVariant.success;
                    case BatchStatus.expiringSoon:
                      statusVariant = AppBadgeVariant.warning;
                    case BatchStatus.expired:
                      statusVariant = AppBadgeVariant.error;
                  }

                  return InkWell(
                    onTap: isDisabled
                        ? null
                        : () => Navigator.of(context).pop(b),
                    child: Container(
                      color: isCurrent
                          ? AppColors.primarySurface
                          : (isDisabled
                          ? AppColors.surfaceVariant.withOpacity(0.5)
                          : null),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Batch: ${b.batchNumber.value}',
                                    style: AppTypography.subtitle
                                        .copyWith(fontSize: 14),
                                  ),
                                  if (isFefo) ...[
                                    const SizedBox(width: 8),
                                    const AppBadge(
                                      label: 'FEFO Recommended',
                                      variant: AppBadgeVariant.primary,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Exp: ${b.expiryDate.display}  •  ${b.expiryDate.daysRemaining}d remaining',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Display Batch Selling Price
                              Text(
                                b.sellingPrice.display,
                                style: AppTypography.numeric.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${b.quantity.value} units in stock',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.md),
                          AppBadge(
                            label: b.status.label,
                            variant: statusVariant,
                            isDot: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}