// lib/core/services/receipt_pdf_builder.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../../features/sales/presentation/widgets/invoice_dialog.dart';

enum ReceiptLayout { thermal58, thermal80, a4 }

class ReceiptPdfBuilder {
  ReceiptPdfBuilder._();

  static const _footerLine1 = 'This software is developed by Ranker Solutions';
  static const _footerLine2 = 'www.rankersolutions.com';
  static const _footerUrdu =
      'اپنا سافٹ ویئر بنوانے کے لیے اس نمبر پر رابطہ کریں';
  static const _footerPhone = '0335-4444788';

  /// Tight dynamic height calculation in mm to prevent tall empty paper trailing
  static double _calculateHeightMm({
    required int itemCount,
    required bool hasLogo,
    required bool hasPhone,
    required bool hasAddress,
    required bool hasFooterMsg,
    required bool hasVendorFooter,
    required bool isCompact,
    required double fontScale,
  }) {
    double h = 10; // Top & bottom margins
    if (hasLogo) h += 18 * fontScale;
    h += 6 * fontScale; // Pharmacy Name
    if (hasPhone) h += 4 * fontScale;
    if (hasAddress) h += 6 * fontScale;
    h += 16 * fontScale; // Meta rows (Inv, Date, Cust, User)
    h += 7 * fontScale; // Table header
    h += itemCount * (isCompact ? 5.0 : 6.5) * fontScale; // Item rows
    h += 12 * fontScale; // Subtotal & Grand Total
    if (!isCompact) h += 10 * fontScale; // Received / Change / Payment summary
    if (hasFooterMsg) h += 8 * fontScale;
    if (hasVendorFooter) h += 14 * fontScale;
    h += 4; // Safety padding
    return h < 50 ? 50 : h;
  }

  static Future<Uint8List> build({
    required String invoiceNumber,
    required String customerName,
    required String customerPhone,
    required String operatorName,
    required List<InvoiceLineData> lines,
    required String subtotal,
    required String discount,
    required String grandTotal,
    required String amountReceived,
    required String change,
    required String paymentSummary,
    required DateTime createdAt,
    ReceiptLayout layout = ReceiptLayout.thermal80,
    bool isCompact = false,
    double marginLeftMm = 1.0,
    double marginRightMm = 1.0,
    double fontScale = 1.0,
    String pharmacyName = 'PharmaSuite ERP',
    String pharmacyPhone = '',
    String pharmacyAddress = '',
    String? logoPath,
    String footerMessage = 'Thank you for your purchase!',
    bool showVendorFooter = true,
  }) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();

