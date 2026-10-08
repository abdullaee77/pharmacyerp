// lib/features/sales/presentation/screens/pos_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../inventory/domain/batch.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../../users/domain/role.dart';
import '../controllers/pos_cart_controller.dart';
import '../controllers/sales_controller.dart';
import 'package:pharmacy/features/sales/domain/pos_models.dart';
import '../widgets/batch_picker_dialog.dart';
import '../widgets/invoice_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/pos_cart_table.dart';
import '../widgets/pos_search_panel.dart';

class PosScreen extends StatefulWidget {
  final PosCartController controller;
  final SalesController salesController;
  final AuthController authController;

  const PosScreen({
    super.key,
    required this.controller,
    required this.salesController,
    required this.authController,
  });

  @override
  State<PosScreen> createState() => PosScreenState();
}

class PosScreenState extends State<PosScreen> with AutomaticKeepAliveClientMixin {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchTextController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadInitial();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _searchFocusNode.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  bool get _canAddSale => PermissionGate.allow(
    widget.authController.currentUser,
    PermissionCategory.sales,
    PermissionAction.add,
  );

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;

    return _processKey(event.logicalKey, event.physicalKey);
  }

  bool _processKey(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    final String label = logical.keyLabel.trim().toUpperCase();

    // 1. Search Medicine: F2
    if (logical == LogicalKeyboardKey.f2 ||
        physical == PhysicalKeyboardKey.f2 ||
        label == 'F2') {
      focusSearch();
      return true;
    }

    // 2. Complete Sale / Pay: F8
    if (logical == LogicalKeyboardKey.f8 ||
        physical == PhysicalKeyboardKey.f8 ||
        label == 'F8') {
      if (_canAddSale) {
        triggerPay();
      }
      return true;
    }

    // 3. Hold / Resume Sale: F9
    if (logical == LogicalKeyboardKey.f9 ||
        physical == PhysicalKeyboardKey.f9 ||
        label == 'F9') {
      if (_canAddSale) {
        triggerHold();
      }
      return true;
    }

    // 4. Escape: Clear Search Focus
    if (logical == LogicalKeyboardKey.escape ||
        physical == PhysicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return true;
      }
    }

    return false;
  }

  void focusSearch() {
    _searchFocusNode.requestFocus();
    if (_searchTextController.text.isNotEmpty) {
      _searchTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchTextController.text.length,
      );
    }
  }

  void triggerPay() {
    if (!_canAddSale) return;
    if (widget.controller.isEmpty) {
      AppToast.info(context, 'Cart is empty. Add medicines before proceeding to payment.');
      return;
    }
    _onPay();
  }

  void triggerHold() {
    if (!_canAddSale) return;
    _onHold();
  }

  Future<void> _handleMedicineSelected(PosSearchResult result) async {
    if (!_canAddSale) return;
    final medicine = result.medicine;

    try {
      final batches = await widget.controller.loadBatches(medicine.id);
      if (!mounted) return;

      Batch targetBatch;

      final usableBatches = batches
          .where((b) => b.status != BatchStatus.expired)
          .toList();

      if (usableBatches.isEmpty) {
        targetBatch = Batch(
          id: BatchId.generate(),
          medicineId: medicine.id,
          medicineName: medicine.name,
          batchNumber: BatchNumber.unsafe('BATCH-01'),
          expiryDate: ExpiryDate(DateTime.now().add(const Duration(days: 365))),
          quantity: Quantity.create(result.currentStock > 0 ? result.currentStock : 1000),
          purchasePrice: medicine.purchasePrice,
          sellingPrice: medicine.sellingPrice,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else if (usableBatches.length == 1) {
        targetBatch = usableBatches.first;
      } else {
        final Batch? selected = await showDialog<Batch?>(
          context: context,
          builder: (ctx) => BatchPickerDialog(medicine: medicine, batches: usableBatches),
        );

        if (selected == null) return;
        targetBatch = selected;
      }

      widget.controller.addToCart(
        medicine: medicine,
        batch: targetBatch,
        quantity: 1,
      );
    } catch (e, stack) {
      debugPrint('Error adding medicine to cart: $e\n$stack');
      if (mounted) {
        AppToast.error(context, 'Failed to add item: ${e.toString()}');
      }
    }
  }

  Future<void> _onPay() async {
    try {
      final result = await showDialog<PaymentResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PaymentDialog(
          cartController: widget.controller,
          salesController: widget.salesController,
          operatorName: widget.authController.currentUser?.fullName ?? 'Operator',
          user: widget.authController.currentUser,
        ),
      );

      if (result != null && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => InvoiceDialog(
            invoiceNumber: result.invoiceNumber,
            customerName: result.customerName,
            customerPhone: result.customerPhone,
            operatorName: widget.authController.currentUser?.fullName ?? 'Operator',
            lines: result.lines,
            subtotal: result.subtotal,
            discount: result.discount,
            grandTotal: result.grandTotal,
            amountReceived: result.amountReceived,
            change: result.change,
            paymentSummary: result.paymentSummary,
            createdAt: result.createdAt,
          ),
        );

        if (mounted) {
          widget.controller.clearCart();
          focusSearch();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Payment error: $e');
      }
    }
  }

  Future<void> _onHold() async {
    await showDialog(
      context: context,
      builder: (ctx) => _HeldSalesDialog(controller: widget.controller),
    );
  }

  Future<void> _onClear() async {
    final confirmed = await AppDialog.warning(
      context,
      title: 'Clear Cart?',
      message: 'All items in the current cart will be removed.',
      confirmLabel: 'Clear',
    );
    if (confirmed) {
      widget.controller.clearCart();
      focusSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final handled = _processKey(event.logicalKey, event.physicalKey);
              return handled ? KeyEventResult.handled : KeyEventResult.ignored;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 28),
                              const SizedBox(width: AppSpacing.md),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Point of Sale', style: AppTypography.pageTitle),
                                  Text('Type medicine name or generic formula to add to cart.', style: AppTypography.bodySmall.copyWith(color: Colors.grey[600])),
                                ],
                              ),
                              const Spacer(),
                              _ShortcutHints(
                                onF2Pressed: focusSearch,
                                onF8Pressed: _canAddSale ? triggerPay : null,
                                onF9Pressed: _canAddSale ? triggerHold : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const SizedBox(height: 96),

                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: PosCartTable(controller: widget.controller),
                            ),
                          ),

                          Container(
                            margin: const EdgeInsets.only(top: AppSpacing.lg),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Subtotal: ${widget.controller.totals.subtotal.display}', style: AppTypography.body),
                                      Text('Discount: - ${widget.controller.totals.totalDiscount.display}', style: AppTypography.bodySmall.copyWith(color: AppColors.success)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('GRAND TOTAL', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      Text(widget.controller.totals.grandTotal.display, style: AppTypography.numericLarge.copyWith(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                                if (widget.controller.lastMessage != null)
                                  Expanded(
                                    child: Text(
                                      widget.controller.lastMessage!,
                                      style: AppTypography.caption.copyWith(
                                          color: widget.controller.lastMessageIsError ? AppColors.error : AppColors.success,
                                          fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                    ),
                                  )
                                else
                                  const Spacer(),

                                if (_canAddSale) ...[
                                  AppButton(
                                    label: 'Clear',
                                    variant: AppButtonVariant.ghost,
                                    onPressed: widget.controller.isEmpty ? null : _onClear,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),

                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AppButton(
                                        label: 'Hold (F9)',
                                        variant: AppButtonVariant.outlined,
                                        onPressed: triggerHold,
                                      ),
                                      if (widget.controller.heldSalesCount > 0)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                            child: Text(
                                              '${widget.controller.heldSalesCount}',
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(width: AppSpacing.sm),
                                  AppButton(
                                    label: 'Complete Sale (F8)',
                                    icon: Icons.payments_rounded,
                                    variant: AppButtonVariant.primary,
                                    onPressed: triggerPay,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      Positioned(
                        top: 66,
                        left: 0,
                        right: 0,
                        child: PosSearchPanel(
                          controller: widget.controller,
                          focusNode: _searchFocusNode,
                          textController: _searchTextController,
                          onMedicineSelected: _handleMedicineSelected,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HeldSalesDialog extends StatefulWidget {
  final PosCartController controller;

  const _HeldSalesDialog({required this.controller});

  @override
  State<_HeldSalesDialog> createState() => _HeldSalesDialogState();
}

class _HeldSalesDialogState extends State<_HeldSalesDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _holdCurrentCart() {
    if (widget.controller.isEmpty) return;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    widget.controller.holdCurrentSale(note: note);
    Navigator.of(context).pop();
  }

  void _resumeHeldSale(HeldSale held) {
    if (!widget.controller.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cart Not Empty'),
          content: const Text('Resuming this order will overwrite current cart items. Do you want to hold the current cart first?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.controller.holdCurrentSale(note: 'Auto-held before resuming');
                widget.controller.resumeSale(held);
                Navigator.of(context).pop();
                AppToast.success(context, 'Resumed held sale.');
              },
              child: const Text('Hold Current & Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.controller.resumeSale(held);
                Navigator.of(context).pop();
                AppToast.success(context, 'Overwrite Current');
              },
              child: const Text('Overwrite Current'),
            ),
          ],
        ),
      );
    } else {
      widget.controller.resumeSale(held);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final hasCurrentItems = !ctrl.isEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pause_circle_filled_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Held Sales Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    Text('Hold current cart or restore previously held orders', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            if (hasCurrentItems) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Cart: ${ctrl.items.length} items (${ctrl.totals.grandTotal.display})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                        ElevatedButton.icon(
                          onPressed: _holdCurrentCart,
                          icon: const Icon(Icons.pause_rounded, size: 16),
                          label: const Text('Hold This Cart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Optional note / customer reference for this held order...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text('Cart is currently empty. You can restore any held sale below.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text('Saved Held Orders (${ctrl.heldSales.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),

            Expanded(
              child: ctrl.heldSales.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No held orders currently.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              )
                  : ListView.separated(
                itemCount: ctrl.heldSales.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final h = ctrl.heldSales[i];
                  final timeStr = '${h.heldAt.hour.toString().padLeft(2, '0')}:${h.heldAt.minute.toString().padLeft(2, '0')}';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF3B82F6), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(h.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                                  const SizedBox(width: 8),
                                  Text('Held at $timeStr', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${h.items.length} items  •  ${h.totals.grandTotal.display}${h.note != null && h.note!.isNotEmpty ? '  •  "${h.note}"' : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _resumeHeldSale(h),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text('Resume'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          tooltip: 'Delete Held Sale',
                          splashRadius: 18,
                          onPressed: () {
                            setState(() {
                              widget.controller.deleteHeldSale(h.id);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutHints extends StatelessWidget {
  final VoidCallback? onF2Pressed;
  final VoidCallback? onF8Pressed;
  final VoidCallback? onF9Pressed;

  const _ShortcutHints({
    this.onF2Pressed,
    this.onF8Pressed,
    this.onF9Pressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyHint('F2', 'Search', onTap: onF2Pressed),
        const SizedBox(width: AppSpacing.sm),
        _KeyHint('F8', 'Pay', onTap: onF8Pressed),
        const SizedBox(width: AppSpacing.sm),
        _KeyHint('F9', 'Hold / Resume', onTap: onF9Pressed),
      ],
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String keyLabel;
  final String label;
  final VoidCallback? onTap;

  const _KeyHint(this.keyLabel, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(keyLabel, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}