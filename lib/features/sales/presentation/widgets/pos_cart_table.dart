import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/cart_item.dart';
import '../controllers/pos_cart_controller.dart';
import 'batch_picker_dialog.dart';

/// Main POS cart table with inline editing.
class PosCartTable extends StatelessWidget {
  final PosCartController controller;

  const PosCartTable({super.key, required this.controller});

  Future<void> _changeBatch(BuildContext context, CartItem item) async {
    final batches = await controller.loadBatches(item.medicine.id);
    if (batches.isEmpty || !context.mounted) return;

    final selected = await showDialog(
      context: context,
      builder: (ctx) => BatchPickerDialog(
        medicine: item.medicine,
        batches: batches,
        currentBatchId: item.batch.id,
      ),
    );

    if (selected != null) {
      controller.changeBatch(item.id, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: const AppEmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Cart is empty',
          subtitle:
          'Scan a barcode or search for a medicine to add it to the cart.',
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                _headerCell('Medicine', flex: 4),
                _headerCell('Batch', flex: 2),
                _headerCell('Qty', flex: 1, align: TextAlign.center),
                _headerCell('Price', flex: 2, align: TextAlign.right),
                _headerCell('Disc %', flex: 1, align: TextAlign.center),
                _headerCell('Total', flex: 2, align: TextAlign.right),
                const SizedBox(width: 40),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: ListView.separated(
              itemCount: controller.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = controller.items[i];
                return _CartRow(
                  item: item,
                  controller: controller,
                  onChangeBatch: () => _changeBatch(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: AppTypography.tableHeader,
      ),
    );
  }
}

class _CartRow extends StatefulWidget {
  final CartItem item;
  final PosCartController controller;
  final VoidCallback onChangeBatch;

  const _CartRow({
    required this.item,
    required this.controller,
    required this.onChangeBatch,
  });

  @override
  State<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends State<_CartRow> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _discCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.item.quantity}');
    _discCtrl = TextEditingController(text: '${widget.item.discountPercent}');
  }

  @override
  void didUpdateWidget(covariant _CartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _qtyCtrl.text = '${widget.item.quantity}';
    }
    if (oldWidget.item.discountPercent != widget.item.discountPercent) {
      _discCtrl.text = '${widget.item.discountPercent}';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Medicine
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicine.name,
                  style: AppTypography.subtitle.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.medicine.strength} — ${item.medicine.dosageForm.label}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),

          // Batch (clickable)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: widget.onChangeBatch,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.batch.batchNumber.value,
                      style: AppTypography.numericSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Exp ${item.batch.expiryDate.display}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quantity (editable)
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _qtyCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: AppTypography.numeric,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                ),
                onSubmitted: (v) {
                  final n = int.tryParse(v);
                  if (n != null) widget.controller.updateQuantity(item.id, n);
                },
                onEditingComplete: () {
                  final n = int.tryParse(_qtyCtrl.text);
                  if (n != null) widget.controller.updateQuantity(item.id, n);
                },
              ),
            ),
          ),

          // Price
          Expanded(
            flex: 2,
            child: Text(
              item.unitPrice.display,
              textAlign: TextAlign.right,
              style: AppTypography.numericSmall,
            ),
          ),

          // Discount %
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _discCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: AppTypography.numeric,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                ),
                onSubmitted: (v) {
                  final n = int.tryParse(v);
                  if (n != null) widget.controller.updateDiscount(item.id, n);
                },
                onEditingComplete: () {
                  final n = int.tryParse(_discCtrl.text);
                  if (n != null) widget.controller.updateDiscount(item.id, n);
                },
              ),
            ),
          ),

          // Line total
          Expanded(
            flex: 2,
            child: Text(
              item.lineTotal.display,
              textAlign: TextAlign.right,
              style: AppTypography.numeric.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),

          // Remove
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.error),
              tooltip: 'Remove line',
              splashRadius: 14,
              onPressed: () => widget.controller.removeLine(item.id),
            ),
          ),
        ],
      ),
    );
  }
}