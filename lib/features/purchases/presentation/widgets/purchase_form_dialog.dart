import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/purchase.dart';
import '../controllers/purchase_controller.dart';

class PurchaseFormDialog extends StatefulWidget {
  final PurchaseController controller;

  const PurchaseFormDialog({super.key, required this.controller});

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController(text: 'General Supplier Ltd');
  final _medNameCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _purPriceCtrl = TextEditingController();
  final _selPriceCtrl = TextEditingController();

  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _medNameCtrl.dispose();
    _batchCtrl.dispose();
    _qtyCtrl.dispose();
    _purPriceCtrl.dispose();
    _selPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final medicineName = _medNameCtrl.text.trim();
    final batchNum = _batchCtrl.text.trim();
    final qty = int.parse(_qtyCtrl.text.trim());
    final purchasePrice = Money.fromPkr(
      double.parse(_purPriceCtrl.text.trim()),
    );
    final sellingPrice = Money.fromPkr(double.parse(_selPriceCtrl.text.trim()));

    final pId = PurchaseId.generate();
    final invNum = PurchaseInvoiceNumber.generate();
    final now = DateTime.now();

    final item = PurchaseItem(
      id: 'p_item_${DateTime.now().microsecondsSinceEpoch}',
      medicineId:
          MedicineId.generate(), // Auto-creates dummy container ID for new procurement batch
      medicineName: medicineName,
      batchNumber: batchNum,
      expiryDate: _expiryDate,
      quantity: qty,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      lineTotal: Money.fromPaisa(purchasePrice.paisa * qty),
    );

    final purchase = Purchase(
      id: pId,
      invoiceNumber: invNum,
      supplierName: _supplierCtrl.text.trim(),
      items: [item],
      subtotal: item.lineTotal,
      discount: Money.zero(),
      grandTotal: item.lineTotal,
      createdAt: now,
      updatedAt: now,
    );

    final error = await widget.controller.receivePurchase(purchase);

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
                  const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Receive Stock Purchase',
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _supplierCtrl,
                        label: 'Supplier Name',
                        isRequired: true,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _medNameCtrl,
                        label: 'Product Name',
                        hint: 'e.g. Augmentin 375mg Tab',
                        isRequired: true,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _batchCtrl,
                        label: 'Batch Number',
                        hint: 'e.g. BN-2024-1002',
                        isRequired: true,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickExpiry,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expiry Date',
                                ),
                                child: Text(
                                  '${_expiryDate.day.toString().padLeft(2, '0')}/${_expiryDate.month.toString().padLeft(2, '0')}/${_expiryDate.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _qtyCtrl,
                              label: 'Procured Units',
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (int.tryParse(v) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _purPriceCtrl,
                              label: 'Purchase Cost (PKR)',
                              isRequired: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) =>
                                  v == null || double.tryParse(v) == null
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _selPriceCtrl,
                              label: 'Dispense Price (PKR)',
                              isRequired: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Receive stock',
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
