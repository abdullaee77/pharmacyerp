// lib/features/sales/presentation/widgets/invoice_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/services/receipt_printer.dart';
import '../../../../core/services/receipt_pdf_builder.dart';
import '../../../../core/services/printer_settings.dart';

class InvoiceLineData {
  final String medicineName;
  final String strength;
  final String batchNumber;
  final int quantity;
  final String unitPrice;
  final String lineTotal;

  const InvoiceLineData({
    required this.medicineName,
    required this.strength,
    required this.batchNumber,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });
}

class InvoiceDialog extends StatelessWidget {
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String operatorName;
  final List<InvoiceLineData> lines;
  final String subtotal;
  final String discount;
  final String grandTotal;
  final String amountReceived;
  final String change;
  final String paymentSummary;
  final DateTime createdAt;

  const InvoiceDialog({
    super.key,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.operatorName,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.amountReceived,
    required this.change,
    required this.paymentSummary,
    required this.createdAt,
  });

  String get _timestamp {
    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      AppToast.info(context, 'Generating receipt...');

      final layout = await PrinterSettings.layout;
      final isCompact = await PrinterSettings.isCompact;
      final marginLeft = await PrinterSettings.marginLeftMm;
      final marginRight = await PrinterSettings.marginRightMm;
      final fontScale = await PrinterSettings.fontScale;
      final printerName = await PrinterSettings.printerName;
      final pharmName = await PrinterSettings.pharmacyName;
      final pharmPhone = await PrinterSettings.pharmacyPhone;
      final pharmAddr = await PrinterSettings.pharmacyAddress;
      final logoPath = await PrinterSettings.pharmacyLogoPath;
      final footer = await PrinterSettings.footerMessage;
      final vendorFooter = await PrinterSettings.showVendorFooter;
      final useDirect = await PrinterSettings.directPrint;

      final pdfBytes = await ReceiptPdfBuilder.build(
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        operatorName: operatorName,
        lines: lines,
        subtotal: subtotal,
        discount: discount,
        grandTotal: grandTotal,
        amountReceived: amountReceived,
        change: change,
        paymentSummary: paymentSummary,
        createdAt: createdAt,
        layout: layout,
        isCompact: isCompact,
        marginLeftMm: marginLeft,
        marginRightMm: marginRight,
        fontScale: fontScale,
        pharmacyName: pharmName.isEmpty ? 'PharmaSuite ERP' : pharmName,
        pharmacyPhone: pharmPhone,
        pharmacyAddress: pharmAddr,
        logoPath: logoPath.isEmpty ? null : logoPath,
        footerMessage: footer.isEmpty ? 'Thank you for your purchase!' : footer,
        showVendorFooter: vendorFooter,
      );

      if (!context.mounted) return;

      if (useDirect) {
        final ok = await ReceiptPrinter.printSilently(
          pdfBytes: pdfBytes,
          invoiceName: invoiceNumber,
          printerName: printerName.isNotEmpty ? printerName : null,
        );
        if (context.mounted) {
          if (ok) {
            AppToast.success(context, 'Receipt sent to printer.');
          } else {
            AppToast.error(context, 'Direct print failed. Check printer settings.');
          }
        }
      } else {
        await ReceiptPrinter.printWithDialog(
          pdfBytes: pdfBytes,
          invoiceName: invoiceNumber,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Print failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice', style: AppTypography.sectionTitle),
                      Text(invoiceNumber, style: AppTypography.caption),
                    ],
                  ),
                  const Spacer(),
                  const AppBadge(
                    label: 'Completed',
                    variant: AppBadgeVariant.success,
                    isDot: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PHARMASUITE ERP',
                        style: AppTypography.subtitle.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                    Text('Main Branch — Counter 01',
                        style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.md),

                    _kv('Customer',
                        customerPhone.isNotEmpty
                            ? '$customerName ($customerPhone)'
                            : customerName),
                    _kv('Operator', operatorName),
                    _kv('Date / Time', _timestamp),

                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),

                    ...lines.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                    '${l.medicineName} ${l.strength}',
                                    style: AppTypography.subtitle
                                        .copyWith(fontSize: 13)),
                              ),
                              Text(l.lineTotal,
                                  style: AppTypography.numeric.copyWith(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Text(
                              'Batch ${l.batchNumber}  ·  ${l.quantity} × ${l.unitPrice}',
                              style: AppTypography.caption),
                        ],
                      ),
                    )),

                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),

                    _kvNumeric('Subtotal', subtotal),
                    _kvNumeric('Discount', '- $discount'),
                    _kvNumeric('Grand Total', grandTotal, emphasize: true),

                    const SizedBox(height: AppSpacing.md),

                    _kvNumeric('Amount Received', amountReceived),
                    _kvNumeric('Change', change),

                    const SizedBox(height: AppSpacing.sm),
                    Text('Payment: $paymentSummary',
                        style: AppTypography.caption),

                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text('Thank you for your purchase!',
                          style: AppTypography.caption
                              .copyWith(fontStyle: FontStyle.italic)),
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
                    label: 'Print Receipt',
                    icon: Icons.print_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _printReceipt(context),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Close',
                    variant: AppButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(k, style: AppTypography.caption)),
          Expanded(
              child: Text(v,
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _kvNumeric(String k, String v, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: emphasize
                  ? AppTypography.subtitle.copyWith(color: AppColors.primary)
                  : AppTypography.body),
          Text(v,
              style: emphasize
                  ? AppTypography.numericLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)
                  : AppTypography.numeric),
        ],
      ),
    );
  }
}