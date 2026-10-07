import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Semantic badge variants for status indicators.
enum AppBadgeVariant {
  success,
  warning,
  error,
  info,
  neutral,
  primary,
}

/// Compact status badge / tag component.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final bool isDot;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.isDot = false,
  });

  Color get _bgColor {
    switch (variant) {
      case AppBadgeVariant.success:
        return AppColors.successSurface;
      case AppBadgeVariant.warning:
        return AppColors.warningSurface;
      case AppBadgeVariant.error:
        return AppColors.errorSurface;
      case AppBadgeVariant.info:
        return AppColors.infoSurface;
      case AppBadgeVariant.neutral:
        return AppColors.surfaceVariant;
      case AppBadgeVariant.primary:
        return AppColors.primarySurface;
    }
  }

  Color get _fgColor {
    switch (variant) {
      case AppBadgeVariant.success:
        return AppColors.success;
      case AppBadgeVariant.warning:
        return AppColors.warning;
      case AppBadgeVariant.error:
        return AppColors.error;
      case AppBadgeVariant.info:
        return AppColors.info;
      case AppBadgeVariant.neutral:
        return AppColors.textSecondary;
      case AppBadgeVariant.primary:
        return AppColors.primary;
    }
  }

  Color get _borderColor {
    return _fgColor.withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDot ? AppSpacing.sm : AppSpacing.sm,
        vertical: isDot ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _fgColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null && !isDot) ...[
            Icon(icon, size: 12, color: _fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: _fgColor,
            ),
          ),
        ],
      ),
    );
  }
}