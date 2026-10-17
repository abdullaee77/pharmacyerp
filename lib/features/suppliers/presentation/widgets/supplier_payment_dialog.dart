// import 'package:flutter/material.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../core/theme/app_spacing.dart';
// import '../../../../core/theme/app_typography.dart';
// import '../../../../core/widgets/components.dart';
// import '../../../medicines/domain/value_objects.dart';
// import '../../domain/supplier.dart';
// import '../controllers/supplier_controller.dart';
//
// class SupplierPaymentDialog extends StatefulWidget {
//   final SupplierController controller;
//   final Supplier supplier;
//   final Money currentPayable;
//   final String operatorName;
//
//   const SupplierPaymentDialog({
//     super.key,
//     required this.controller,
//     required this.supplier,
//     required this.currentPayable,
//     required this.operatorName,
//   });
//
//   @override
//   State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
// }
//
// class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
//   final _amountCtrl = TextEditingController();
//   final _refCtrl = TextEditingController();
//   final _noteCtrl = TextEditingController();
//   String _method = 'Cash';
//   bool _isSaving = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _amountCtrl.text = widget.currentPayable.paisa > 0
//         ? widget.currentPayable.pkr.toStringAsFixed(2)
//         : '';
//   }
//
//   @override
//   void dispose() {
//     _amountCtrl.dispose();
//     _refCtrl.dispose();
//     _noteCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _submit() async {
//     final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
//     if (amount <= 0) {
//       AppToast.error(context, 'Enter a valid payment amount.');
//       return;
//     }
//
//     setState(() => _isSaving = true);
//     final error = await widget.controller.recordPayment(
//       supplierId: widget.supplier.id,
//       amount: Money.fromPkr(amount),
//       paymentMethod: _method,
//       reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
//       note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
//       operatorName: widget.operatorName,
//     );
//
//     setState(() => _isSaving = false);
//     if (!mounted) return;
//
//     if (error != null) {
//       AppToast.error(context, error);
//     } else {
//       Navigator.of(context).pop(true);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 460),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(AppSpacing.lg),
//               child: Row(
//                 children: [
//                   const Icon(Icons.payments_rounded, color: AppColors.primary),
//                   const SizedBox(width: AppSpacing.sm),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Pay Supplier', style: AppTypography.sectionTitle),
//                       Text(widget.supplier.name, style: AppTypography.caption),
//                     ],
//                   ),
//                   const Spacer(),
//                   IconButton(
//                     icon: const Icon(Icons.close_rounded, size: 20),
//                     onPressed: _isSaving
//                         ? null
//                         : () => Navigator.of(context).pop(),
//                     splashRadius: 18,
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),
//             Padding(
//               padding: const EdgeInsets.all(AppSpacing.xl),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(AppSpacing.md),
//                     decoration: BoxDecoration(
//                       color: AppColors.errorSurface,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Amount We Owe',
//                           style: AppTypography.subtitle.copyWith(
//                             color: AppColors.error,
//                           ),
//                         ),
//                         Text(
//                           widget.currentPayable.display,
//                           style: AppTypography.numericLarge.copyWith(
//                             fontSize: 18,
//                             color: AppColors.error,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: AppSpacing.lg),
//                   AppTextField(
//                     controller: _amountCtrl,
//                     label: 'Payment Amount (PKR)',
//                     prefixIcon: Icons.attach_money_rounded,
//                     isRequired: true,
//                     autofocus: true,
//                     keyboardType: const TextInputType.numberWithOptions(
//                       decimal: true,
//                     ),
//                   ),
//                   const SizedBox(height: AppSpacing.md),
//                   DropdownButtonFormField<String>(
//                     value: _method,
//                     decoration: const InputDecoration(
//                       labelText: 'Payment Method',
//                     ),
//                     items: const ['Cash', 'Card', 'Bank', 'Other']
//                         .map((m) => DropdownMenuItem(value: m, child: Text(m)))
//                         .toList(),
//                     onChanged: (v) => setState(() => _method = v ?? 'Cash'),
//                   ),
//                   const SizedBox(height: AppSpacing.md),
//                   AppTextField(
//                     controller: _refCtrl,
//                     label: 'Reference (optional)',
//                     prefixIcon: Icons.receipt_long_outlined,
//                   ),
//                   const SizedBox(height: AppSpacing.md),
//                   AppTextField(
//                     controller: _noteCtrl,
//                     label: 'Note (optional)',
//                     maxLines: 2,
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),
//             Padding(
//               padding: const EdgeInsets.all(AppSpacing.lg),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   AppButton(
//                     label: 'Cancel',
//                     variant: AppButtonVariant.ghost,
//                     onPressed: _isSaving
//                         ? null
//                         : () => Navigator.of(context).pop(),
//                   ),
//                   const SizedBox(width: AppSpacing.md),
//                   AppButton(
//                     label: 'Record Payment',
//                     variant: AppButtonVariant.success,
//                     isLoading: _isSaving,
//                     onPressed: _isSaving ? null : _submit,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../accounts/domain/account.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/supplier.dart';
import '../controllers/supplier_controller.dart';

