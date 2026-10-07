import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../controllers/inventory_controller.dart';
import '../../domain/inventory_movement.dart';

/// Chronological transaction audit history log sheet.
class MovementHistoryDialog extends StatefulWidget {
  final InventoryController controller;
  final InventoryStock stock;

  const MovementHistoryDialog({
    super.key,
    required this.controller,
    required this.stock,
  });

  @override
  State<MovementHistoryDialog> createState() => _MovementHistoryDialogState();
}

class _MovementHistoryDialogState extends State<MovementHistoryDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadMovements(widget.stock.medicine.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final logs = widget.controller.activeMovements;

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audit Transaction Logs',
                            style: AppTypography.sectionTitle,
                          ),
                          Text(
                            widget.stock.medicine.name,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Movement Logs List
                Expanded(
                  child: logs.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.history_toggle_off_rounded,
                          title: 'No transaction history found',
                          subtitle:
                              'Stock balances have not been modified yet.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            final log = logs[index];
                            final isAddition = log.quantityChanged > 0;
                            final color = isAddition
                                ? AppColors.success
                                : AppColors.error;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  // Change indicator
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isAddition
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_down_rounded,
                                      color: color,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),

                                  // Left side descriptions
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.type == MovementType.adjustment &&
                                                  log.reason != null
                                              ? '${log.type.label} (${log.reason!.label})'
                                              : log.type.label,
                                          style: AppTypography.subtitle
                                              .copyWith(fontSize: 13),
                                        ),
                                        Text(
                                          'User: ${log.operatorName}  •  ${_formatDate(log.createdAt)}',
                                          style: AppTypography.caption,
                                        ),
                                        if (log.reference != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Note: "${log.reference}"',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  fontStyle: FontStyle.italic,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Right side signed value changes
                                  Text(
                                    '${isAddition ? "+" : ""}${log.quantityChanged}',
                                    style: AppTypography.numeric.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
