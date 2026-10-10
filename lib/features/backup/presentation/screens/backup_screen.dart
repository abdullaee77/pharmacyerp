import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/backup_models.dart';
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

  // ── Create Backup ──
  Future<void> _backup() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Create Backup?',
      message:
      'This will save a copy of your database to:\n'
          'Documents/PharmaSuite Backups/\n\n'
          'The last 3 backups are kept automatically.',
    );
    if (ok) {
      final success = await widget.controller.performBackup();
      if (mounted && success) AppToast.success(context, 'Backup created.');
    }
  }

  // ── Restore from selected file / entry ──
  Future<void> _restorePath(String targetPath, String displayName) async {
    final confirm = await AppDialog.warning(
      context,
      title: 'Restore Backup?',
      message:
      'WARNING: This will replace ALL current data with the backup:\n'
          '$displayName\n\n'
          'This action CANNOT be undone. Proceed?',
      confirmLabel: 'Restore',
    );
    if (confirm) {
      final success = await widget.controller.performRestore(targetPath);
      if (mounted && success) {
        AppToast.success(context, 'Database restored successfully.');
      }
    }
  }

  // ── Main Restore Button (Under "Backup Now") ──
  Future<void> _restoreMain() async {
    final ctrl = widget.controller;
    await ctrl.loadBackups();
    if (!mounted) return;

    if (ctrl.backups.isEmpty) {
      // If no local backups exist, open Browse File directly
      await _browseAndRestore();
      return;
    }

    // Show selection dialog of available backups + browse option
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Backup to Restore'),
        content: SizedBox(
          width: 480,
          height: 320,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: ctrl.backups.length,
                  itemBuilder: (ctx, i) {
                    final b = ctrl.backups[i];
                    return ListTile(
                      leading: const Icon(Icons.history_rounded,
                          color: AppColors.primary),
                      title: Text(b.dateFormatted,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${b.fileName} · ${b.sizeFormatted}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14),
                      onTap: () => Navigator.of(ctx).pop(b.filePath),
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded,
                    color: AppColors.warning),
                title: const Text('Browse Other File...'),
                subtitle: const Text('Select custom database file from Explorer / Finder'),
                onTap: () {
                  Navigator.of(ctx).pop('__BROWSE__');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    if (selected == '__BROWSE__') {
      await _browseAndRestore();
    } else {
      await _restorePath(selected, p.basename(selected));
    }
  }

  // ── Browse External File using Native Dialog ──
  Future<void> _browseAndRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select PharmaSuite Database Backup (.db)',
      );

      if (result == null || result.files.isEmpty) {
        return; // User closed file picker
      }

      final selectedPath = result.files.single.path;
      if (selectedPath == null || selectedPath.isEmpty) return;

      final fileName = p.basename(selectedPath);
      await _restorePath(selectedPath, fileName);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not access file browser: $e');
      }
    }
  }

  Future<void> _delete(BackupEntry entry) async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Delete Backup?',
      message: 'Delete "${entry.fileName}" permanently?',
    );
    if (ok) await widget.controller.deleteBackup(entry);
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
                  const Icon(Icons.cloud_sync_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Text('Backup & Network', style: AppTypography.pageTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Database Status ──
              _SectionCard(
                title: 'Database Status',
                icon: Icons.storage_rounded,
                children: [
                  _kv('Database Size', info.databaseSize),
                  _kv('WAL Mode', 'Enabled (power-failure safe)'),
                  _kv('Auto-Backup', 'On app open & close (keeps last 3)'),
                  _kv(
                    'Latest Backup',
                    ctrl.backups.isNotEmpty
                        ? ctrl.backups.first.dateFormatted
                        : 'Never',
                  ),
                  _kv('Backup Folder', info.backupLocation),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Backup & Restore (Restore button directly under Backup Now) ──
              _SectionCard(
                title: 'Backup & Restore',
                icon: Icons.backup_rounded,
                children: [
                  Text(
                    'Backups are saved to Documents/PharmaSuite Backups/. '
                        'You can copy these files to USB or share them via WhatsApp/Email.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppButton(
                        label: 'Backup Now',
                        icon: Icons.save_rounded,
                        variant: AppButtonVariant.primary,
                        isLoading: ctrl.isBackingUp,
                        onPressed: _backup,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Restore',
                        icon: Icons.restore_rounded,
                        variant: AppButtonVariant.danger,
                        isLoading: ctrl.isRestoring,
                        onPressed: _restoreMain,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Available Backups List ──
              _SectionCard(
                title: 'Available Backups (${ctrl.backups.length}/3)',
                icon: Icons.folder_open_rounded,
                children: [
                  if (ctrl.backups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No backups created yet. Tap "Backup Now" above.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...ctrl.backups.map((entry) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 22, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.dateFormatted,
                                  style: AppTypography.subtitle
                                      .copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${entry.fileName}  ·  ${entry.sizeFormatted}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          AppButton(
                            label: 'Restore',
                            icon: Icons.restore_rounded,
                            variant: AppButtonVariant.danger,
                            isLoading: ctrl.isRestoring,
                            onPressed: () => _restorePath(
                                entry.filePath, entry.dateFormatted),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            tooltip: 'Delete this backup',
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20),
                            color: AppColors.error,
                            onPressed: () => _delete(entry),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Server & Terminals ──
              _SectionCard(
                title: 'Server & Network',
                icon: Icons.lan_rounded,
                children: [
                  _kv('Server Status', 'Local Only'),
                  _kv('Network Mode', 'Offline'),
                  _kv('Sync Status', 'Not Configured'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

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
                          const Icon(Icons.computer_rounded,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(node.name,
                                    style: AppTypography.subtitle
                                        .copyWith(fontSize: 14)),
                                Text(
                                    '${node.type}  ·  ${node.ipAddress ?? 'N/A'}',
                                    style: AppTypography.caption),
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

              // ── Status Message ──
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
                      color: (ctrl.messageIsError
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
            width: 140,
            child: Text(k,
                style:
                AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v,
                style:
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
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