import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/medicine.dart';
import '../controllers/barcode_controller.dart';

/// Scanner-first dialog for barcode-driven medicine lookup.
///
/// Supports both USB barcode scanner input (treated as keyboard) and
/// manual entry with Enter-to-submit behavior.
class BarcodeScanDialog extends StatefulWidget {
  final BarcodeController controller;

  const BarcodeScanDialog({super.key, required this.controller});

  @override
  State<BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<BarcodeScanDialog> {
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Medicine? _foundMedicine;
  String? _notFoundCode;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundMedicine = null;
      _notFoundCode = null;
    });

    final result = await widget.controller.scanBarcode(code);

    setState(() {
      _isSearching = false;
      if (result != null) {
        _foundMedicine = result;
      } else {
        _notFoundCode = code;
      }
    });
  }

  void _reset() {
    setState(() {
      _foundMedicine = null;
      _notFoundCode = null;
      _codeCtrl.clear();
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan Barcode', style: AppTypography.sectionTitle),
                        Text(
                          'Scan with USB scanner or type barcode manually',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _codeCtrl,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  hintText: 'Scan or type and press Enter',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  suffixIcon: _isSearching
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : IconButton(
                    icon: const Icon(Icons.search_rounded, size: 18),
                    onPressed: _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_foundMedicine != null) _buildFoundCard(_foundMedicine!),
              if (_notFoundCode != null) _buildNotFoundCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoundCard(Medicine m) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Medicine Found', style: AppTypography.subtitle.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(m.name, style: AppTypography.subtitle),
          Text(
            '${m.genericName} ${m.strength} — ${m.dosageForm.label}',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Price: ${m.sellingPrice.display}',
            style: AppTypography.numeric.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppButton(
                label: 'Scan Another',
                variant: AppButtonVariant.outlined,
                size: AppButtonSize.small,
                onPressed: _reset,
              ),
              const Spacer(),
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search_off_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Not Found', style: AppTypography.subtitle.copyWith(color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No medicine is assigned to barcode "$_notFoundCode". You can assign this barcode from the Barcode Management screen.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Try Again',
            variant: AppButtonVariant.outlined,
            size: AppButtonSize.small,
            onPressed: _reset,
          ),
        ],
      ),
    );
  }
}