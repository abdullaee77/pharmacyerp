import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/customer.dart';
import '../controllers/customer_controller.dart';

class CustomerPaymentDialog extends StatefulWidget {
  final CustomerController controller;
  final Customer customer;
  final Money currentOutstanding;
  final String operatorName;

  const CustomerPaymentDialog({
    super.key,
    required this.controller,
    required this.customer,
    required this.currentOutstanding,
    required this.operatorName,
  });

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = 'Cash';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.currentOutstanding.paisa > 0
        ? widget.currentOutstanding.pkr.toStringAsFixed(2)
        : '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.error(context, 'Enter a valid payment amount.');
      return;
    }

    setState(() => _isSaving = true);
    final error = await widget.controller.recordPayment(
      customerId: widget.customer.id,
      amount: Money.fromPkr(amount),
      paymentMethod: _method,
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      operatorName: widget.operatorName,
    );

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (error != null) {
      AppToast.error(context, error);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Record Payment', style: AppTypography.sectionTitle),
                      Text(
                        'From ${widget.customer.name}',
                        style: AppTypography.caption,
                      ),
                    ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Outstanding',
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          widget.currentOutstanding.display,
                          style: AppTypography.numericLarge.copyWith(
                            fontSize: 18,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _amountCtrl,
                    label: 'Payment Amount (PKR)',
                    prefixIcon: Icons.attach_money_rounded,
                    isRequired: true,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _method,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: const ['Cash', 'Card', 'Bank', 'Other']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _method = v ?? 'Cash'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _refCtrl,
                    label: 'Reference (optional)',
                    prefixIcon: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _noteCtrl,
                    label: 'Note (optional)',
                    maxLines: 2,
                  ),
                ],
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
                    label: 'Record Payment',
                    variant: AppButtonVariant.success,
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
