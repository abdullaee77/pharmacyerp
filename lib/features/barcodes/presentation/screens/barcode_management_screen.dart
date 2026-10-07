import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/medicine.dart';
import '../../domain/barcode_label.dart';
import '../controllers/barcode_controller.dart';
import '../widgets/barcode_painter.dart';
import '../widgets/barcode_scan_dialog.dart';

/// Barcode Management workspace: assign, generate, preview, and prepare prints.
class BarcodeManagementScreen extends StatefulWidget {
  final BarcodeController controller;

  const BarcodeManagementScreen({super.key, required this.controller});

  @override
  State<BarcodeManagementScreen> createState() => _BarcodeManagementScreenState();
}

class _BarcodeManagementScreenState extends State<BarcodeManagementScreen> {
  final _assignCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadMedicines();
    });
  }

  @override
  void dispose() {
    _assignCtrl.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    await showDialog(
      context: context,
      builder: (ctx) => BarcodeScanDialog(controller: widget.controller),
    );
  }

  Future<void> _generateAndAssign(Medicine medicine) async {
    final newCode = widget.controller.generateNewBarcode();
    final error = await widget.controller.assignBarcode(medicine.id, newCode);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Barcode generated and assigned: $newCode');
    }
  }

  Future<void> _manualAssign(Medicine medicine) async {
    _assignCtrl.text = medicine.barcode?.value ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Barcode', style: AppTypography.sectionTitle),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medicine.name, style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _assignCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_assignCtrl.text.trim()),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final error = await widget.controller.assignBarcode(medicine.id, result);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Barcode assigned successfully.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barcode Management', style: AppTypography.pageTitle),
                    Text(
                      'Assign, generate and preview medicine barcodes.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  label: 'Scan Barcode',
                  icon: Icons.qr_code_scanner_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _openScanner,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Medicine list
                  Expanded(flex: 3, child: _buildMedicineList(ctrl)),
                  const SizedBox(width: AppSpacing.lg),
                  // Right: Barcode preview panel
                  Expanded(flex: 2, child: _buildPreviewPanel(ctrl)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMedicineList(BarcodeController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(type: AppLoadingType.spinner, message: 'Loading medicines...');
    }
    if (ctrl.medicines.isEmpty) {
      return const AppEmptyState(
        icon: Icons.medication_outlined,
        title: 'No medicines registered',
        subtitle: 'Add medicines first before managing barcodes.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ListView.separated(
          itemCount: ctrl.medicines.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final m = ctrl.medicines[i];
            final isSelected = ctrl.selectedMedicine?.id == m.id;
            final hasBarcode = m.barcode != null;

            return InkWell(
              onTap: () => ctrl.selectMedicine(m),
              child: Container(
                color: isSelected ? AppColors.primarySurface : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: AppTypography.subtitle.copyWith(fontSize: 14)),
                          Text(
                            '${m.strength} — ${m.dosageForm.label}',
                            style: AppTypography.caption,
                          ),
                          const SizedBox(height: 2),
                          if (hasBarcode)
                            Text(
                              m.barcode!.value,
                              style: AppTypography.numericSmall.copyWith(color: AppColors.primary),
                            )
                          else
                            Text(
                              'No barcode assigned',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        AppBadge(
                          label: hasBarcode ? 'Assigned' : 'Not Set',
                          variant: hasBarcode ? AppBadgeVariant.success : AppBadgeVariant.warning,
                          isDot: true,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                              tooltip: 'Generate new barcode',
                              splashRadius: 16,
                              onPressed: () => _generateAndAssign(m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Assign manually',
                              splashRadius: 16,
                              onPressed: () => _manualAssign(m),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(BarcodeController ctrl) {
    final label = ctrl.activeLabel;

    if (label == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: const AppEmptyState(
          icon: Icons.qr_code_2_outlined,
          title: 'Select a medicine',
          subtitle: 'Pick a product on the left to preview its barcode label.',
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label Preview', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),

            // Preview label
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.borderDark, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label.includeName)
                      Text(
                        label.medicineName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    if (label.strength != null)
                      Text(
                        label.strength!,
                        style: const TextStyle(fontSize: 9, color: Colors.black87),
                      ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 180,
                      height: 50,
                      child: CustomPaint(
                        painter: BarcodePainter(data: label.barcode),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.barcode,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        letterSpacing: 2,
                      ),
                    ),
                    if (label.includePrice) ...[
                      const SizedBox(height: 2),
                      Text(
                        label.price,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Settings
            Text('Print Settings', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<LabelSize>(
              value: label.size,
              decoration: const InputDecoration(labelText: 'Label Size', isDense: true),
              items: LabelSize.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) ctrl.updateLabel(label.copyWith(size: v));
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: label.includeName,
              onChanged: (v) => ctrl.updateLabel(label.copyWith(includeName: v)),
              title: Text('Include Medicine Name', style: AppTypography.bodySmall),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: label.includePrice,
              onChanged: (v) => ctrl.updateLabel(label.copyWith(includePrice: v)),
              title: Text('Include Price', style: AppTypography.bodySmall),
            ),

            const Spacer(),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Print Preview',
                    icon: Icons.print_outlined,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      AppToast.info(context, 'Printer integration will be available in a future phase.');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}