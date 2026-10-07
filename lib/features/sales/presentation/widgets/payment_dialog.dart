// lib/features/sales/presentation/widgets/payment_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/payment.dart';
import '../../domain/sale.dart';
import '../controllers/pos_cart_controller.dart';
import '../controllers/sales_controller.dart';
import 'invoice_dialog.dart';

class PaymentResult {
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final List<InvoiceLineData> lines;
  final String subtotal;
  final String discount;
  final String grandTotal;
  final String amountReceived;
  final String change;
  final String paymentSummary;
  final DateTime createdAt;

  const PaymentResult({
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.amountReceived,
    required this.change,
    required this.paymentSummary,
    required this.createdAt,
  });
}

class PaymentDialog extends StatefulWidget {
  final PosCartController cartController;
  final SalesController salesController;
  final String operatorName;

  const PaymentDialog({
    super.key,
    required this.cartController,
    required this.salesController,
    required this.operatorName,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  PaymentMethod _primaryMethod = PaymentMethod.cash;
  final _receivedCtrl = TextEditingController();

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _receivedCtrl.text = widget.cartController.totals.grandTotal.pkr.toStringAsFixed(2);
    _customerNameCtrl.text = widget.cartController.customerName == 'Walk-in Customer' ? '' : widget.cartController.customerName;
    _customerPhoneCtrl.text = widget.cartController.customerPhone;
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    super.dispose();
  }

  double get _totalTendered => double.tryParse(_receivedCtrl.text.trim()) ?? 0.0;
  double get _grandTotalPkr => widget.cartController.totals.grandTotal.pkr;
  double get _changePkr {
    final diff = _totalTendered - _grandTotalPkr;
    return diff > 0 ? diff : 0.0;
  }
  bool get _isCreditSelected => _primaryMethod == PaymentMethod.credit;
  bool get _isPaidInFull => _totalTendered >= _grandTotalPkr;

  Future<void> _process() async {
    if (!_isCreditSelected && !_isPaidInFull) {
      AppToast.error(context, 'Amount tendered is less than the total.');
      return;
    }

    setState(() => _isProcessing = true);

    // Save Customer Details to Cart Context
    widget.cartController.setCustomer(
      _customerNameCtrl.text,
      phone: _customerPhoneCtrl.text,
    );

    final cart = widget.cartController;
    final totals = cart.totals;
    final now = DateTime.now();
    final saleId = SaleId.generate();
    final invoice = InvoiceNumber.generate();

    final items = cart.items.map((ci) => SaleItem(
      id: ci.id.value,
      medicineId: ci.medicine.id,
      medicineName: ci.medicine.name,
      medicineStrength: ci.medicine.strength,
      batchId: ci.batch.id,
      batchNumber: ci.batch.batchNumber.value,
      quantity: ci.quantity,
      unitPrice: ci.unitPrice,
      discountPercent: ci.discountPercent,
      lineTotal: ci.lineTotal,
    )).toList();

    final amountReceived = Money.fromPkr(_totalTendered);
    final change = Money.fromPkr(_changePkr);

    final sale = Sale(
      id: saleId,
      invoiceNumber: invoice,
      customerName: cart.customerName,
      operatorName: widget.operatorName,
      items: items,
      subtotal: totals.subtotal,
      discount: totals.totalDiscount,
      grandTotal: totals.grandTotal,
      amountReceived: amountReceived,
      change: change,
      status: SaleStatus.completed,
      createdAt: now,
    );

    final tenders = <PaymentTender>[
      PaymentTender(method: _primaryMethod, amount: Money.fromPkr(_totalTendered)),
    ];

    // Pass customerPhone along to completeSale
    final error = await widget.salesController.completeSale(
      sale: sale,
      tenders: tenders,
      customerPhone: cart.customerPhone,
    );

    setState(() => _isProcessing = false);
    if (!mounted) return;

    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    final paymentSummary = '${_primaryMethod.label}: ${amountReceived.display}';
    final lineData = items.map((it) => InvoiceLineData(
      medicineName: it.medicineName,
      strength: it.medicineStrength,
      batchNumber: it.batchNumber,
      quantity: it.quantity,
      unitPrice: it.unitPrice.display,
      lineTotal: it.lineTotal.display,
    )).toList();

    Navigator.of(context).pop(PaymentResult(
      invoiceNumber: invoice.value,
      customerName: cart.customerName,
      customerPhone: cart.customerPhone,
      lines: lineData,
      subtotal: totals.subtotal.display,
      discount: totals.totalDiscount.display,
      grandTotal: totals.grandTotal.display,
      amountReceived: amountReceived.display,
      change: change.display,
      paymentSummary: paymentSummary,
      createdAt: now,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totals = widget.cartController.totals;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Complete Sale', style: AppTypography.sectionTitle),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer Details
                    Text('Customer Details', style: AppTypography.subtitle),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _customerNameCtrl,
                            label: 'Name (Leave blank for Walk-in)',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _customerPhoneCtrl,
                            label: 'Phone Number (Optional)',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Totals block
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          _row('Subtotal', totals.subtotal.display),
                          _row('Discount', '- ${totals.totalDiscount.display}'),
                          const Divider(),
                          _row('Grand Total', totals.grandTotal.display, emphasize: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Payment method
                    Text('Payment Method', style: AppTypography.subtitle),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: PaymentMethod.values.map((m) {
                        return ChoiceChip(
                          label: Text(m.label),
                          selected: _primaryMethod == m,
                          onSelected: (_) => setState(() => _primaryMethod = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      controller: _receivedCtrl,
                      label: _primaryMethod == PaymentMethod.credit ? 'Credit Amount (PKR)' : 'Amount Received (PKR)',
                      prefixIcon: Icons.account_balance_wallet_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Change / outstanding display
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          _row('Amount Received', 'PKR ${_totalTendered.toStringAsFixed(2)}'),
                          _row(
                            _isCreditSelected ? 'On Credit' : _isPaidInFull ? 'Change Due' : 'Short By',
                            _isCreditSelected
                                ? 'PKR ${(_grandTotalPkr - _totalTendered).clamp(0, double.infinity).toStringAsFixed(2)}'
                                : _isPaidInFull
                                ? 'PKR ${_changePkr.toStringAsFixed(2)}'
                                : 'PKR ${(_grandTotalPkr - _totalTendered).toStringAsFixed(2)}',
                            emphasize: true,
                            emphasisColor: _isPaidInFull ? AppColors.success : AppColors.warning,
                          ),
                        ],
                      ),
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
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Complete Sale',
                    icon: Icons.check_circle_rounded,
                    variant: AppButtonVariant.primary,
                    isLoading: _isProcessing,
                    onPressed: _isProcessing ? null : _process,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false, Color? emphasisColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: emphasize ? AppTypography.subtitle.copyWith(color: emphasisColor ?? AppColors.primary) : AppTypography.body),
          Text(value, style: emphasize ? AppTypography.numericLarge.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: emphasisColor ?? AppColors.primary) : AppTypography.numeric),
        ],
      ),
    );
  }
}