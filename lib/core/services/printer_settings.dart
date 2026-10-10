// lib/core/services/printer_settings.dart

import '../../features/settings/data/sqlite_settings_repository.dart';
import 'receipt_pdf_builder.dart';

class PrinterSettings {
  PrinterSettings._();

  static final _repo = SqliteSettingsRepository();

  static Future<String> _get(String key) async {
    final r = await _repo.getSetting(key);
    return r.fold(onSuccess: (v) => v, onFailure: (_) => '');
  }

  static Future<bool> get autoPrint async {
    final v = await _get('printer_auto_print');
    return v.toLowerCase() == 'true';
  }

  /// When true: Print Receipt goes straight to the selected printer (no Windows dialog).
  static Future<bool> get directPrint async {
    final v = await _get('printer_direct_print');
    return v.toLowerCase() == 'true';
  }

  static Future<String> get printerName => _get('printer_name');

  static Future<ReceiptLayout> get layout async {
    final v = await _get('printer_layout');
    switch (v) {
      case 'thermal58':
        return ReceiptLayout.thermal58;
      case 'a4':
        return ReceiptLayout.a4;
      default:
        return ReceiptLayout.thermal80;
    }
  }

  /// Returns true if compact layout (no payment breakdown) is enabled
  static Future<bool> get isCompact async {
    final v = await _get('printer_receipt_density');
    return v.toLowerCase() == 'compact';
  }

  /// Custom Left Margin in mm (default 1.0mm to offset driver padding)
  static Future<double> get marginLeftMm async {
    final v = await _get('printer_margin_left');
    return double.tryParse(v) ?? 1.0;
  }

  /// Custom Right Margin in mm (default 1.0mm)
  static Future<double> get marginRightMm async {
    final v = await _get('printer_margin_right');
    return double.tryParse(v) ?? 1.0;
  }

  /// Font scale multiplier: 0.85 (small), 1.0 (normal), 1.15 (large)
  static Future<double> get fontScale async {
    final v = await _get('printer_font_scale');
    return double.tryParse(v) ?? 1.0;
  }

  static Future<String> get pharmacyName => _get('pharmacy_name');
  static Future<String> get pharmacyPhone => _get('pharmacy_phone');
  static Future<String> get pharmacyAddress => _get('pharmacy_address');
  static Future<String> get pharmacyLogoPath => _get('pharmacy_logo_path');
  static Future<String> get footerMessage => _get('pharmacy_footer');

  static Future<bool> get showVendorFooter async {
    final v = await _get('pharmacy_show_vendor_footer');
    return v.toLowerCase() != 'false';
  }
}