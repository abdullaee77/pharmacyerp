import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../data/sqlite_batch_repository.dart';
import '../../domain/batch.dart';
import '../../domain/inventory_movement.dart';
import '../controllers/inventory_controller.dart';

enum _AdjustMode { add, remove }

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
  final SqliteBatchRepository _batchRepo = SqliteBatchRepository();

  List<Batch> _batches = [];
  Batch? _selectedBatch;
  bool _loadingBatches = true;

  _AdjustMode _mode = _AdjustMode.add;
  AdjustmentReason _reason = AdjustmentReason.manualCorrection;
  bool _isSaving = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _qtyCtrl.addListener(() => setState(() => _inlineError = null));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() => _loadingBatches = true);
    final res = await _batchRepo.getBatches(
      medicineId: widget.stock.medicine.id,
    );
    res.fold(
      onSuccess: (list) {
        if (!mounted) return;
        final matched = list
            .where((b) => b.medicineId == widget.stock.medicine.id)
            .toList();
        setState(() {
          _batches = matched;
          _loadingBatches = false;
          if (matched.isNotEmpty) {
            _selectedBatch = matched.first;
          }
        });
      },
      onFailure: (_) {
        if (mounted) setState(() => _loadingBatches = false);
      },
    );
  }

  int get _currentBatchQty => _selectedBatch?.quantity.value ?? 0;

  int? get _enteredQty {
    final t = _qtyCtrl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int? get _signedDelta {
    final qty = _enteredQty;
    if (qty == null || qty <= 0) return null;

    switch (_mode) {
      case _AdjustMode.add:
        return qty;
      case _AdjustMode.remove:
        return -qty;
    }
  }

  int? get _newBalance {
    final delta = _signedDelta;
    if (delta == null) return null;
    return _currentBatchQty + delta;
  }

  String get _modeHint {
    switch (_mode) {
      case _AdjustMode.add:
        return 'How many units to add to this batch?';
      case _AdjustMode.remove:
        return 'How many units to remove from this batch?';
    }
  }

  String get _qtyLabel {
    switch (_mode) {
      case _AdjustMode.add:
        return 'Units to add';
      case _AdjustMode.remove:
        return 'Units to remove';
    }
  }

  void _setMode(_AdjustMode mode) {
    setState(() {
      _mode = mode;
      _inlineError = null;
      _qtyCtrl.clear();
    });
  }

  void _onBatchChanged(Batch? batch) {
    if (batch == null) return;
    setState(() {
      _selectedBatch = batch;
      _inlineError = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedBatch == null) {
      setState(() => _inlineError = 'Please select a batch to adjust.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final delta = _signedDelta;
    final newBal = _newBalance;

    if (delta == null || newBal == null) {
      setState(() => _inlineError = 'Enter a valid quantity greater than 0.');
      return;
    }

    if (newBal < 0) {
      setState(() => _inlineError =
      'Resulting batch quantity cannot be negative (would be $newBal).');
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    final refNote = _refCtrl.text.trim().isEmpty
        ? 'Batch: ${_selectedBatch!.batchNumber.value}'
        : '${_refCtrl.text.trim()} (Batch: ${_selectedBatch!.batchNumber.value})';

    final error = await widget.controller.adjustStock(
      medicineId: widget.stock.medicine.id,
      quantityChange: delta,
      reason: _reason,
      reference: refNote,
      operatorName: widget.operatorName,
      batchId: _selectedBatch!.id.value,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      setState(() => _inlineError = error);
      return;
    }

    Navigator.of(context).pop(true); // success only on apply
  }

  @override
  Widget build(BuildContext context) {
    final newBal = _newBalance;
    final delta = _signedDelta;
    final previewOk =
        newBal != null && newBal >= 0 && delta != null && delta != 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Stock (Batch Specific)',
                          style: AppTypography.pageTitle
                              .copyWith(color: Colors.white, fontSize: 18),
                        ),
                        Text(
                          widget.stock.medicine.name,
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Batch Selector
                      if (_loadingBatches)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        )
                      else if (_batches.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No physical batches on file for this medicine. Create a Receive Purchase invoice first.',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<Batch>(
                          value: _selectedBatch,
                          decoration: InputDecoration(
                            labelText: 'Select Target Batch *',
                            prefixIcon: const Icon(Icons.layers_outlined),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          items: _batches.map((b) {
                            return DropdownMenuItem<Batch>(
                              value: b,
                              child: Text(
                                'Batch: ${b.batchNumber.value} (Exp: ${b.expiryDate.display}, Stock: ${b.quantity.value})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: _onBatchChanged,
                        ),

                      const SizedBox(height: AppSpacing.lg),

                      // Current Batch Stock Chip
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Selected Batch Stock:',
                                style: AppTypography.bodySmall),
                            const Spacer(),
                            Text(
                              '$_currentBatchQty',
                              style: AppTypography.numeric.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('units', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      Text('Adjustment Type', style: AppTypography.subtitle),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _ModeChip(
                              selected: _mode == _AdjustMode.add,
                              icon: Icons.add_circle_outline_rounded,
                              label: 'Increase',
                              color: AppColors.success,
                              onTap: () => _setMode(_AdjustMode.add),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ModeChip(
                              selected: _mode == _AdjustMode.remove,
                              icon: Icons.remove_circle_outline_rounded,
                              label: 'Decrease',
                              color: AppColors.error,
                              onTap: () => _setMode(_AdjustMode.remove),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(_modeHint, style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.sm),

                      TextFormField(
                        controller: _qtyCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AppTypography.numeric.copyWith(fontSize: 20),
                        decoration: InputDecoration(
                          labelText: _qtyLabel,
                          hintText: 'e.g. 5',
                          prefixIcon: Icon(
                            _mode == _AdjustMode.add
                                ? Icons.add_rounded
                                : Icons.remove_rounded,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Quantity required';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null) return 'Enter a whole number';
                          if (n <= 0) return 'Must be greater than 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Live preview card
                      _PreviewCard(
                        current: _currentBatchQty,
                        newBalance: newBal,
                        delta: delta,
                        isValid: previewOk,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      DropdownButtonFormField<AdjustmentReason>(
                        value: _reason,
                        decoration: InputDecoration(
                          labelText: 'Adjustment Reason',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
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
                              () => _reason =
                              v ?? AdjustmentReason.manualCorrection,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      TextFormField(
                        controller: _refCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Audit Note (optional)',
                          hintText:
                          'e.g. Physical count correction, broken bottle write-off...',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      ),

                      if (_inlineError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 18, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _inlineError!,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.error),
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
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Apply Adjustment',
                    icon: Icons.check_rounded,
                    variant: _mode == _AdjustMode.remove
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    isLoading: _isSaving,
                    onPressed: (_isSaving || _batches.isEmpty) ? null : _submit,
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

class _ModeChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.12) : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22, color: selected ? color : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final int current;
  final int? newBalance;
  final int? delta;
  final bool isValid;

  const _PreviewCard({
    required this.current,
    required this.newBalance,
    required this.delta,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    final show = newBalance != null && delta != null;
    final negative = newBalance != null && newBalance! < 0;
    final noChange = delta == 0;

    Color borderColor = AppColors.border;
    Color bg = AppColors.surfaceVariant;
    if (show && isValid) {
      borderColor = delta! > 0 ? AppColors.success : AppColors.warning;
      bg = (delta! > 0 ? AppColors.success : AppColors.warning)
          .withOpacity(0.08);
    } else if (negative || noChange) {
      borderColor = AppColors.error.withOpacity(0.5);
      bg = AppColors.error.withOpacity(0.06);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _PreviewCol(title: 'BEFORE', value: '$current'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          _PreviewCol(
            title: 'AFTER',
            value: show ? '$newBalance' : '—',
            highlight: isValid,
            danger: negative,
          ),
          const Spacer(),
          if (show && !noChange)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (delta! >= 0 ? AppColors.success : AppColors.error)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                delta! >= 0 ? '+$delta' : '$delta',
                style: AppTypography.numeric.copyWith(
                  fontWeight: FontWeight.w800,
                  color: delta! >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewCol extends StatelessWidget {
  final String title;
  final String value;
  final bool highlight;
  final bool danger;

  const _PreviewCol({
    required this.title,
    required this.value,
    this.highlight = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.caption),
        Text(
          value,
          style: AppTypography.numeric.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: danger
                ? AppColors.error
                : highlight
                ? AppColors.primary
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}