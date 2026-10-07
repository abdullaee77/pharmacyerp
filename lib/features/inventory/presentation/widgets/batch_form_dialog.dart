import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/batch.dart';
import '../controllers/batch_controller.dart';

/// Add / Edit batch form dialog.
class BatchFormDialog extends StatefulWidget {
  final BatchController controller;
  final Batch? existingBatch;

  const BatchFormDialog({
    super.key,
    required this.controller,
    this.existingBatch,
  });

  @override
  State<BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends State<BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _batchNoCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _sellingCtrl;
  late final TextEditingController _medicineIdCtrl;
  late final TextEditingController _medicineNameCtrl;

  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

  bool get _isEditing => widget.existingBatch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBatch;
    _batchNoCtrl = TextEditingController(text: b?.batchNumber.value ?? '');
    _qtyCtrl = TextEditingController(
      text: b != null ? '${b.quantity.value}' : '',
    );
    _purchaseCtrl = TextEditingController(
      text: b != null ? b.purchasePrice.pkr.toStringAsFixed(2) : '0.00',
    );
    _sellingCtrl = TextEditingController(
      text: b != null ? b.sellingPrice.pkr.toStringAsFixed(2) : '0.00',
    );
    _medicineIdCtrl = TextEditingController(text: b?.medicineId.value ?? '');
    _medicineNameCtrl = TextEditingController(text: b?.medicineName ?? '');
    if (b != null) _expiryDate = b.expiryDate.date;
  }

  @override
  void dispose() {
    _batchNoCtrl.dispose();
    _qtyCtrl.dispose();
    _purchaseCtrl.dispose();
    _sellingCtrl.dispose();
    _medicineIdCtrl.dispose();
    _medicineNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final medicineId = _medicineIdCtrl.text.trim().isEmpty
        ? MedicineId.generate()
        : MedicineId(_medicineIdCtrl.text.trim());

    final batch = Batch(
      id: _isEditing ? widget.existingBatch!.id : BatchId.generate(),
      medicineId: _isEditing ? widget.existingBatch!.medicineId : medicineId,
      medicineName: _medicineNameCtrl.text.trim(),
      batchNumber: BatchNumber.unsafe(_batchNoCtrl.text.trim()),
      expiryDate: ExpiryDate(_expiryDate),
      quantity: Quantity.create(int.tryParse(_qtyCtrl.text) ?? 0),
      purchasePrice: Money.fromPkr(double.tryParse(_purchaseCtrl.text) ?? 0),
      sellingPrice: Money.fromPkr(double.tryParse(_sellingCtrl.text) ?? 0),
      status: Batch.deriveStatus(ExpiryDate(_expiryDate)),
      createdAt: widget.existingBatch?.createdAt ?? now,
      updatedAt: now,
    );

    String? error;
    if (_isEditing) {
      error = await widget.controller.updateBatch(batch);
    } else {
      error = await widget.controller.createBatch(batch);
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(error);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEditing ? 'Edit Batch' : 'Register New Batch',
                    style: AppTypography.sectionTitle,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEditing) ...[
                      AppTextField(
                        controller: _medicineNameCtrl,
                        label: 'Medicine Name',
                        hint: 'e.g. Panadol 500mg',
                        isRequired: true,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    AppTextField(
                      controller: _batchNoCtrl,
                      label: 'Batch Number',
                      hint: 'e.g. BN-2024-0892',
                      prefixIcon: Icons.tag_rounded,
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
                                prefixIcon: Icon(Icons.event_rounded),
                              ),
                              child: Text(
                                '${_expiryDate.day.toString().padLeft(2, '0')}/'
                                '${_expiryDate.month.toString().padLeft(2, '0')}/'
                                '${_expiryDate.year}',
                                style: AppTypography.body,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _qtyCtrl,
                            label: 'Quantity',
                            hint: '0',
                            keyboardType: TextInputType.number,
                            isRequired: true,
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
                            controller: _purchaseCtrl,
                            label: 'Purchase Price (PKR)',
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _sellingCtrl,
                            label: 'Selling Price (PKR)',
                            hint: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
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
                    label: _isEditing ? 'Save Changes' : 'Register Batch',
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
