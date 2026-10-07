import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/account.dart';
import '../controllers/account_controller.dart';

class AccountFormDialog extends StatefulWidget {
  final AccountController controller;
  final Account? existing;

  const AccountFormDialog({super.key, required this.controller, this.existing});

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _openingCtrl;
  late final TextEditingController _notesCtrl;
  AccountType _type = AccountType.cash;
  AccountStatus _status = AccountStatus.active;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _openingCtrl = TextEditingController(
      text: a != null ? a.openingBalance.pkr.toStringAsFixed(2) : '0.00',
    );
    _notesCtrl = TextEditingController(text: a?.notes ?? '');
    _type = a?.accountType ?? AccountType.cash;
    _status = a?.status ?? AccountStatus.active;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final account = Account(
      id: _isEdit ? widget.existing!.id : AccountId.generate(),
      name: _nameCtrl.text.trim(),
      accountType: _type,
      openingBalance: Money.fromPkr(double.tryParse(_openingCtrl.text) ?? 0),
      status: _status,
      notes: _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    final error = _isEdit
        ? await widget.controller.updateAccount(account)
        : await widget.controller.createAccount(account);

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_isEdit ? 'Edit Account' : 'Add Account',
                      style: AppTypography.sectionTitle),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
                      label: 'Account Name',
                      prefixIcon: Icons.label_outline_rounded,
                      isRequired: true,
                      autofocus: true,
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<AccountType>(
                            value: _type,
                            decoration:
                            const InputDecoration(labelText: 'Account Type'),
                            items: AccountType.values
                                .map((t) => DropdownMenuItem(
                                value: t, child: Text(t.label)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _type = v ?? AccountType.cash),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _openingCtrl,
                            label: 'Opening Balance (PKR)',
                            prefixIcon: Icons.attach_money_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<AccountStatus>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: AccountStatus.values
                          .map((s) => DropdownMenuItem(
                          value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _status = v ?? AccountStatus.active),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _notesCtrl,
                      label: 'Notes',
                      maxLines: 2,
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
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: _isEdit ? 'Save Changes' : 'Add Account',
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