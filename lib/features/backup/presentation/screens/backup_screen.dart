import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../controllers/backup_controller.dart';

class BackupScreen extends StatefulWidget {
  final BackupController controller;

  const BackupScreen({super.key, required this.controller});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadInfo();
    });
  }

  Future<void> _backup() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Create Backup?',
      message:
          'This will create a copy of the current database. The application will remain operational during backup.',
    );
    if (ok) {
      final success = await widget.controller.performBackup();
      if (mounted && success) AppToast.success(context, 'Backup completed.');
    }
  }

  Future<void> _restore() async {
    final ok = await AppDialog.warning(
      context,
      title: 'Restore from Backup?',
      message:
          'WARNING: This will replace ALL current data with the backup data. This action cannot be undone. Make sure you have a current backup before proceeding.',
      confirmLabel: 'Restore',
    );
    if (ok) {
      final success = await widget.controller.performRestore();
      if (mounted && success) AppToast.success(context, 'Restore completed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final info = ctrl.info;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cloud_sync_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Backup & Network', style: AppTypography.pageTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Database status
              _SectionCard(
                title: 'Database Status',
                icon: Icons.storage_rounded,
                children: [
                  _kv('Database Path', info.databasePath),
                  _kv('Database Status', info.databaseSize),
                  _kv(
                    'Last Backup',
                    info.lastBackupAt != null
                        ? '${info.lastBackupAt!.day}/${info.lastBackupAt!.month}/${info.lastBackupAt!.year}'
                        : 'Never',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Backup actions
              _SectionCard(
                title: 'Backup & Restore',
                icon: Icons.backup_rounded,
                children: [
                  Text(
                    'Create regular backups to protect your pharmacy data. Store backups in a safe location.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      AppButton(
                        label: 'Backup Now',
                        icon: Icons.cloud_upload_rounded,
                        variant: AppButtonVariant.primary,
                        isLoading: ctrl.isBackingUp,
                        onPressed: _backup,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: 'Restore',
                        icon: Icons.cloud_download_rounded,
                        variant: AppButtonVariant.danger,
                        isLoading: ctrl.isRestoring,
                        onPressed: _restore,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Server / LAN status
              _SectionCard(
                title: 'Server & Network',
                icon: Icons.lan_rounded,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.infoSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'This application is running in offline-first local mode. '
                            'LAN and server synchronization features will be available in a future update.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _kv('Server Status', 'Local Only'),
                  _kv('Network Mode', 'Offline'),
                  _kv('Sync Status', 'Not Configured'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Connected terminals
              _SectionCard(
                title: 'Connected Terminals',
                icon: Icons.devices_rounded,
                children: [
                  ...ctrl.nodes.map(
                    (node) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.computer_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.name,
                                  style: AppTypography.subtitle.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${node.type}  ·  ${node.ipAddress ?? 'N/A'}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          AppBadge(
                            label: node.status,
                            variant: node.status == 'Online'
                                ? AppBadgeVariant.success
                                : AppBadgeVariant.neutral,
                            isDot: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Status message
              if (ctrl.message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: ctrl.messageIsError
                        ? AppColors.errorSurface
                        : AppColors.successSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color:
                          (ctrl.messageIsError
                                  ? AppColors.error
                                  : AppColors.success)
                              .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    ctrl.message!,
                    style: AppTypography.bodySmall.copyWith(
                      color: ctrl.messageIsError
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
