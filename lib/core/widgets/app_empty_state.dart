import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Illustrated empty-state placeholder for lists, tables, and workspaces.
/// Overflow-safe and responsive even in tight containers.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 200;
        final padding = isCompact ? AppSpacing.sm : AppSpacing.xl;
        final iconSize = isCompact ? 32.0 : 48.0;

        return Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
                SizedBox(height: isCompact ? AppSpacing.xs : AppSpacing.md),
                Text(
                  title,
                  style: isCompact
                      ? AppTypography.subtitle.copyWith(color: AppColors.textSecondary)
                      : AppTypography.sectionTitle.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null && !isCompact) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.lg),
                  AppButton(
                    label: actionLabel,
                    variant: AppButtonVariant.primary,
                    size: isCompact ? AppButtonSize.small : AppButtonSize.medium,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}