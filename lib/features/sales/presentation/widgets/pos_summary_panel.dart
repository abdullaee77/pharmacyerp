import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../controllers/pos_cart_controller.dart';

/// Bottom cart summary + payment action panel.
class PosSummaryPanel extends StatelessWidget {
  final PosCartController controller;
  final VoidCallback onPay;
  final VoidCallback onClear;
  final VoidCallback onHold;

  const PosSummaryPanel({
    super.key,
    required this.controller,
    required this.onPay,
    required this.onClear,
    required this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    final totals = controller.totals;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.shadowSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Info & Messages
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${totals.itemCount} Items  |  ${totals.totalUnits} Units',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (controller.lastMessage != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        controller.lastMessageIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 14,
                        color: controller.lastMessageIsError
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          controller.lastMessage!,
                          style: AppTypography.caption.copyWith(
                            color: controller.lastMessageIsError
                                ? AppColors.error
                                : AppColors.success,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Container(
            width: 1,
            height: 40,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),

          // Middle: Financials
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VerticalTotal(
                  'Subtotal',
                  totals.subtotal.display,
                  AppColors.textPrimary,
                ),
                _VerticalTotal(
                  'Discount',
                  totals.totalDiscount.display,
                  AppColors.success,
                ),
                _VerticalTotal(
                  'Grand Total',
                  totals.grandTotal.display,
                  AppColors.primary,
                  isLarge: true,
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 40,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),

          // Right: Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'Clear',
                icon: Icons.delete_sweep_outlined,
                variant: AppButtonVariant.ghost,
                onPressed: controller.isEmpty ? null : onClear,
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'Hold (F9)',
                icon: Icons.pause_circle_outline_rounded,
                variant: AppButtonVariant.outlined,
                onPressed: controller.isEmpty ? null : onHold,
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'Complete Sale (F8)',
                icon: Icons.payments_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.large,
                onPressed: controller.isEmpty ? null : onPay,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerticalTotal extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  const _VerticalTotal(
    this.label,
    this.value,
    this.color, {
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: isLarge
              ? AppTypography.numericLarge.copyWith(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                )
              : AppTypography.numeric.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }
}