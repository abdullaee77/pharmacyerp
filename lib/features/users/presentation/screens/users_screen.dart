import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/app_user.dart';
import '../controllers/user_controller.dart';
import '../widgets/user_form_dialog.dart';

class UsersScreen extends StatefulWidget {
  final UserController controller;

  const UsersScreen({super.key, required this.controller});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadUsers();
      widget.controller.loadRoles();
    });
  }

  Future<void> _addUser() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => UserFormDialog(controller: widget.controller),
    );
    if (!mounted) return;
    if (error != null)
      AppToast.error(context, error);
    else
      AppToast.success(context, 'User created.');
  }

  Future<void> _editUser(AppUser u) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          UserFormDialog(controller: widget.controller, existing: u),
    );
    if (!mounted) return;
    if (error != null)
      AppToast.error(context, error);
    else
      AppToast.success(context, 'User updated.');
  }

  Future<void> _toggleStatus(AppUser u) async {
    final newStatus = u.status == UserStatus.active
        ? UserStatus.inactive
        : UserStatus.active;
    final label = newStatus == UserStatus.active ? 'activate' : 'deactivate';
    final ok = await AppDialog.confirm(
      context,
      title:
          '${newStatus == UserStatus.active ? 'Activate' : 'Deactivate'} User?',
      message: 'Are you sure you want to $label "${u.fullName}"?',
    );
    if (ok) {
      final error = await widget.controller.changeStatus(u.id, newStatus);
      if (!mounted) return;
      if (error != null)
        AppToast.error(context, error);
      else
        AppToast.success(context, 'User ${newStatus.label.toLowerCase()}.');
    }
  }

  Future<void> _resetPassword(AppUser u) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password', style: AppTypography.sectionTitle),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter new password for "${u.fullName}".',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: ctrl,
                label: 'New Password',
                obscureText: true,
                autofocus: true,
                isRequired: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.isNotEmpty && mounted) {
      final error = await widget.controller.resetPassword(u.id, ctrl.text);
      if (!mounted) return;
      if (error != null)
        AppToast.error(context, error);
      else
        AppToast.success(context, 'Password reset successfully.');
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
                  Icons.manage_accounts_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Management', style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.users.length} users registered',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  label: 'Add User',
                  icon: Icons.person_add_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: _addUser,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchBar(
              hint: 'Search by name, username, phone...',
              maxWidth: 420,
              onSearch: ctrl.search,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildTable(ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildTable(UserController ctrl) {
    if (ctrl.isLoading) return const AppLoading(message: 'Loading users...');
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadUsers,
      );
    }
    if (ctrl.users.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No users found',
        subtitle: 'Add your first user to manage access.',
        actionLabel: 'Add User',
        onAction: _addUser,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 52,
            horizontalMargin: AppSpacing.lg,
            columnSpacing: AppSpacing.xl,
            headingRowColor: WidgetStatePropertyAll(AppColors.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Full Name')),
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Last Login')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.users.map((u) {
              AppBadgeVariant statusVariant;
              switch (u.status) {
                case UserStatus.active:
                  statusVariant = AppBadgeVariant.success;
                case UserStatus.inactive:
                  statusVariant = AppBadgeVariant.neutral;
                case UserStatus.locked:
                  statusVariant = AppBadgeVariant.error;
              }
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      u.fullName,
                      style: AppTypography.tableCell.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(u.username, style: AppTypography.tableCell)),
                  DataCell(
                    AppBadge(
                      label: u.roleName.isEmpty ? '—' : u.roleName,
                      variant: AppBadgeVariant.primary,
                    ),
                  ),
                  DataCell(
                    Text(
                      u.phone.isEmpty ? '—' : u.phone,
                      style: AppTypography.tableCell,
                    ),
                  ),
                  DataCell(
                    AppBadge(
                      label: u.status.label,
                      variant: statusVariant,
                      isDot: true,
                    ),
                  ),
                  DataCell(
                    Text(
                      u.lastLoginAt == null
                          ? 'Never'
                          : '${u.lastLoginAt!.day}/${u.lastLoginAt!.month}/${u.lastLoginAt!.year}',
                      style: AppTypography.caption,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit',
                          splashRadius: 16,
                          onPressed: () => _editUser(u),
                        ),
                        IconButton(
                          icon: Icon(
                            u.status == UserStatus.active
                                ? Icons.block_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: u.status == UserStatus.active
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          tooltip: u.status == UserStatus.active
                              ? 'Deactivate'
                              : 'Activate',
                          splashRadius: 16,
                          onPressed: () => _toggleStatus(u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.lock_reset_rounded, size: 16),
                          tooltip: 'Reset Password',
                          splashRadius: 16,
                          onPressed: () => _resetPassword(u),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
