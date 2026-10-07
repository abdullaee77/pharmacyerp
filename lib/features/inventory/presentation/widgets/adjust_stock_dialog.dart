import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../controllers/inventory_controller.dart';
import '../../domain/inventory_movement.dart';

/// Wizard dialog facilitating manual balance modifications.
class AdjustStockDialog extends StatefulWidget {
  final InventoryController controller;
  final InventoryStock stock;
  final String operatorName;

  const AdjustStockDialog({
    super.key,
    required this.controller,
    required this.stock,
    required this.operatorName,
  });

  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  bool _isAddition = true; // Toggle direction context
  AdjustmentReason _reason = AdjustmentReason.manualCorrection;
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final qtyChange = int.parse(_qtyCtrl.text.trim());
    final signedChange = _isAddition ? qtyChange : -qtyChange;

    final error = await widget.controller.adjustStock(
      medicineId: widget.stock.medicine.id,
      quantityChange: signedChange,
      reason: _reason,
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      operatorName: widget.operatorName,
    );

    setState(() => _isSaving = false);

    if (error != null && mounted) {
      Navigator.of(context).pop(error);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Manual Stock Adjustment',
                    style: AppTypography.sectionTitle,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Group Form Elements
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.stock.medicine.name,
                      style: AppTypography.subtitle,
                    ),
                    Text(
                      'Current Balance: ${widget.stock.currentStock.value} Units',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Direction Selector
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _isAddition = true),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _isAddition
                                  ? AppColors.successSurface
                                  : null,
                              side: BorderSide(
                                color: _isAddition
                                    ? AppColors.success
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Increase',
                                  style: TextStyle(
                                    color: _isAddition
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _isAddition = false),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: !_isAddition
                                  ? AppColors.errorSurface
                                  : null,
                              side: BorderSide(
                                color: !_isAddition
                                    ? AppColors.error
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.remove_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Decrease',
                                  style: TextStyle(
                                    color: !_isAddition
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Quantity Entry
                    AppTextField(
                      controller: _qtyCtrl,
                      label: 'Adjustment Quantity',
                      hint: 'Enter absolute quantity unit value',
                      prefixIcon: Icons.unfold_more_rounded,
                      isRequired: true,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Value required';
                        final numVal = int.tryParse(v);
                        if (numVal == null || numVal <= 0)
                          return 'Must be positive integer';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Reason Dropdown
                    DropdownButtonFormField<AdjustmentReason>(
                      value: _reason,
                      decoration: const InputDecoration(
                        labelText: 'Adjustment Reason',
                      ),
                      items: AdjustmentReason.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _reason = v ?? AdjustmentReason.manualCorrection,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Notes / Reference Field
                    AppTextField(
                      controller: _refCtrl,
                      label: 'Audit Reference Note',
                      hint:
                          'e.g. Audit ledger corrections, batch damage ref...',
                      prefixIcon: Icons.notes_rounded,
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
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
                    label: 'Apply Adjustment',
                    variant: _isAddition
                        ? AppButtonVariant.success
                        : AppButtonVariant.danger,
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
