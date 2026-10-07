import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../inventory/domain/batch.dart';
import '../../../medicines/domain/medicine.dart';

/// Dialog for selecting a batch when adding a medicine with multiple batches.
///
/// Batches are displayed in FEFO order; the earliest-expiry non-expired
/// batch is preselected.
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
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
                        Text('Select Batch', style: AppTypography.sectionTitle),
                        Text(
                          '${medicine.name} ${medicine.strength}',
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
                title: 'No batches available',
                subtitle:
                'Register a batch for this medicine before selling.',
              )
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                itemCount: batches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final b = batches[i];
                  final isCurrent = currentBatchId == b.id;
                  final isFefo = i == 0;

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
                    onTap: b.status == BatchStatus.expired
                        ? null
                        : () => Navigator.of(context).pop(b),
                    child: Container(
                      color: isCurrent ? AppColors.primarySurface : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    b.batchNumber.value,
                                    style: AppTypography.subtitle
                                        .copyWith(fontSize: 14),
                                  ),
                                  if (isFefo) ...[
                                    const SizedBox(width: 8),
                                    const AppBadge(
                                      label: 'FEFO',
                                      variant: AppBadgeVariant.primary,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                'Expiry ${b.expiryDate.display}  ·  '
                                    '${b.expiryDate.daysRemaining}d left',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${b.quantity.value} units',
                                style: AppTypography.numeric
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              AppBadge(
                                label: b.status.label,
                                variant: statusVariant,
                                isDot: true,
                              ),
                            ],
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