    pw.MemoryImage? logo;
    if (logoPath != null && logoPath.trim().isNotEmpty) {
      try {
        final file = File(logoPath.trim());
        if (await file.exists()) {
          logo = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    PdfPageFormat pageFormat;
    if (layout == ReceiptLayout.a4) {
      pageFormat = const PdfPageFormat(
        210 * PdfPageFormat.mm,
        297 * PdfPageFormat.mm,
        marginAll: 12 * PdfPageFormat.mm,
      );
    } else {
      final double totalHeightMm = _calculateHeightMm(
        itemCount: lines.length,
        hasLogo: logo != null,
        hasPhone: pharmacyPhone.isNotEmpty,
        hasAddress: pharmacyAddress.isNotEmpty,
        hasFooterMsg: footerMessage.trim().isNotEmpty,
        hasVendorFooter: showVendorFooter,
        isCompact: isCompact,
        fontScale: fontScale,
      );

      final is58 = layout == ReceiptLayout.thermal58;
      final paperWidthMm = is58 ? 58.0 : 80.0;

      pageFormat = PdfPageFormat(
        paperWidthMm * PdfPageFormat.mm,
        totalHeightMm * PdfPageFormat.mm,
        marginLeft: marginLeftMm * PdfPageFormat.mm,
        marginRight: marginRightMm * PdfPageFormat.mm,
        marginTop: 2.0 * PdfPageFormat.mm,
        marginBottom: 2.0 * PdfPageFormat.mm,
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context ctx) {
          return _buildThermal(
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
            fonts: fonts,
            pharmacyName: pharmacyName,
            pharmacyPhone: pharmacyPhone,
            pharmacyAddress: pharmacyAddress,
            logo: logo,
            footerMessage: footerMessage,
            showVendorFooter: showVendorFooter,
            isNarrow: layout == ReceiptLayout.thermal58,
            isCompact: isCompact,
            fontScale: fontScale,
          );
        },
      ),
    );

    return await doc.save();
  }

  static Future<_Fonts> _loadFonts() async {
    final regular = await PdfGoogleFonts.poppinsRegular();
    final bold = await PdfGoogleFonts.poppinsBold();
    pw.Font urdu;
    try {
      urdu = await PdfGoogleFonts.notoNaskhArabicBold();
    } catch (_) {
      urdu = bold;
    }
    return _Fonts(regular: regular, bold: bold, urdu: urdu);
  }

  static String _formatDate(DateTime dt) {
    try {
      return DateFormat('dd MMM yy, HH:mm').format(dt.toLocal());
    } catch (_) {
      return dt.toLocal().toString().substring(0, 16);
    }
  }

  static String _amt(String v) {
    return v.replaceAll('PKR ', '').trim();
  }

  static pw.Widget _dashedLine() {
    return pw.Divider(
      thickness: 0.6,
      height: 3,
      color: PdfColors.black,
      borderStyle: pw.BorderStyle.dashed,
    );
  }

  static pw.Widget _metaRow(
      _Fonts f,
      String label,
      String value, {
        required double fontSize,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: f.bold, fontSize: fontSize)),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              maxLines: 1,
              style: pw.TextStyle(font: f.bold, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildThermal({
    required String invoiceNumber,
    required String customerName,
    required String customerPhone,
    required String operatorName,
    required List<InvoiceLineData> lines,
    required String subtotal,
    required String discount,
    required String grandTotal,
    required String amountReceived,
    required String change,
    required String paymentSummary,
    required DateTime createdAt,
    required _Fonts fonts,
    required String pharmacyName,
    required String pharmacyPhone,
    required String pharmacyAddress,
    pw.MemoryImage? logo,
    required String footerMessage,
    required bool showVendorFooter,
    required bool isNarrow,
    required bool isCompact,
    required double fontScale,
  }) {
    final fs = (isCompact ? (isNarrow ? 6.0 : 6.5) : (isNarrow ? 6.5 : 7.0)) * fontScale;
    final fsItem = (isCompact ? (isNarrow ? 5.5 : 6.0) : (isNarrow ? 6.0 : 6.5)) * fontScale;

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (logo != null) ...[
          pw.Center(
            child: pw.Container(
              width: (isNarrow ? 14 : 18) * PdfPageFormat.mm,
              height: (isNarrow ? 14 : 18) * PdfPageFormat.mm,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
          pw.SizedBox(height: 2),
        ],

        pw.Center(
          child: pw.Text(
            pharmacyName,
            style: pw.TextStyle(font: fonts.bold, fontSize: (isNarrow ? 9.0 : 11.0) * fontScale),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (pharmacyPhone.isNotEmpty)
          pw.Center(
            child: pw.Text(pharmacyPhone,
                style: pw.TextStyle(font: fonts.bold, fontSize: fs)),
          ),
        if (pharmacyAddress.isNotEmpty)
          pw.Center(
            child: pw.Text(
              pharmacyAddress,
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              style: pw.TextStyle(font: fonts.regular, fontSize: fs - 0.5),
            ),
          ),

        pw.SizedBox(height: 2),
        _dashedLine(),

        _metaRow(fonts, 'Inv', invoiceNumber, fontSize: fs),
        _metaRow(fonts, 'Date', _formatDate(createdAt), fontSize: fs),
        if (!isCompact || customerName != 'Walk-in Customer')
          _metaRow(
            fonts,
            'Cust',
            customerPhone.isNotEmpty
                ? '$customerName ($customerPhone)'
                : customerName,
            fontSize: fs,
          ),
        _metaRow(fonts, 'User', operatorName, fontSize: fs),
        pw.SizedBox(height: 2),

        // ── Table: Generous AMT flex width to prevent right-hand clipping ──
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
          columnWidths: isNarrow
              ? const {
            0: pw.FixedColumnWidth(9),
            1: pw.FlexColumnWidth(2.4),
            2: pw.FixedColumnWidth(14),
            3: pw.FlexColumnWidth(2.0),
          }
              : const {
            0: pw.FixedColumnWidth(11),
            1: pw.FlexColumnWidth(3.0),
            2: pw.FixedColumnWidth(18),
            3: pw.FlexColumnWidth(2.5),
          },
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              children: [
                _cell('#', fonts, fsItem, align: pw.TextAlign.center, bold: true),
                _cell('ITEM', fonts, fsItem, align: pw.TextAlign.left, bold: true),
                _cell('QTY', fonts, fsItem, align: pw.TextAlign.center, bold: true),
                _cell('AMT', fonts, fsItem, align: pw.TextAlign.right, bold: true),
              ],
            ),
            for (var i = 0; i < lines.length; i++)
              pw.TableRow(
                children: [
                  _cell('${i + 1}', fonts, fsItem,
                      align: pw.TextAlign.center, bold: true),
                  _cell(
                    '${lines[i].medicineName} ${lines[i].strength}'.trim(),
                    fonts,
                    fsItem,
                    align: pw.TextAlign.left,
                    bold: true,
                  ),
                  _cell('${lines[i].quantity}', fonts, fsItem,
                      align: pw.TextAlign.center, bold: true),
                  _cell(_amt(lines[i].lineTotal), fonts, fsItem,
                      align: pw.TextAlign.right, bold: true),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 2),

        _metaRow(fonts, 'Subtotal', _amt(subtotal), fontSize: fs),
        if (discount != 'PKR 0.00' && discount != '0.00')
          _metaRow(fonts, 'Discount', '- ${_amt(discount)}', fontSize: fs),
        pw.Divider(thickness: 1.0, height: 3, color: PdfColors.black),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('TOTAL',
                    style: pw.TextStyle(font: fonts.bold, fontSize: fs + 1)),
              ),
              pw.Text(_amt(grandTotal),
                  style: pw.TextStyle(font: fonts.bold, fontSize: fs + 1)),
            ],
          ),
        ),
        pw.Divider(thickness: 1.0, height: 3, color: PdfColors.black),

        if (!isCompact) ...[
          _metaRow(fonts, 'Received', _amt(amountReceived), fontSize: fs),
          _metaRow(fonts, 'Change', _amt(change), fontSize: fs),
          _metaRow(fonts, 'Pay', paymentSummary, fontSize: fs),
          pw.SizedBox(height: 1),
          _dashedLine(),
        ],

        if (footerMessage.trim().isNotEmpty) ...[
          pw.Center(
            child: pw.Text(
              footerMessage,
              style: pw.TextStyle(font: fonts.bold, fontSize: fs),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 1),
          _dashedLine(),
        ],

        if (showVendorFooter) ...[
          pw.SizedBox(height: 1),
          pw.Center(
            child: pw.Text(_footerLine1,
                style: pw.TextStyle(font: fonts.bold, fontSize: 4.8),
                textAlign: pw.TextAlign.center),
          ),
          pw.Center(
            child: pw.Text(_footerLine2,
                style: pw.TextStyle(font: fonts.bold, fontSize: 4.8)),
          ),
          pw.SizedBox(height: 1),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text(_footerUrdu,
                  style: pw.TextStyle(font: fonts.urdu, fontSize: 5.5),
                  textAlign: pw.TextAlign.center),
            ),
          ),
          pw.Center(
            child: pw.Text(_footerPhone,
                style: pw.TextStyle(font: fonts.bold, fontSize: 5.5)),
          ),
        ],
      ],
    );
  }

  static pw.Widget _cell(
      String text,
      _Fonts f,
      double fontSize, {
        required pw.TextAlign align,
        bool bold = true,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0, horizontal: 1.0),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: bold ? f.bold : f.regular,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _Fonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font urdu;
  const _Fonts(
      {required this.regular, required this.bold, required this.urdu});
}