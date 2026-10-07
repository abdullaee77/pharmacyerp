import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/role.dart';
import '../controllers/user_controller.dart';
import '../widgets/role_form_dialog.dart';

class RolesScreen extends StatefulWidget {
  final UserController controller;

  const RolesScreen({super.key, required this.controller});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controller.loadRoles(),
    );
  }

  Future<void> _addRole() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => RoleFormDialog(controller: widget.controller),
    );
    if (!mounted) return;
    if (error != null)
      AppToast.error(context, error);
    else
      AppToast.success(context, 'Role created.');
  }

  Future<void> _editRole(Role role) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          RoleFormDialog(controller: widget.controller, existing: role),
    );
    if (!mounted) return;
    if (error != null)
      AppToast.error(context, error);
    else
      AppToast.success(context, 'Role updated.');
  }

  Future<void> _deleteRole(Role role) async {
    if (role.isBuiltIn) {
      AppToast.warning(context, 'Cannot delete a built-in role.');
      return;
    }
    final ok = await AppDialog.warning(
      context,
      title: 'Delete Role?',
      message: '"${role.name}" will be permanently removed.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      final error = await widget.controller.deleteRole(role.id);
      if (!mounted) return;
      if (error != null)
        AppToast.error(context, error);
      else
        AppToast.success(context, 'Role deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Roles & Permissions', style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.roles.length} roles defined',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  label: 'Add Role',
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _addRole,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ctrl.isLoading
                  ? const AppLoading()
                  : ctrl.roles.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'No roles defined',
                      subtitle: 'Create a role to manage permissions.',
                    )
                  : ListView.separated(
                      itemCount: ctrl.roles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (ctx, i) {
                        final role = ctrl.roles[i];
                        final permCount = role.permissions.length;
                        final totalPerms = Permission.all.length;
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primarySurface,
                                child: Text(
                                  role.name[0].toUpperCase(),
                                  style: AppTypography.sectionTitle.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          role.name,
                                          style: AppTypography.subtitle,
                                        ),
                                        if (role.isBuiltIn) ...[
                                          const SizedBox(width: 8),
                                          const AppBadge(
                                            label: 'Built-in',
                                            variant: AppBadgeVariant.info,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      role.description.isEmpty
                                          ? '$permCount of $totalPerms permissions'
                                          : role.description,
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              AppButton(
                                label: 'Edit',
                                icon: Icons.edit_outlined,
                                variant: AppButtonVariant.outlined,
                                size: AppButtonSize.small,
                                onPressed: () => _editRole(role),
                              ),
                              if (!role.isBuiltIn) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                  tooltip: 'Delete',
                                  splashRadius: 16,
                                  onPressed: () => _deleteRole(role),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
