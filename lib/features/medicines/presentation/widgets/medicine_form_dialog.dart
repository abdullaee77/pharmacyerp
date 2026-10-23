import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/medicine.dart';
import '../../domain/value_objects.dart';

class OpeningStockInfo {
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;

  const OpeningStockInfo({
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
  });
}

class MedicineCreationResult {
  final Medicine medicine;
  final OpeningStockInfo? openingStock;

  const MedicineCreationResult({
    required this.medicine,
    this.openingStock,
  });
}

class MedicineFormDialog extends StatefulWidget {
  final Medicine? medicine;
  final List<String> existingCategories;
  final List<String> existingManufacturers;

  const MedicineFormDialog({
    super.key,
    this.medicine,
    this.existingCategories = const [],
    this.existingManufacturers = const [],
  });

  @override
  State<MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  late final TextEditingController _nameCtrl;
  late final TextEditingController _genericCtrl;
  late final TextEditingController _strengthCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _manufacturerCtrl;
  late final TextEditingController _barcodeCtrl;

  // Category & Manufacturer Selection Mode
  late String? _selectedCategoryDropdown;
  late bool _isCustomCategory;
  late String? _selectedManufacturerDropdown;
  late bool _isCustomManufacturer;

  // Classification
  late DosageForm _dosageForm;
  late DrugSchedule _drugSchedule;
  late bool _prescriptionRequired;
  late MedicineStatus _status;

  // Pricing & Stock Thresholds
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _mrpCtrl;
  late final TextEditingController _boxSizeCtrl;
  late final TextEditingController _boxPriceCtrl;
  late final TextEditingController _minStockCtrl;
  late String _unit;

  // Storage
  late final TextEditingController _rackCtrl;
  late final TextEditingController _storageCtrl;

  bool get _isEditing => widget.medicine != null;

