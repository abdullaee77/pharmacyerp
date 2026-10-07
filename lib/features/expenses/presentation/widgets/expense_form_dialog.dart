import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../accounts/domain/account.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/expense.dart';
import '../controllers/expense_controller.dart';

class ExpenseFormDialog extends StatefulWidget {
  final ExpenseController controller;
  final String operatorName;
  final List<AccountWithBalance> accounts;

  const ExpenseFormDialog({
    super.key,
    required this.controller,
    required this.operatorName,
    required this.accounts,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  String? _category;
  String _method = 'Cash';
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      AppToast.error(context, 'Select a category.');
      return;
    }

    setState(() => _isSaving = true);

    final expense = Expense(
      id: ExpenseId.generate(),
      category: _category!,
      description: _descCtrl.text.trim(),
      amount: Money.fromPkr(double.tryParse(_amountCtrl.text) ?? 0),
      paymentMethod: _method,
      accountId: _accountId,
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      operatorName: widget.operatorName,
      expenseDate: _date,
      createdAt: DateTime.now(),
    );

    final error = await widget.controller.createExpense(expense);
    setState(() => _isSaving = false);

    if (mounted) Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.controller.categories;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.money_off_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Record Expense', style: AppTypography.sectionTitle),
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
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: cats
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.name,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _category = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _amountCtrl,
                            label: 'Amount (PKR)',
                            prefixIcon: Icons.attach_money_rounded,
                            isRequired: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) =>
                                v == null || double.tryParse(v) == null
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _descCtrl,
                      label: 'Description',
                      prefixIcon: Icons.description_outlined,
                      isRequired: true,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.event_rounded),
                              ),
                              child: Text(
                                '${_date.day.toString().padLeft(2, '0')}/'
                                '${_date.month.toString().padLeft(2, '0')}/'
                                '${_date.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _method,
                            decoration: const InputDecoration(
                              labelText: 'Payment Method',
                            ),
                            items: const ['Cash', 'Card', 'Bank', 'Other']
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _method = v ?? 'Cash'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String?>(
                      value: _accountId,
                      decoration: const InputDecoration(
                        labelText: 'Account (optional)',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— None —'),
                        ),
                        ...widget.accounts.map(
                          (awb) => DropdownMenuItem(
                            value: awb.account.id.value,
                            child: Text(awb.account.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _refCtrl,
                      label: 'Reference (optional)',
                      prefixIcon: Icons.receipt_long_outlined,
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
                    label: 'Record Expense',
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
