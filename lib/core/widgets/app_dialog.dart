import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Static dialog helpers for consistent confirmation and alert flows.
class AppDialog {
  AppDialog._();

  /// Confirmation dialog with cancel/confirm actions.
  static Future<bool> confirm(
      BuildContext context, {
        required String title,
        required String message,
        String confirmLabel = 'Confirm',
        String cancelLabel = 'Cancel',
        AppButtonVariant confirmVariant = AppButtonVariant.primary,
        IconData? icon,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BaseDialog(
        icon: icon ?? Icons.help_outline_rounded,
        iconColor: _variantColor(confirmVariant),
        title: title,
        message: message,
        actions: [
          AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: confirmLabel,
            variant: confirmVariant,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Informational alert with a single dismiss button.
  static Future<void> info(
      BuildContext context, {
        required String title,
        required String message,
        String dismissLabel = 'OK',
      }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _BaseDialog(
        icon: Icons.info_outline_rounded,
        iconColor: AppColors.info,
        title: title,
        message: message,
        actions: [
          AppButton(
            label: dismissLabel,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  /// Error alert dialog.
  static Future<void> error(
      BuildContext context, {
        required String title,
        required String message,
        String dismissLabel = 'Close',
      }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _BaseDialog(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
        title: title,
        message: message,
        actions: [
          AppButton(
            label: dismissLabel,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  /// Warning alert dialog.
  static Future<bool> warning(
      BuildContext context, {
        required String title,
        required String message,
        String confirmLabel = 'Proceed',
        String cancelLabel = 'Cancel',
      }) async {
    return confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmVariant: AppButtonVariant.danger,
      icon: Icons.warning_amber_rounded,
    );
  }

  static Color _variantColor(AppButtonVariant variant) {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.success:
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }
}

class _BaseDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;

  const _BaseDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actions: actions,
    );
  }
}