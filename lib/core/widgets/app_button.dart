import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Button variant types.
enum AppButtonVariant {
  primary,
  outlined,
  ghost,
  danger,
  success,
}

/// Button size presets.
enum AppButtonSize {
  small,
  medium,
  large,
}

/// Unified button component with variant, size, loading, and icon support.
class AppButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  bool get _isEnabled => onPressed != null && !isLoading;

  double get _height {
    switch (size) {
      case AppButtonSize.small:
        return 32;
      case AppButtonSize.medium:
        return 40;
      case AppButtonSize.large:
        return 48;
    }
  }

  double get _horizontalPadding {
    switch (size) {
      case AppButtonSize.small:
        return AppSpacing.md;
      case AppButtonSize.medium:
        return AppSpacing.lg;
      case AppButtonSize.large:
        return AppSpacing.xl;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case AppButtonSize.small:
        return AppTypography.buttonSmall;
      case AppButtonSize.medium:
        return AppTypography.button;
      case AppButtonSize.large:
        return AppTypography.button.copyWith(fontSize: 15);
    }
  }

  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 14;
      case AppButtonSize.medium:
        return 16;
      case AppButtonSize.large:
        return 18;
    }
  }

  Color get _bgColor {
    if (!_isEnabled) return AppColors.disabled;
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.outlined:
        return AppColors.surface;
      case AppButtonVariant.ghost:
        return Colors.transparent;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.success:
        return AppColors.success;
    }
  }

  Color get _fgColor {
    if (!_isEnabled) return AppColors.disabledText;
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.textInverse;
      case AppButtonVariant.outlined:
        return AppColors.primary;
      case AppButtonVariant.ghost:
        return AppColors.primary;
      case AppButtonVariant.danger:
        return AppColors.textInverse;
      case AppButtonVariant.success:
        return AppColors.textInverse;
    }
  }

  Color get _borderColor {
    if (!_isEnabled) return AppColors.disabled;
    switch (variant) {
      case AppButtonVariant.outlined:
        return AppColors.border;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
      height: _iconSize,
      width: _iconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(_fgColor),
      ),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _iconSize, color: _fgColor),
          if (label != null) const SizedBox(width: AppSpacing.sm),
        ],
        if (label != null)
          Text(label!, style: _textStyle.copyWith(color: _fgColor)),
        if (trailingIcon != null) ...[
          if (label != null) const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: _iconSize, color: _fgColor),
        ],
      ],
    );

    final button = Material(
      color: _bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: _isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: _fgColor.withValues(alpha: 0.08),
        child: Container(
          height: _height,
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _borderColor, width: 1),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}