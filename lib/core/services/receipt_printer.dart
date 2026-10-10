// lib/core/services/receipt_printer.dart

import 'dart:typed_data';
import 'package:printing/printing.dart';

/// Handles sending generated PDF bytes to a physical or virtual printer.
class ReceiptPrinter {
  ReceiptPrinter._();

  /// Print directly to the default (or named) printer without showing a dialog.
  /// Returns true if the print job was accepted by the OS.
  static Future<bool> printSilently({
    required Uint8List pdfBytes,
    required String invoiceName,
    String? printerName,
  }) async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) return false;

      Printer target;
      if (printerName != null && printerName.trim().isNotEmpty) {
        final search = printerName.trim().toLowerCase();
        target = printers.firstWhere(
          (p) => p.name.toLowerCase().contains(search),
          orElse: () => printers.firstWhere(
            (p) => p.isDefault,
            orElse: () => printers.first,
          ),
        );
      } else {
        target = printers.firstWhere(
          (p) => p.isDefault,
          orElse: () => printers.first,
        );
      }

      return await Printing.directPrintPdf(
        printer: target,
        onLayout: (_) async => pdfBytes,
        name: invoiceName,
        usePrinterSettings: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Show the OS print dialog so the user can pick a printer and preview.
  static Future<void> printWithDialog({
    required Uint8List pdfBytes,
    required String invoiceName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: invoiceName,
    );
  }

  /// List all available printers on this PC (for Settings UI).
  static Future<List<Printer>> listPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (_) {
      return [];
    }
  }
}