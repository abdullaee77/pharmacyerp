import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/dashboard_summary.dart';

/// Panel displaying prioritized pharmacy alerts (expiry, stock, payments).
class AlertPanel extends StatelessWidget {
  final List<AlertItem> alerts;

  const AlertPanel({super.key, required this.alerts});

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
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Active Alerts', style: AppTypography.subtitle),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Alert List
          Expanded(
            child: alerts.isEmpty
                ? Center(
              child: Text(
                'No active alerts. All clear!',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.success,
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _AlertTile(alert: alert);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertItem alert;

  const _AlertTile({required this.alert});

  Color get _severityColor {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return AppColors.error;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.info:
        return AppColors.info;
    }
  }

  Color get _severityBackground {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return AppColors.errorSurface;
      case AlertSeverity.warning:
        return AppColors.warningSurface;
      case AlertSeverity.info:
        return AppColors.infoSurface;
    }
  }

  IconData get _severityIcon {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return Icons.error_outline_rounded;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _severityBackground,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_severityIcon, size: 16, color: _severityColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: AppTypography.label.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.description,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatTimeAgo(alert.timestamp),
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}