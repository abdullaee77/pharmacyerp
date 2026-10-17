import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/account.dart';
import '../controllers/account_controller.dart';

class AccountFormDialog extends StatefulWidget {
  final AccountController controller;
  final Account? existing;

  const AccountFormDialog({
    super.key,
    required this.controller,
    this.existing,
  });

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
  String? _inlineError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _nameCtrl = TextEditingController(text: a?.name ?? '');

    final openingPkr = a != null ? (a.openingBalance.paisa / 100.0) : 0.0;
    _openingCtrl = TextEditingController(
      text: openingPkr == 0 ? '0.00' : openingPkr.toStringAsFixed(2),
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

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    final now = DateTime.now();
    final parsedPkr = double.tryParse(_openingCtrl.text.trim()) ?? 0.0;
    final paisa = (parsedPkr * 100).round();

    final account = Account(
      id: _isEdit ? widget.existing!.id : AccountId.generate(),
      name: _nameCtrl.text.trim(),
      accountType: _type,
      openingBalance: Money.fromPaisa(paisa),
      status: _status,
      notes: _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    final error = _isEdit
        ? await widget.controller.updateAccount(account)
        : await widget.controller.createAccount(account);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSaving = false;
        _inlineError = error;
      });
      return;
    }

    Navigator.of(context).pop(true); // Success
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_isEdit ? 'Edit Account' : 'Add Account', style: AppTypography.sectionTitle),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
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
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<AccountType>(
                              value: _type,
                              decoration: const InputDecoration(
                                labelText: 'Account Type',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: AccountType.values
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                                  .toList(),
                              onChanged: (v) => setState(() => _type = v ?? AccountType.cash),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _openingCtrl,
                              label: 'Opening Balance',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<AccountStatus>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: AccountStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v ?? AccountStatus.active),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _notesCtrl,
                        label: 'Notes',
                        maxLines: 2,
                      ),

                      if (_inlineError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.error.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _inlineError!,
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
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