// lib/features/settings/presentation/screens/settings_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/services/receipt_pdf_builder.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../sales/presentation/widgets/invoice_dialog.dart';
import '../../../users/domain/role.dart';
import '../controllers/settings_controller.dart';

enum SettingsMode { store, printer }

class SettingsScreen extends StatefulWidget {
  final SettingsMode mode;
  final SettingsController controller;
  final AuthController authController;

  const SettingsScreen({
    super.key,
    required this.mode,
    required this.controller,
    required this.authController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedPrinter;
  late String _selectedLayout;
  late String _receiptDensity; // 'standard' or 'compact'
  late double _marginLeftMm;
  late double _marginRightMm;
  late String _fontScaleChoice; // '0.85', '1.0', '1.15'
  late bool _autoPrint;
  late bool _directPrint;
  late String _logoPath;
  late TextEditingController _pharmNameCtrl;
  late TextEditingController _pharmPhoneCtrl;
  late TextEditingController _pharmAddrCtrl;
  late TextEditingController _footerCtrl;
  late bool _showVendorFooter;

  List<Printer> _printers = [];
  bool _loadingPrinters = true;
  bool _isInitialized = false;

  bool get _canManage => PermissionGate.allow(
      widget.authController.currentUser,
      PermissionCategory.settings,
      PermissionAction.manage);

  @override
  void initState() {
    super.initState();
    widget.controller.loadSettings().then((_) {
      _initValues();
      if (widget.mode == SettingsMode.printer) {
        _detectPrinters();
      }
    });
  }

  void _initValues() {
    _selectedPrinter = widget.controller.getValue('printer_name');
    final l = widget.controller.getValue('printer_layout');
    _selectedLayout = (l.isEmpty || l == 'a4') ? 'thermal80' : l;

    final d = widget.controller.getValue('printer_receipt_density');
    _receiptDensity = d.isEmpty ? 'standard' : d;

    _marginLeftMm = double.tryParse(widget.controller.getValue('printer_margin_left')) ?? 0.0;
    _marginRightMm = double.tryParse(widget.controller.getValue('printer_margin_right')) ?? 10.0;

    final fs = widget.controller.getValue('printer_font_scale');
    _fontScaleChoice = fs.isEmpty ? '1.0' : fs;

    _autoPrint = widget.controller.getValue('printer_auto_print') == 'true';
    _directPrint = widget.controller.getValue('printer_direct_print') == 'true';
    _logoPath = widget.controller.getValue('pharmacy_logo_path');

    final pn = widget.controller.getValue('pharmacy_name');
    _pharmNameCtrl =
        TextEditingController(text: pn.isEmpty ? 'PharmaSuite ERP' : pn);
    _pharmPhoneCtrl =
        TextEditingController(text: widget.controller.getValue('pharmacy_phone'));
    _pharmAddrCtrl = TextEditingController(
        text: widget.controller.getValue('pharmacy_address'));

    final ft = widget.controller.getValue('pharmacy_footer');
    _footerCtrl = TextEditingController(
        text: ft.isEmpty ? 'Thank you for your purchase!' : ft);
    _showVendorFooter = widget.controller
        .getValue('pharmacy_show_vendor_footer')
        .toLowerCase() !=
        'false';

    if (mounted) setState(() { _isInitialized = true; });
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _pharmNameCtrl.dispose();
      _pharmPhoneCtrl.dispose();
      _pharmAddrCtrl.dispose();
      _footerCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _detectPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          _loadingPrinters = false;
          if (_selectedPrinter.isEmpty && printers.isNotEmpty) {
            final defaultPrinter = printers.firstWhere(
                  (p) => p.isDefault,
              orElse: () => printers.first,
            );
            _selectedPrinter = defaultPrinter.name;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _save() async {
    final Map<String, String> payload = {};

    if (widget.mode == SettingsMode.store) {
      payload['pharmacy_name'] = _pharmNameCtrl.text.trim();
      payload['pharmacy_phone'] = _pharmPhoneCtrl.text.trim();
      payload['pharmacy_address'] = _pharmAddrCtrl.text.trim();
      payload['pharmacy_logo_path'] = _logoPath;
    } else {
      payload['printer_name'] = _selectedPrinter;
      payload['printer_layout'] = _selectedLayout;
      payload['printer_receipt_density'] = _receiptDensity;
      payload['printer_margin_left'] = _marginLeftMm.toStringAsFixed(1);
      payload['printer_margin_right'] = _marginRightMm.toStringAsFixed(1);
      payload['printer_font_scale'] = _fontScaleChoice;
      payload['printer_auto_print'] = _autoPrint.toString();
      payload['printer_direct_print'] = _directPrint.toString();
      payload['pharmacy_footer'] = _footerCtrl.text.trim();
      payload['pharmacy_show_vendor_footer'] = _showVendorFooter.toString();
    }

    final error = await widget.controller.saveSettings(payload);

    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(
        context,
        widget.mode == SettingsMode.store
            ? 'Store Information saved.'
            : 'Printer Settings saved.',
      );
    }
  }

  Future<Uint8List> _generatePreviewPdf() async {
    return ReceiptPdfBuilder.build(
      invoiceNumber: 'INV-20231025-001',
      customerName: 'Walk-in Customer',
      customerPhone: '',
      operatorName: widget.authController.currentUser?.fullName ?? 'Operator',
      lines: const [
        InvoiceLineData(
          medicineName: 'Panadol',
          strength: '500mg',
          batchNumber: 'B-101',
          quantity: 2,
          unitPrice: 'PKR 25.00',
          lineTotal: 'PKR 50.00',
        ),
        InvoiceLineData(
          medicineName: 'Augmentin',
          strength: '625mg',
          batchNumber: 'B-442',
          quantity: 1,
          unitPrice: 'PKR 250.00',
          lineTotal: 'PKR 250.00',
        ),
      ],
      subtotal: 'PKR 300.00',
      discount: 'PKR 0.00',
      grandTotal: 'PKR 300.00',
      amountReceived: 'PKR 500.00',
      change: 'PKR 200.00',
      paymentSummary: 'Cash: PKR 500.00',
      createdAt: DateTime.now(),
      layout: _selectedLayout == 'thermal58'
          ? ReceiptLayout.thermal58
          : ReceiptLayout.thermal80,
      isCompact: _receiptDensity == 'compact',
      marginLeftMm: _marginLeftMm,
      marginRightMm: _marginRightMm,
      fontScale: double.tryParse(_fontScaleChoice) ?? 1.0,
      pharmacyName:
      _pharmNameCtrl.text.isEmpty ? 'PharmaSuite ERP' : _pharmNameCtrl.text,
      pharmacyPhone: _pharmPhoneCtrl.text,
      pharmacyAddress: _pharmAddrCtrl.text,
      logoPath: _logoPath.isEmpty ? null : _logoPath,
      footerMessage: _footerCtrl.text,
      showVendorFooter: _showVendorFooter,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isLoading || !_isInitialized) {
      return const AppLoading();
    }

    final readOnly = !_canManage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.mode == SettingsMode.store
                  ? Icons.store_rounded
                  : Icons.print_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode == SettingsMode.store
                      ? 'Store Information'
                      : 'Printer Configuration',
                  style: AppTypography.pageTitle,
                ),
                Text(
                  widget.mode == SettingsMode.store
                      ? 'Manage pharmacy contact details and branding.'
                      : 'Manage receipt hardware, margins, and live preview.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Expanded(
          child: widget.mode == SettingsMode.store
              ? _buildStoreInfoMode(readOnly)
              : _buildPrinterConfigMode(readOnly),
        ),
      ],
    );
  }

