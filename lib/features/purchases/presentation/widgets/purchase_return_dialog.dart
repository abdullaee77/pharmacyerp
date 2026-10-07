import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_return.dart';
import '../controllers/purchase_controller.dart';

class PurchaseReturnDialog extends StatefulWidget {
  final Purchase purchase;
  final PurchaseController controller;
  final String operatorName;

  const PurchaseReturnDialog({
    super.key,
    required this.purchase,
    required this.controller,
    required this.operatorName,
  });

  @override
  State<PurchaseReturnDialog> createState() => _PurchaseReturnDialogState();
}

class _PurchaseReturnDialogState extends State<PurchaseReturnDialog> {
  final Map<String, int> _returnQty = {};
  final Map<String, int> _alreadyReturned = {};
  final _notesCtrl = TextEditingController();
  PurchaseReturnReason _reason = PurchaseReturnReason.damaged;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    for (final item in widget.purchase.items) {
      _returnQty[item.id] = 0;
    }
    _loadReturnedCounts();
  }

  Future<void> _loadReturnedCounts() async {
    final map = await widget.controller.loadReturnedQuantities(
      widget.purchase.id,
    );
    setState(() {
      _alreadyReturned.addAll(map);
      _isLoading = false;
    });
  }

  int _remainingFor(PurchaseItem item) =>
      item.quantity - (_alreadyReturned[item.id] ?? 0);

  Money get _totalRefund {
    int paisa = 0;
    for (final item in widget.purchase.items) {
      final qty = _returnQty[item.id] ?? 0;
      if (qty > 0) {
        paisa += item.purchasePrice.paisa * qty;
      }
    }
    return Money.fromPaisa(paisa);
  }

  bool get _hasAnyReturn => _returnQty.values.any((q) => q > 0);

  Future<void> _submit() async {
    if (!_hasAnyReturn) {
      AppToast.warning(
        context,
        'Set return quantities on at least one item line.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final items = <PurchaseReturnItem>[];
    for (final item in widget.purchase.items) {
      final qty = _returnQty[item.id] ?? 0;
      if (qty <= 0) continue;
      items.add(
        PurchaseReturnItem(
          id: 'pri_${DateTime.now().microsecondsSinceEpoch}_${item.id}',
          originalPurchaseItemId: item.id,
          medicineId: item.medicineId,
          medicineName: item.medicineName,
          batchNumber: item.batchNumber,
          quantity: qty,
          refundAmount: Money.fromPaisa(item.purchasePrice.paisa * qty),
        ),
      );
    }

    final returnDoc = PurchaseReturn(
      id: PurchaseReturnId.generate(),
      originalPurchaseId: widget.purchase.id,
      originalInvoiceNumber: widget.purchase.invoiceNumber.value,
      supplierName: widget.purchase.supplierName,
      items: items,
      reason: _reason,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      totalRefund: _totalRefund,
      operatorName: widget.operatorName,
      createdAt: DateTime.now(),
    );

    final error = await widget.controller.createReturn(
      originalPurchase: widget.purchase,
      returnDoc: returnDoc,
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
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_return_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supplier Purchase Return',
                        style: AppTypography.sectionTitle,
                      ),
                      Text(
                        'Original Proc Invoice: ${widget.purchase.invoiceNumber.value}',
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

            Expanded(
              child: _isLoading
                  ? const AppLoading()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              children: widget.purchase.items.map((item) {
                                final remaining = _remainingFor(item);
                                final current = _returnQty[item.id] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.medicineName,
                                              style: AppTypography.subtitle
                                                  .copyWith(fontSize: 13),
                                            ),
                                            Text(
                                              'Batch: ${item.batchNumber}  ·  Original Qty: ${item.quantity}',
                                              style: AppTypography.caption,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Returnable: $remaining',
                                        style: AppTypography.caption,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      SizedBox(
                                        width: 90,
                                        child: TextField(
                                          enabled: remaining > 0,
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                            hintText: '0',
                                          ),
                                          controller: TextEditingController(
                                            text: current == 0
                                                ? ''
                                                : '$current',
                                          ),
                                          onChanged: (v) {
                                            final n = int.tryParse(v) ?? 0;
                                            setState(() {
                                              _returnQty[item.id] = n.clamp(
                                                0,
                                                remaining,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          DropdownButtonFormField<PurchaseReturnReason>(
                            value: _reason,
                            decoration: const InputDecoration(
                              labelText: 'Return Reason',
                            ),
                            items: PurchaseReturnReason.values
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(
                              () => _reason = v ?? PurchaseReturnReason.damaged,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _notesCtrl,
                            label: 'Return adjustment notes',
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Refund Credit Amount',
                                  style: AppTypography.subtitle.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  _totalRefund.display,
                                  style: AppTypography.numericLarge.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
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
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Complete Return',
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
