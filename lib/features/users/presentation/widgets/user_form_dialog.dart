// lib/features/users/presentation/widgets/user_form_dialog.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/app_user.dart';
import '../../domain/role.dart';
import '../controllers/user_controller.dart';

class UserFormDialog extends StatefulWidget {
  final UserController controller;
  final AppUser? existing;

  const UserFormDialog({super.key, required this.controller, this.existing});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;
  String? _roleId;
  UserStatus _status = UserStatus.active;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _nameCtrl = TextEditingController(text: u?.fullName ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _passwordCtrl = TextEditingController();
    _roleId =
        u?.roleId ??
            (widget.controller.roles.isNotEmpty
                ? widget.controller.roles.first.id.value
                : null);
    _status = u?.status ?? UserStatus.active;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final rawPassword = _passwordCtrl.text.trim();

    if (!_isEdit && rawPassword.isEmpty) {
      AppToast.error(context, 'Password is required for new users.');
      return;
    }
    if (_roleId == null) {
      AppToast.error(context, 'Select a role.');
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();

    // Hash the password into SHA-256 to align with client/server authentication comparisons
    final hashedPassword =
    rawPassword.isNotEmpty ? _hashPassword(rawPassword) : '';

    final user = AppUser(
      id: _isEdit ? widget.existing!.id : AppUserId.generate(),
      fullName: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      roleId: _roleId!,
      status: _status,
      passwordHash: hashedPassword.isNotEmpty
          ? hashedPassword
          : (widget.existing?.passwordHash ?? ''),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    String? error;
    if (_isEdit) {
      error = await widget.controller.updateUser(user);
    } else {
      error = await widget.controller.createUser(user, hashedPassword);
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    final roles = widget.controller.roles;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEdit ? 'Edit User' : 'Add User',
                    style: AppTypography.sectionTitle,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      prefixIcon: Icons.person_outline_rounded,
                      isRequired: true,
                      autofocus: true,
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: IgnorePointer(
                            ignoring: _isEdit,
                            child: Opacity(
                              opacity: _isEdit ? 0.6 : 1.0,
                              child: AppTextField(
                                controller: _usernameCtrl,
                                label: 'Username',
                                prefixIcon: Icons.alternate_email_rounded,
                                isRequired: true,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _phoneCtrl,
                            label: 'Phone',
                            prefixIcon: Icons.phone_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!_isEdit)
                      AppTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        isRequired: true,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _roleId,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
                            items: roles
                                .map(
                                  (r) => DropdownMenuItem(
                                value: r.id.value,
                                child: Text(r.name),
                              ),
                            )
                                .toList(),
                            onChanged: (v) => setState(() => _roleId = v),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<UserStatus>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items: UserStatus.values
                                .map(
                                  (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                                .toList(),
                            onChanged: (v) => setState(
                                  () => _status = v ?? UserStatus.active,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: _isEdit ? 'Save Changes' : 'Create User',
                    variant: AppButtonVariant.primary,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}