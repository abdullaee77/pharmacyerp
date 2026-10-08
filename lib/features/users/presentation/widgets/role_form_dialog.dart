// lib/features/users/presentation/widgets/role_form_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/role.dart';
import '../controllers/user_controller.dart';

class RoleFormDialog extends StatefulWidget {
  final UserController controller;
  final Role? existing;

  const RoleFormDialog({super.key, required this.controller, this.existing});

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late Set<Permission> _permissions;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  /// Map of category to only the actions actively verified by our app.
  static const Map<PermissionCategory, List<PermissionAction>> _supportedPermissions = {
    PermissionCategory.dashboard: [PermissionAction.view],
    PermissionCategory.sales: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.returnAction,
      PermissionAction.discount,
      PermissionAction.manage,
    ],
    PermissionCategory.purchases: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.returnAction,
      PermissionAction.manage,
    ],
    PermissionCategory.inventory: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.edit,
      PermissionAction.delete,
      PermissionAction.adjust,
      PermissionAction.manage,
    ],
    PermissionCategory.medicines: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.edit,
      PermissionAction.delete,
      PermissionAction.manage,
    ],
    PermissionCategory.customers: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.edit,
      PermissionAction.delete,
      PermissionAction.manage,
    ],
    PermissionCategory.suppliers: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.edit,
      PermissionAction.delete,
      PermissionAction.manage,
    ],
    PermissionCategory.accounts: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.edit,
      PermissionAction.delete,
      PermissionAction.manage,
    ],
    PermissionCategory.reports: [
      PermissionAction.view,
      PermissionAction.export,
    ],
    PermissionCategory.users: [
      PermissionAction.view,
      PermissionAction.add,
      PermissionAction.edit,
      PermissionAction.delete,
      PermissionAction.manage,
    ],
    PermissionCategory.settings: [
      PermissionAction.view,
      PermissionAction.edit,
      PermissionAction.manage,
    ],
    PermissionCategory.licensing: [
      PermissionAction.view,
    ],
  };

  int get _totalSupportedCount =>
      _supportedPermissions.values.fold(0, (sum, list) => sum + list.length);

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existing?.name ?? '';
    _descCtrl.text = widget.existing?.description ?? '';

    // Copy permissions, keeping only supported permissions to prevent stale data
    final existingPerms = widget.existing?.permissions ?? const <Permission>{};
    _permissions = existingPerms.where((p) {
      final supportedActions = _supportedPermissions[p.category];
      return supportedActions != null && supportedActions.contains(p.action);
    }).toSet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _togglePermission(Permission p) {
    setState(() {
      if (_permissions.contains(p)) {
        _permissions.remove(p);
      } else {
        _permissions.add(p);
      }
    });
  }

  void _toggleCategory(PermissionCategory cat) {
    final actions = _supportedPermissions[cat] ?? [];
    final catPerms = actions.map((act) => Permission(cat, act)).toSet();
    final allSelected = catPerms.every((p) => _permissions.contains(p));

    setState(() {
      if (allSelected) {
        _permissions.removeAll(catPerms);
      } else {
        _permissions.addAll(catPerms);
      }
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      AppToast.error(context, 'Role name is required.');
      return;
    }
    setState(() => _isSaving = true);

    final role = Role(
      id: _isEdit ? widget.existing!.id : RoleId.generate(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isBuiltIn: widget.existing?.isBuiltIn ?? false,
      permissions: Set<Permission>.of(_permissions),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    final error = await widget.controller.saveRole(role, isNew: !_isEdit);
    if (mounted) setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(_isEdit ? 'Edit Role' : 'Add Role', style: AppTypography.sectionTitle),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  splashRadius: 18,
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(controller: _nameCtrl, label: 'Role Name', isRequired: true, autofocus: true),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(controller: _descCtrl, label: 'Description', maxLines: 2),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Permissions', style: AppTypography.subtitle.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${_permissions.length} of $_totalSupportedCount selected',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._supportedPermissions.entries.map((entry) {
                      final cat = entry.key;
                      final actions = entry.value;
                      final catPerms = actions.map((act) => Permission(cat, act)).toList();
                      final selectedCount = catPerms.where((p) => _permissions.contains(p)).length;
                      final allSelected = selectedCount == catPerms.length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ExpansionTile(
                          leading: Checkbox(
                            value: allSelected,
                            tristate: true,
                            onChanged: (_) => _toggleCategory(cat),
                          ),
                          title: Text(cat.label, style: AppTypography.subtitle.copyWith(fontSize: 14)),
                          subtitle: Text('$selectedCount / ${catPerms.length}', style: AppTypography.caption),
                          children: catPerms.map((p) {
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 48, right: 16),
                              value: _permissions.contains(p),
                              onChanged: (_) => _togglePermission(p),
                              title: Text(p.action.label, style: AppTypography.bodySmall),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.ghost,
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  label: _isEdit ? 'Save Changes' : 'Create Role',
                  variant: AppButtonVariant.primary,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submit,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}