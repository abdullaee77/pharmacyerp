// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../core/theme/app_spacing.dart';
// import '../../../../core/theme/app_radius.dart';
// import '../../../../core/theme/app_typography.dart';
// import '../../../../core/widgets/components.dart';
// import '../../domain/cart_item.dart';
// import '../controllers/pos_cart_controller.dart';
// import 'batch_picker_dialog.dart';
//
// /// Main POS cart table with inline editing.
// class PosCartTable extends StatelessWidget {
//   final PosCartController controller;
//
//   const PosCartTable({super.key, required this.controller});
//
//   Future<void> _changeBatch(BuildContext context, CartItem item) async {
//     final batches = await controller.loadBatches(item.medicine.id);
//     if (batches.isEmpty || !context.mounted) return;
//
//     final selected = await showDialog(
//       context: context,
//       builder: (ctx) => BatchPickerDialog(
//         medicine: item.medicine,
//         batches: batches,
//         currentBatchId: item.batch.id,
//       ),
//     );
//
//     if (selected != null) {
//       controller.changeBatch(item.id, selected);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (controller.isEmpty) {
//       return Container(
//         decoration: BoxDecoration(
//           color: AppColors.surface,
//           borderRadius: BorderRadius.circular(AppRadius.lg),
//           border: Border.all(color: AppColors.border),
//         ),
//         child: const AppEmptyState(
//           icon: Icons.shopping_cart_outlined,
//           title: 'Cart is empty',
//           subtitle:
//           'Scan a barcode or search for a medicine to add it to the cart.',
//         ),
//       );
//     }
//
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.lg),
//         border: Border.all(color: AppColors.border),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         children: [
//           // Table header
//           Container(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppSpacing.md,
//               vertical: AppSpacing.sm,
//             ),
//             decoration: BoxDecoration(
//               color: AppColors.surfaceVariant,
//               border: Border(
//                 bottom: BorderSide(color: AppColors.border),
//               ),
//             ),
//             child: Row(
//               children: [
//                 _headerCell('Medicine', flex: 4),
//                 _headerCell('Batch', flex: 2),
//                 _headerCell('Qty', flex: 1, align: TextAlign.center),
//                 _headerCell('Price', flex: 2, align: TextAlign.right),
//                 _headerCell('Disc %', flex: 2, align: TextAlign.center),
//                 _headerCell('Disc Amt', flex: 2, align: TextAlign.center),
//                 _headerCell('Total', flex: 2, align: TextAlign.right),
//                 const SizedBox(width: 40),
//               ],
//             ),
//           ),
//
//           // Items list
//           Expanded(
//             child: ListView.separated(
//               itemCount: controller.items.length,
//               separatorBuilder: (_, __) => const Divider(height: 1),
//               itemBuilder: (ctx, i) {
//                 final item = controller.items[i];
//                 return _CartRow(
//                   key: ValueKey(item.id.value),
//                   item: item,
//                   controller: controller,
//                   onChangeBatch: () => _changeBatch(context, item),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _headerCell(String label,
//       {int flex = 1, TextAlign align = TextAlign.left}) {
//     return Expanded(
//       flex: flex,
//       child: Text(
//         label,
//         textAlign: align,
//         style: AppTypography.tableHeader,
//       ),
//     );
//   }
// }
//
// class _CartRow extends StatefulWidget {
//   final CartItem item;
//   final PosCartController controller;
//   final VoidCallback onChangeBatch;
//
//   const _CartRow({
//     super.key,
//     required this.item,
//     required this.controller,
//     required this.onChangeBatch,
//   });
//
//   @override
//   State<_CartRow> createState() => _CartRowState();
// }
//
// class _CartRowState extends State<_CartRow> {
//   late final TextEditingController _qtyCtrl;
//   late final TextEditingController _pctCtrl;
//   late final TextEditingController _amtCtrl;
//
//   final FocusNode _qtyFocus = FocusNode();
//   final FocusNode _pctFocus = FocusNode();
//   final FocusNode _amtFocus = FocusNode();
//
//   static String _fmtPct(double v) {
//     if (v == 0) return '0';
//     return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
//   }
//
//   static String _fmtAmt(int paisa) => (paisa / 100).toStringAsFixed(2);
//
//   @override
//   void initState() {
//     super.initState();
//     _qtyCtrl = TextEditingController(text: '${widget.item.quantity}');
//     _pctCtrl =
//         TextEditingController(text: _fmtPct(widget.item.discountPercent));
//     _amtCtrl = TextEditingController(
//         text: _fmtAmt(widget.item.discountAmount.paisa));
//
//     // Save / normalize when a field loses focus (click away).
//     _qtyFocus.addListener(() {
//       if (!_qtyFocus.hasFocus) _commitQty();
//     });
//     _pctFocus.addListener(() {
//       if (!_pctFocus.hasFocus) _syncDiscountTexts(force: true);
//     });
//     _amtFocus.addListener(() {
//       if (!_amtFocus.hasFocus) _syncDiscountTexts(force: true);
//     });
//   }
//
//   @override
//   void didUpdateWidget(covariant _CartRow oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.item.quantity != widget.item.quantity &&
//         !_qtyFocus.hasFocus) {
//       _qtyCtrl.text = '${widget.item.quantity}';
//     }
//     _syncDiscountTexts();
//   }
//
//   /// Updates the discount text boxes from the model.
//   /// The box being typed in is left alone (unless [force]).
//   void _syncDiscountTexts({bool force = false}) {
//     final item = widget.item;
//     if (force || !_pctFocus.hasFocus) {
//       final t = _fmtPct(item.discountPercent);
//       if (_pctCtrl.text != t) _pctCtrl.text = t;
//     }
//     if (force || !_amtFocus.hasFocus) {
//       final t = _fmtAmt(item.discountAmount.paisa);
//       if (_amtCtrl.text != t) _amtCtrl.text = t;
//     }
//   }
//
//   void _commitQty() {
//     final n = int.tryParse(_qtyCtrl.text.trim());
//     if (n != null) {
//       widget.controller.updateQuantity(widget.item.id, n);
//     }
//     // Reset text to the real value (handles invalid / rejected input).
//     if (mounted) _qtyCtrl.text = '${widget.item.quantity}';
//   }
//
//   void _onPercentChanged(String text) {
//     final pct = double.tryParse(text.trim()) ?? 0;
//     widget.controller.updateDiscountPercent(widget.item.id, pct);
//     // amount box refreshes automatically through didUpdateWidget
//   }
//
//   void _onAmountChanged(String text) {
//     final rupees = double.tryParse(text.trim()) ?? 0;
//     final paisa = (rupees * 100).round();
//     widget.controller.updateDiscountAmount(widget.item.id, paisa);
//     // percent box refreshes automatically through didUpdateWidget
//   }
//
//   @override
//   void dispose() {
//     _qtyCtrl.dispose();
//     _pctCtrl.dispose();
//     _amtCtrl.dispose();
//     _qtyFocus.dispose();
//     _pctFocus.dispose();
//     _amtFocus.dispose();
//     super.dispose();
//   }
//
//   InputDecoration _fieldDecoration({String? suffix}) => InputDecoration(
//     isDense: true,
//     suffixText: suffix,
//     contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
//   );
//
//   @override
//   Widget build(BuildContext context) {
//     final item = widget.item;
//     return Container(
//       padding: const EdgeInsets.symmetric(
//         horizontal: AppSpacing.md,
//         vertical: AppSpacing.sm,
//       ),
//       child: Row(
//         children: [
//           // Medicine
//           Expanded(
//             flex: 4,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   item.medicine.name,
//                   style: AppTypography.subtitle.copyWith(fontSize: 13),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 Text(
//                   '${item.medicine.strength} — ${item.medicine.dosageForm.label}',
//                   style: AppTypography.caption,
//                 ),
//               ],
//             ),
//           ),
//
//           // Batch (clickable)
//           Expanded(
//             flex: 2,
//             child: InkWell(
//               onTap: widget.onChangeBatch,
//               borderRadius: BorderRadius.circular(AppRadius.sm),
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 6,
//                   vertical: 4,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item.batch.batchNumber.value,
//                       style: AppTypography.numericSmall.copyWith(
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(
//                       'Exp ${item.batch.expiryDate.display}',
//                       style: AppTypography.caption,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           // Quantity (editable)
//           Expanded(
//             flex: 1,
//             child: SizedBox(
//               height: 32,
//               child: TextField(
//                 controller: _qtyCtrl,
//                 focusNode: _qtyFocus,
//                 textAlign: TextAlign.center,
//                 keyboardType: TextInputType.number,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 style: AppTypography.numeric,
//                 decoration: _fieldDecoration(),
//                 onSubmitted: (_) => _commitQty(),
//                 onEditingComplete: _commitQty,
//               ),
//             ),
//           ),
//
//           // Price
//           Expanded(
//             flex: 2,
//             child: Text(
//               item.unitPrice.display,
//               textAlign: TextAlign.right,
//               style: AppTypography.numericSmall,
//             ),
//           ),
//
//           // Discount % (typing here auto-fills Disc Amt)
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 4),
//               child: SizedBox(
//                 height: 32,
//                 child: TextField(
//                   controller: _pctCtrl,
//                   focusNode: _pctFocus,
//                   textAlign: TextAlign.center,
//                   keyboardType:
//                   const TextInputType.numberWithOptions(decimal: true),
//                   inputFormatters: [
//                     FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
//                   ],
//                   style: AppTypography.numeric,
//                   decoration: _fieldDecoration(suffix: '%'),
//                   onChanged: _onPercentChanged,
//                 ),
//               ),
//             ),
//           ),
//
//           // Discount amount (typing here auto-fills Disc %)
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 4),
//               child: SizedBox(
//                 height: 32,
//                 child: TextField(
//                   controller: _amtCtrl,
//                   focusNode: _amtFocus,
//                   textAlign: TextAlign.center,
//                   keyboardType:
//                   const TextInputType.numberWithOptions(decimal: true),
//                   inputFormatters: [
//                     FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
//                   ],
//                   style: AppTypography.numeric,
//                   decoration: _fieldDecoration(),
//                   onChanged: _onAmountChanged,
//                 ),
//               ),
//             ),
//           ),
//
//           // Line total
//           Expanded(
//             flex: 2,
//             child: Text(
//               item.lineTotal.display,
//               textAlign: TextAlign.right,
//               style: AppTypography.numeric.copyWith(
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.primary,
//               ),
//             ),
//           ),
//
//           // Remove
//           SizedBox(
//             width: 40,
//             child: IconButton(
//               icon: const Icon(Icons.close_rounded,
//                   size: 16, color: AppColors.error),
//               tooltip: 'Remove line',
//               splashRadius: 14,
//               onPressed: () => widget.controller.removeLine(item.id),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                _headerCell('Disc %', flex: 2, align: TextAlign.center),
                _headerCell('Disc Amt', flex: 2, align: TextAlign.center),
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
                  key: ValueKey(item.id.value),
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

  Widget _headerCell(String label,
      {int flex = 1, TextAlign align = TextAlign.left}) {
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
    super.key,
    required this.item,
    required this.controller,
    required this.onChangeBatch,
  });

  @override
  State<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends State<_CartRow> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _pctCtrl;
  late final TextEditingController _amtCtrl;

  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _pctFocus = FocusNode();
  final FocusNode _amtFocus = FocusNode();

  static String _fmtPct(double v) {
    if (v == 0) return '0';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  static String _fmtAmt(int paisa) => (paisa / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.item.quantity}');
    _pctCtrl =
        TextEditingController(text: _fmtPct(widget.item.discountPercent));
    _amtCtrl = TextEditingController(
        text: _fmtAmt(widget.item.discountAmount.paisa));

    // Save / normalize when a field loses focus (click away).
    _qtyFocus.addListener(() {
      if (!_qtyFocus.hasFocus) _commitQty();
    });
    _pctFocus.addListener(() {
      if (!_pctFocus.hasFocus) _syncDiscountTexts(force: true);
    });
    _amtFocus.addListener(() {
      if (!_amtFocus.hasFocus) _syncDiscountTexts(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant _CartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity &&
        !_qtyFocus.hasFocus) {
      _qtyCtrl.text = '${widget.item.quantity}';
    }
    _syncDiscountTexts();
  }

  /// Updates the discount text boxes from the model.
  /// The box being typed in is left alone (unless [force]).
  void _syncDiscountTexts({bool force = false}) {
    final item = widget.item;
    if (force || !_pctFocus.hasFocus) {
      final t = _fmtPct(item.discountPercent);
      if (_pctCtrl.text != t) _pctCtrl.text = t;
    }
    if (force || !_amtFocus.hasFocus) {
      final t = _fmtAmt(item.discountAmount.paisa);
      if (_amtCtrl.text != t) _amtCtrl.text = t;
    }
  }

  void _commitQty() {
    final n = int.tryParse(_qtyCtrl.text.trim());
    if (n != null) {
      widget.controller.updateQuantity(widget.item.id, n);
    }
    // Reset text to the real value (handles invalid / rejected input).
    if (mounted) _qtyCtrl.text = '${widget.item.quantity}';
  }

  void _onPercentChanged(String text) {
    final pct = double.tryParse(text.trim()) ?? 0;
    widget.controller.updateDiscountPercent(widget.item.id, pct);
    // amount box refreshes automatically through didUpdateWidget
  }

  void _onAmountChanged(String text) {
    final rupees = double.tryParse(text.trim()) ?? 0;
    final paisa = (rupees * 100).round();
    widget.controller.updateDiscountAmount(widget.item.id, paisa);
    // percent box refreshes automatically through didUpdateWidget
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _pctCtrl.dispose();
    _amtCtrl.dispose();
    _qtyFocus.dispose();
    _pctFocus.dispose();
    _amtFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({String? suffix}) => InputDecoration(
    isDense: true,
    suffixText: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
  );

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
                focusNode: _qtyFocus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.numeric,
                decoration: _fieldDecoration(),
                onSubmitted: (_) => _commitQty(),
                onEditingComplete: _commitQty,
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

          // Discount % (typing here auto-fills Disc Amt)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _pctCtrl,
                  focusNode: _pctFocus,
                  textAlign: TextAlign.center,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: AppTypography.numeric,
                  decoration: _fieldDecoration(suffix: '%'),
                  onChanged: _onPercentChanged,
                ),
              ),
            ),
          ),

          // Discount amount (typing here auto-fills Disc %)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _amtCtrl,
                  focusNode: _amtFocus,
                  textAlign: TextAlign.center,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: AppTypography.numeric,
                  decoration: _fieldDecoration(),
                  onChanged: _onAmountChanged,
                ),
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