  Widget _buildStoreInfoMode(bool readOnly) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            icon: Icons.local_pharmacy_rounded,
            title: 'Pharmacy Details & Logo',
            children: [
              IgnorePointer(
                ignoring: readOnly,
                child: Opacity(
                  opacity: readOnly ? 0.6 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pharmacy Logo',
                          style: AppTypography.subtitle.copyWith(fontSize: 14)),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _logoPath.isNotEmpty &&
                                File(_logoPath).existsSync()
                                ? Image.file(File(_logoPath),
                                fit: BoxFit.contain)
                                : const Icon(Icons.image_outlined,
                                size: 36, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppButton(
                                  label: _logoPath.isEmpty
                                      ? 'Upload Logo'
                                      : 'Change Logo',
                                  icon: Icons.upload_file_outlined,
                                  variant: AppButtonVariant.outlined,
                                  size: AppButtonSize.small,
                                  onPressed: readOnly
                                      ? null
                                      : () async {
                                    final result = await FilePicker
                                        .platform
                                        .pickFiles(
                                      type: FileType.image,
                                      allowMultiple: false,
                                    );
                                    if (result != null &&
                                        result.files.single.path != null) {
                                      setState(() {
                                        _logoPath =
                                        result.files.single.path!;
                                      });
                                    }
                                  },
                                ),
                                if (_logoPath.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  AppButton(
                                    label: 'Remove Logo',
                                    icon: Icons.delete_outline,
                                    variant: AppButtonVariant.ghost,
                                    size: AppButtonSize.small,
                                    onPressed: readOnly
                                        ? null
                                        : () => setState(() => _logoPath = ''),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  'Shown at the top of printed receipts (PNG/JPG recommended).',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      AppTextField(
                        controller: _pharmNameCtrl,
                        label: 'Pharmacy / Store Name',
                        prefixIcon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _pharmPhoneCtrl,
                        label: 'Phone Number',
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _pharmAddrCtrl,
                        label: 'Address',
                        prefixIcon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!readOnly)
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Save Store Information',
                icon: Icons.save_outlined,
                variant: AppButtonVariant.primary,
                onPressed: _save,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrinterConfigMode(bool readOnly) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Configuration Controls
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge, right: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionCard(
                  icon: Icons.print_rounded,
                  title: 'Hardware & Layout',
                  children: [
                    Text('Select Printer',
                        style: AppTypography.subtitle.copyWith(fontSize: 14)),
                    const SizedBox(height: AppSpacing.sm),
                    if (_loadingPrinters)
                      const AppLoading(
                          type: AppLoadingType.spinner,
                          message: 'Detecting printers...')
                    else if (_printers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warning, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'No printers detected. Connect a USB or network printer and click Refresh.',
                                style: AppTypography.bodySmall,
                              ),
                            ),
                            AppButton(
                              label: 'Refresh',
                              variant: AppButtonVariant.outlined,
                              size: AppButtonSize.small,
                              onPressed: _detectPrinters,
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: IgnorePointer(
                              ignoring: readOnly,
                              child: Opacity(
                                opacity: readOnly ? 0.6 : 1.0,
                                child: DropdownButtonFormField<String>(
                                  value: _printers.any(
                                          (p) => p.name == _selectedPrinter)
                                      ? _selectedPrinter
                                      : _printers.first.name,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: _printers.map((p) {
                                    final label = p.isDefault
                                        ? '${p.name} (Default)'
                                        : p.name;
                                    return DropdownMenuItem(
                                        value: p.name, child: Text(label));
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedPrinter = v ?? ''),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            tooltip: 'Refresh printer list',
                            onPressed: _detectPrinters,
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('Thermal Paper Width',
                        style: AppTypography.subtitle.copyWith(fontSize: 14)),
                    const SizedBox(height: AppSpacing.sm),
                    IgnorePointer(
                      ignoring: readOnly,
                      child: Opacity(
                        opacity: readOnly ? 0.6 : 1.0,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            _layoutChip('thermal58', 'Thermal 58mm', Icons.receipt),
                            _layoutChip(
                                'thermal80', 'Thermal 80mm', Icons.receipt_long),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Margin Tuning Sliders (Extended to 15.0 mm) ──
                    Text('Printer Driver Margins (Offset Tuning)',
                        style: AppTypography.subtitle.copyWith(fontSize: 14)),
                    Text(
                      'Compensates for hardware driver padding. Lower Left Margin if text shifts right.',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Left Margin: ${_marginLeftMm.toStringAsFixed(1)} mm',
                                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                              Slider(
                                value: _marginLeftMm.clamp(0.0, 15.0),
                                min: 0.0,
                                max: 15.0, // Extended range to 15mm
                                divisions: 30, // 0.5mm increments
                                label: '${_marginLeftMm.toStringAsFixed(1)} mm',
                                onChanged: readOnly
                                    ? null
                                    : (v) => setState(() => _marginLeftMm = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Right Margin: ${_marginRightMm.toStringAsFixed(1)} mm',
                                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                              Slider(
                                value: _marginRightMm.clamp(0.0, 15.0),
                                min: 0.0,
                                max: 15.0, // Extended range to 15mm
                                divisions: 30, // 0.5mm increments
                                label: '${_marginRightMm.toStringAsFixed(1)} mm',
                                onChanged: readOnly
                                    ? null
                                    : (v) => setState(() => _marginRightMm = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text('Font Size Scale',
                        style: AppTypography.subtitle.copyWith(fontSize: 14)),
                    const SizedBox(height: AppSpacing.sm),
                    IgnorePointer(
                      ignoring: readOnly,
                      child: Opacity(
                        opacity: readOnly ? 0.6 : 1.0,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            _fontScaleChip('0.85', 'Small (85%)'),
                            _fontScaleChip('1.0', 'Normal (100%)'),
                            _fontScaleChip('1.15', 'Large (115%)'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('Receipt Density (Spacing & Details)',
                        style: AppTypography.subtitle.copyWith(fontSize: 14)),
                    const SizedBox(height: AppSpacing.sm),
                    IgnorePointer(
                      ignoring: readOnly,
                      child: Opacity(
                        opacity: readOnly ? 0.6 : 1.0,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _densityChip('standard', 'Standard (Full Info)'),
                            _densityChip('compact', 'Compact (No Payment Breakdown)'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Auto-Print After Sale',
                          style: AppTypography.subtitle.copyWith(fontSize: 14)),
                      subtitle: Text(
                        'Automatically print receipt when a sale is completed at POS.',
                        style: AppTypography.caption,
                      ),
                      value: _autoPrint,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _autoPrint = v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Direct Print (No Dialog)',
                          style: AppTypography.subtitle.copyWith(fontSize: 14)),
                      subtitle: Text(
                        'When Print Receipt is clicked, bypass the Windows popup and print instantly.',
                        style: AppTypography.caption,
                      ),
                      value: _directPrint,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _directPrint = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _sectionCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Receipt Footer',
                  children: [
                    IgnorePointer(
                      ignoring: readOnly,
                      child: Opacity(
                        opacity: readOnly ? 0.6 : 1.0,
                        child: AppTextField(
                          controller: _footerCtrl,
                          label: 'Footer Message',
                          hint: 'e.g. Thank you for your purchase!',
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Show Vendor Footer',
                          style: AppTypography.subtitle.copyWith(fontSize: 14)),
                      subtitle: Text(
                        'Displays "Developed by Ranker Solutions" at the bottom of receipts.',
                        style: AppTypography.caption,
                      ),
                      value: _showVendorFooter,
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _showVendorFooter = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                if (!readOnly)
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'Save Printer Settings',
                      icon: Icons.save_outlined,
                      variant: AppButtonVariant.primary,
                      onPressed: _save,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Right Column: Dynamic Tight Vector PDF Preview
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.preview_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Live Receipt Preview',
                      style: AppTypography.subtitle.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Center(
                  child: Container(
                    width: _selectedLayout == 'thermal58' ? 240 : 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PdfPreview(
                      build: (format) => _generatePreviewPdf(),
                      dpi: 300, // Crisp 300 DPI high-res vector rendering
                      maxPageWidth: _selectedLayout == 'thermal58' ? 220 : 280,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      padding: EdgeInsets.zero,
                      scrollViewDecoration: const BoxDecoration(color: Colors.white),
                      pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(title,
                    style: AppTypography.sectionTitle
                        .copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _layoutChip(String value, String label, IconData icon) {
    final selected = _selectedLayout == value;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 16,
          color: selected ? AppColors.primary : AppColors.textSecondary),
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _selectedLayout = value),
      selectedColor: AppColors.primarySurface,
    );
  }

  Widget _densityChip(String value, String label) {
    final selected = _receiptDensity == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _receiptDensity = value),
      selectedColor: AppColors.primarySurface,
    );
  }

  Widget _fontScaleChip(String value, String label) {
    final selected = _fontScaleChoice == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _fontScaleChoice = value),
      selectedColor: AppColors.primarySurface,
    );
  }
}