  static const _units = [
    'Tab',
    'Cap',
    'ml',
    'mg',
    'g',
    'Sachet',
    'Tube',
    'Bottle',
    'Box',
    'Piece',
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    final initialCat = m?.category ?? '';
    final initialMfr = m?.manufacturer ?? '';

    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _genericCtrl = TextEditingController(text: m?.genericName ?? '');
    _strengthCtrl = TextEditingController(text: m?.strength ?? '');
    _categoryCtrl = TextEditingController(text: initialCat);
    _manufacturerCtrl = TextEditingController(text: initialMfr);
    _barcodeCtrl = TextEditingController(text: m?.barcode?.value ?? '');

    // Setup Category selection logic
    if (initialCat.isNotEmpty && widget.existingCategories.contains(initialCat)) {
      _selectedCategoryDropdown = initialCat;
      _isCustomCategory = false;
    } else if (initialCat.isNotEmpty) {
      _selectedCategoryDropdown = '__custom__';
      _isCustomCategory = true;
    } else {
      _selectedCategoryDropdown = widget.existingCategories.isNotEmpty ? widget.existingCategories.first : '__custom__';
      _isCustomCategory = widget.existingCategories.isEmpty;
      if (!_isCustomCategory && _selectedCategoryDropdown != null) {
        _categoryCtrl.text = _selectedCategoryDropdown!;
      }
    }

    // Setup Manufacturer selection logic
    if (initialMfr.isNotEmpty && widget.existingManufacturers.contains(initialMfr)) {
      _selectedManufacturerDropdown = initialMfr;
      _isCustomManufacturer = false;
    } else if (initialMfr.isNotEmpty) {
      _selectedManufacturerDropdown = '__custom__';
      _isCustomManufacturer = true;
    } else {
      _selectedManufacturerDropdown = widget.existingManufacturers.isNotEmpty ? widget.existingManufacturers.first : '__custom__';
      _isCustomManufacturer = widget.existingManufacturers.isEmpty;
      if (!_isCustomManufacturer && _selectedManufacturerDropdown != null) {
        _manufacturerCtrl.text = _selectedManufacturerDropdown!;
      }
    }

    _dosageForm = m?.dosageForm ?? DosageForm.tablet;
    _drugSchedule = m?.drugSchedule ?? DrugSchedule.none;
    _prescriptionRequired = m?.prescriptionRequired ?? false;
    _status = m?.status ?? MedicineStatus.active;

    _purchasePriceCtrl = TextEditingController(
      text: m != null ? m.purchasePrice.pkr.toStringAsFixed(2) : '',
    );
    _sellingPriceCtrl = TextEditingController(
      text: m != null ? m.sellingPrice.pkr.toStringAsFixed(2) : '',
    );
    _mrpCtrl = TextEditingController(
      text: m != null ? m.mrp.pkr.toStringAsFixed(2) : '',
    );
    _boxSizeCtrl = TextEditingController(
      text: m != null ? '${m.boxSize}' : '1',
    );
    _boxPriceCtrl = TextEditingController(
      text: m != null && m.boxPrice.paisa > 0
          ? m.boxPrice.pkr.toStringAsFixed(2)
          : '',
    );
    _minStockCtrl = TextEditingController(
      text: m != null ? '${m.minStockLevel.value}' : '10',
    );
    _unit = m?.unit ?? 'Tab';

    _rackCtrl = TextEditingController(text: m?.rackLocation ?? '');
    _storageCtrl = TextEditingController(text: m?.storageInstructions ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genericCtrl.dispose();
    _strengthCtrl.dispose();
    _categoryCtrl.dispose();
    _manufacturerCtrl.dispose();
    _barcodeCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _mrpCtrl.dispose();
    _boxSizeCtrl.dispose();
    _boxPriceCtrl.dispose();
    _minStockCtrl.dispose();
    _rackCtrl.dispose();
    _storageCtrl.dispose();
    super.dispose();
  }

  double _parsePkr(String text) => double.tryParse(text.trim()) ?? 0.0;
  int _parseInt(String text) => int.tryParse(text.trim()) ?? 0;

  void _autoCalcFromBox() {
    final boxPrice = _parsePkr(_boxPriceCtrl.text);
    final boxSize = _parseInt(_boxSizeCtrl.text);
    if (boxPrice > 0 && boxSize > 0) {
      final unitPrice = boxPrice / boxSize;
      _sellingPriceCtrl.text = unitPrice.toStringAsFixed(2);
    }
  }

  void _autoCalcFromUnit() {
    final unitPrice = _parsePkr(_sellingPriceCtrl.text);
    final boxSize = _parseInt(_boxSizeCtrl.text);
    if (unitPrice > 0 && boxSize > 0) {
      final boxPrice = unitPrice * boxSize;
      _boxPriceCtrl.text = boxPrice.toStringAsFixed(2);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final m = widget.medicine;
    final bCode = _barcodeCtrl.text.trim();

    final medicine = Medicine(
      id: m?.id ?? MedicineId.generate(),
      name: _nameCtrl.text.trim(),
      genericName: _genericCtrl.text.trim(),
      manufacturer: _manufacturerCtrl.text.trim(),
      dosageForm: _dosageForm,
      strength: _strengthCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      unit: _unit,
      rackLocation: _rackCtrl.text.trim(),
      drugSchedule: _drugSchedule,
      storageInstructions: _storageCtrl.text.trim(),
      barcode: bCode.isNotEmpty ? Barcode.unsafe(bCode) : null,
      prescriptionRequired: _prescriptionRequired,
      minStockLevel: Quantity.create(_parseInt(_minStockCtrl.text)),
      purchasePrice: Money.fromPkr(_parsePkr(_purchasePriceCtrl.text)),
      sellingPrice: Money.fromPkr(_parsePkr(_sellingPriceCtrl.text)),
      mrp: Money.fromPkr(_parsePkr(_mrpCtrl.text)),
      boxSize: _parseInt(_boxSizeCtrl.text) > 0 ? _parseInt(_boxSizeCtrl.text) : 1,
      boxPrice: Money.fromPkr(_parsePkr(_boxPriceCtrl.text)),
      status: _status,
      createdAt: m?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(MedicineCreationResult(
      medicine: medicine,
      openingStock: null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit_rounded : Icons.medication_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEditing ? 'Edit Medicine' : 'Add New Medicine',
                    style: AppTypography.pageTitle.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                        'Basic Information',
                        Icons.info_outline,
                        AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSectionCard([
                        _field('Medicine Name *', _nameCtrl, required: true),
                        _field('Generic Name', _genericCtrl),
                        Row(
                          children: [
                            Expanded(
                              child: _field('Strength', _strengthCtrl, hint: 'e.g. 500mg'),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _field('Barcode', _barcodeCtrl, hint: 'Scan or type'),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Category Hybrid Selector
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _selectedCategoryDropdown,
                                    decoration: _decoration('Category'),
                                    items: [
                                      ...widget.existingCategories.map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      )),
                                      const DropdownMenuItem(
                                        value: '__custom__',
                                        child: Text('+ Add Custom Category...'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCategoryDropdown = val;
                                        if (val == '__custom__') {
                                          _isCustomCategory = true;
                                          _categoryCtrl.clear();
                                        } else if (val != null) {
                                          _isCustomCategory = false;
                                          _categoryCtrl.text = val;
                                        }
                                      });
                                    },
                                  ),
                                  if (_isCustomCategory) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    TextFormField(
                                      controller: _categoryCtrl,
                                      decoration: _decoration('Type Custom Category'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            // ✅ Manufacturer Hybrid Selector
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _selectedManufacturerDropdown,
                                    decoration: _decoration('Manufacturer / Company'),
                                    items: [
                                      ...widget.existingManufacturers.map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      )),
                                      const DropdownMenuItem(
                                        value: '__custom__',
                                        child: Text('+ Add Custom Manufacturer...'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedManufacturerDropdown = val;
                                        if (val == '__custom__') {
                                          _isCustomManufacturer = true;
                                          _manufacturerCtrl.clear();
                                        } else if (val != null) {
                                          _isCustomManufacturer = false;
                                          _manufacturerCtrl.text = val;
                                        }
                                      });
                                    },
                                  ),
                                  if (_isCustomManufacturer) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    TextFormField(
                                      controller: _manufacturerCtrl,
                                      decoration: _decoration('Type Custom Manufacturer'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.lg),
                      _buildSectionHeader(
                        'Drug Classification',
                        Icons.science_outlined,
                        AppColors.info,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSectionCard([
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<DosageForm>(
                                value: _dosageForm,
                                decoration: _decoration('Dosage Form'),
                                items: DosageForm.values
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                                    .toList(),
                                onChanged: (v) => setState(() => _dosageForm = v!),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: DropdownButtonFormField<DrugSchedule>(
                                value: _drugSchedule,
                                decoration: _decoration('Drug Schedule'),
                                items: DrugSchedule.values
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                                    .toList(),
                                onChanged: (v) => setState(() => _drugSchedule = v!),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _unit,
                                decoration: _decoration('Unit'),
                                items: _units
                                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) => setState(() => _unit = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: SwitchListTile(
                                  value: _prescriptionRequired,
                                  onChanged: (v) => setState(() => _prescriptionRequired = v),
                                  title: Text('Prescription Required', style: AppTypography.body),
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: AppColors.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonFormField<MedicineStatus>(
                                value: _status,
                                decoration: _decoration('Catalog Status'),
                                items: MedicineStatus.values
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                                    .toList(),
                                onChanged: (v) => setState(() => _status = v!),
                              ),
                            ),
                          ],
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.lg),
                      _buildSectionHeader(
                        'Pricing & Packaging',
                        Icons.currency_exchange_rounded,
                        AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSectionCard([
                        Row(
                          children: [
                            Expanded(child: _priceField('Purchase Price (PKR)', _purchasePriceCtrl)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _priceField(
                                'Selling Price (PKR)',
                                _sellingPriceCtrl,
                                onChanged: (_) => _autoCalcFromUnit(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _priceField('MRP (PKR)', _mrpCtrl)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _boxSizeCtrl,
                                decoration: _decoration('Box Size (pieces)'),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _autoCalcFromBox(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _priceField(
                                'Box Price (PKR)',
                                _boxPriceCtrl,
                                onChanged: (_) => _autoCalcFromBox(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _minStockCtrl,
                                decoration: _decoration('Min Alert Threshold', hint: 'e.g. 10'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.lg),
                      _buildSectionHeader(
                        'Storage & Location',
                        Icons.warehouse_outlined,
                        AppColors.warning,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSectionCard([
                        Row(
                          children: [
                            Expanded(child: _field('Rack / Shelf Location', _rackCtrl, hint: 'e.g. A-3')),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _field('Storage Instructions', _storageCtrl, hint: 'e.g. Keep below 25°C')),
                          ],
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
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
                    label: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: _isEditing ? 'Save Changes' : 'Add Medicine',
                    icon: _isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.subtitle.copyWith(color: color)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _field(
      String label,
      TextEditingController ctrl, {
        bool required = false,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: ctrl,
        decoration: _decoration(label, hint: hint),
        validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
      ),
    );
  }

  Widget _priceField(
      String label,
      TextEditingController ctrl, {
        ValueChanged<String>? onChanged,
      }) {
    return TextFormField(
      controller: ctrl,
      decoration: _decoration(label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}