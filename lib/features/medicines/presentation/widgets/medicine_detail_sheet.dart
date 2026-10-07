import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/medicine.dart';

class MedicineDetailSheet extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onEdit;

  const MedicineDetailSheet({
    super.key,
    required this.medicine,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(medicine.name, style: AppTypography.sectionTitle),
                        Text(
                          '${medicine.genericName} ${medicine.strength} — ${medicine.dosageForm.label}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    variant: AppButtonVariant.outlined,
                    size: AppButtonSize.small,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection('Basic Information', [
                      _DetailRow('Medicine Name', medicine.name),
                      _DetailRow('Generic / Salt', medicine.genericName),
                      _DetailRow('Manufacturer', medicine.manufacturer),
                      _DetailRow('Dosage Form', medicine.dosageForm.label),
                      _DetailRow('Strength', medicine.strength),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailSection('Classification', [
                      _DetailRow('Category', medicine.category),
                      _DetailRow('Prescription', medicine.prescriptionRequired ? 'Required (Rx)' : 'OTC'),
                      _DetailRow('Status', medicine.status.label, badge: AppBadge(
                        label: medicine.status.label,
                        variant: medicine.status == MedicineStatus.active ? AppBadgeVariant.success : AppBadgeVariant.neutral,
                        isDot: true,
                      )),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailSection('Pricing (Per Piece)', [
                      _DetailRow('Purchase Price', medicine.purchasePrice.display),
                      _DetailRow('Selling Price', medicine.sellingPrice.display),
                      _DetailRow('MRP', medicine.mrp.display),
                      _DetailRow('Profit / Unit', medicine.profitPerUnit.display),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailSection('Inventory & Packaging', [
                      _DetailRow('Barcode', medicine.barcode?.value ?? 'Not assigned'),
                      _DetailRow('Pack Size (Box)', '${medicine.packSize} pieces'),
                      _DetailRow('Box Price', medicine.boxPrice.display),
                      _DetailRow('Min Stock Level', '${medicine.minStockLevel.value} units'),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _DetailSection(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.subtitle.copyWith(color: AppColors.primary)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? badge;
  const _DetailRow(this.label, this.value, {this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600))),
          if (badge != null) badge! else Expanded(child: Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}