class SupplierPaymentDialog extends StatefulWidget {
  final SupplierController controller;
  final Supplier supplier;
  final Money currentPayable;
  final String operatorName;
  final List<AccountWithBalance> accounts;

  const SupplierPaymentDialog({
    super.key,
    required this.controller,
    required this.supplier,
    required this.currentPayable,
    required this.operatorName,
    required this.accounts,
  });

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = 'Cash';
  String? _accountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.currentPayable.paisa > 0
        ? widget.currentPayable.pkr.toStringAsFixed(2)
        : '';
    _syncAccountWithMethod(_method);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onMethodSelected(String method) {
    setState(() {
      _method = method;
      _syncAccountWithMethod(method);
    });
  }

  void _syncAccountWithMethod(String method) {
    if (widget.accounts.isEmpty) {
      _accountId = null;
      return;
    }

    if (method == 'Cash') {
      final cashAccounts =
      widget.accounts.where((a) => a.account.accountType == AccountType.cash).toList();
      _accountId = cashAccounts.isNotEmpty
          ? cashAccounts.first.account.id.value
          : null;
    } else if (method == 'Card' || method == 'Bank') {
      final bankAccounts =
      widget.accounts.where((a) => a.account.accountType == AccountType.bank).toList();
      _accountId = bankAccounts.isNotEmpty
          ? bankAccounts.first.account.id.value
          : null;
    } else {
      _accountId = widget.accounts.first.account.id.value;
    }
  }

  List<AccountWithBalance> get _filteredAccounts {
    if (_method == 'Cash') {
      return widget.accounts
          .where((a) => a.account.accountType == AccountType.cash)
          .toList();
    } else if (_method == 'Card' || _method == 'Bank') {
      return widget.accounts
          .where((a) => a.account.accountType == AccountType.bank)
          .toList();
    }
    return widget.accounts;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.error(context, 'Enter a valid payment amount.');
      return;
    }

    setState(() => _isSaving = true);
    final error = await widget.controller.recordPayment(
      supplierId: widget.supplier.id,
      amount: Money.fromPkr(amount),
      paymentMethod: _method,
      accountId: _accountId,
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
                      Text('Pay Supplier', style: AppTypography.sectionTitle),
                      Text(widget.supplier.name, style: AppTypography.caption),
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
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount We Owe',
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        Text(
                          widget.currentPayable.display,
                          style: AppTypography.numericLarge.copyWith(
                            fontSize: 18,
                            color: AppColors.error,
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
                      prefixIcon: Icon(Icons.payment_rounded),
                    ),
                    items: const ['Cash', 'Card', 'Bank', 'Other']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _onMethodSelected(v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Account dropdown (strictly filtered by method) ──
                  if (widget.accounts.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: _accountId,
                      decoration: const InputDecoration(
                        labelText: 'Payment Account',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— None —'),
                        ),
                        ..._filteredAccounts.map(
                              (awb) => DropdownMenuItem(
                            value: awb.account.id.value,
                            child: Text(awb.account.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),

                  if (widget.accounts.isNotEmpty)
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
