import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../accounts/domain/account.dart';
import '../../../medicines/data/sqlite_medicine_repository.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../medicines/domain/medicine_repository.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../../suppliers/data/sqlite_supplier_repository.dart';
import '../../../suppliers/domain/supplier.dart';
import '../../domain/purchase.dart';
import '../controllers/purchase_controller.dart';

class PurchaseFormDialog extends StatefulWidget {
  final PurchaseController controller;
  final List<AccountWithBalance> accounts;

  const PurchaseFormDialog({
    super.key,
    required this.controller,
    this.accounts = const [],
  });

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final SqliteMedicineRepository _medicineRepo = SqliteMedicineRepository();
  final SqliteSupplierRepository _supplierRepo = SqliteSupplierRepository();

  final _invoiceNumCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController(text: '0.00');

  final _medSearchCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _purPriceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _selPriceCtrl = TextEditingController();

  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  Medicine? _selectedMedicine;
  List<Medicine> _searchResults = [];
  bool _isSearchingMed = false;

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _loadingSuppliers = true;
  String? _accountId;

  final List<PurchaseItem> _addedItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _invoiceNumCtrl.text = PurchaseInvoiceNumber.generate().value;
    _loadSuppliers();
  }

  @override
  void dispose() {
    _invoiceNumCtrl.dispose();
    _discountCtrl.dispose();
    _amountPaidCtrl.dispose();
    _medSearchCtrl.dispose();
    _batchCtrl.dispose();
    _qtyCtrl.dispose();
    _purPriceCtrl.dispose();
    _mrpCtrl.dispose();
    _selPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loadingSuppliers = true);
    final result = await _supplierRepo.getSuppliers();
    result.fold(
      onSuccess: (list) {
        if (!mounted) return;
        final active = list
            .map((s) => s.supplier)
            .where((s) => s.status == SupplierStatus.active)
            .toList();
        final all = list.map((s) => s.supplier).toList();
        setState(() {
          _suppliers = active.isNotEmpty ? active : all;
          _loadingSuppliers = false;
          _selectedSupplier = null;
        });
      },
      onFailure: (_) {
        if (mounted) setState(() => _loadingSuppliers = false);
      },
    );
  }

  Future<void> _searchMedicines(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingMed = false;
      });
      return;
    }

    setState(() => _isSearchingMed = true);

    final res = await _medicineRepo.getMedicines(
      filter: MedicineFilter(searchQuery: query.trim()),
    );

    res.fold(
      onSuccess: (list) {
        if (mounted) {
          setState(() {
            _searchResults = list;
            _isSearchingMed = false;
          });
        }
      },
      onFailure: (_) {
        if (mounted) setState(() => _isSearchingMed = false);
      },
    );
  }

  void _selectMedicine(Medicine med) {
    final costStr = med.effectivePurchasePrice.pkr > 0
        ? med.effectivePurchasePrice.pkr.toStringAsFixed(2)
        : '';
    final sellStr = med.effectiveSellingPrice.pkr > 0
        ? med.effectiveSellingPrice.pkr.toStringAsFixed(2)
        : '';

    setState(() {
      _selectedMedicine = med;
      _medSearchCtrl.text = '${med.name} (${med.strength})';
      _searchResults = [];
      _purPriceCtrl.text = costStr;
      _mrpCtrl.text = sellStr;
      _selPriceCtrl.text = sellStr;
    });
  }

  void _clearMedicineSelection() {
    setState(() {
      _selectedMedicine = null;
      _medSearchCtrl.clear();
      _searchResults = [];
      _purPriceCtrl.clear();
      _mrpCtrl.clear();
      _selPriceCtrl.clear();
    });
  }

  void _onMrpChanged(String value) {
    if (_selPriceCtrl.text.isEmpty || _selPriceCtrl.text == _mrpCtrl.text) {
      _selPriceCtrl.text = value;
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _syncPaidAmount() {
    _amountPaidCtrl.text =
        Money.fromPaisa(_grandTotalPaisa).pkr.toStringAsFixed(2);
  }

  void _addItemToInvoice() {
    if (_selectedMedicine == null) {
      AppToast.error(
        context,
        'Please search and select a medicine from catalog.',
      );
      return;
    }

    final batchNum = _batchCtrl.text.trim();
    if (batchNum.isEmpty) {
      AppToast.error(context, 'Please enter a batch number.');
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      AppToast.error(context, 'Procured quantity must be greater than 0.');
      return;
    }

    final purCostVal = double.tryParse(_purPriceCtrl.text.trim()) ?? 0.0;
    final mrpVal = double.tryParse(_mrpCtrl.text.trim()) ?? 0.0;
    final selPriceVal = double.tryParse(_selPriceCtrl.text.trim()) ?? mrpVal;

    if (mrpVal <= 0) {
      AppToast.error(context, 'MRP is required and must be greater than 0.');
      return;
    }

    final purchasePrice = Money.fromPkr(purCostVal);
    final mrp = Money.fromPkr(mrpVal);
    final sellingPrice = Money.fromPkr(selPriceVal);
    final lineTotal = Money.fromPaisa(purchasePrice.paisa * qty);

    final item = PurchaseItem(
      id: 'p_item_${DateTime.now().microsecondsSinceEpoch}',
      medicineId: _selectedMedicine!.id,
      medicineName: _selectedMedicine!.name,
      batchNumber: batchNum,
      expiryDate: _expiryDate,
      quantity: qty,
      purchasePrice: purchasePrice,
      mrp: mrp,
      sellingPrice: sellingPrice,
      lineTotal: lineTotal,
    );

    setState(() {
      _addedItems.add(item);
      _clearMedicineSelection();
      _batchCtrl.clear();
      _qtyCtrl.clear();
      _syncPaidAmount();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _addedItems.removeAt(index);
      _syncPaidAmount();
    });
  }

  int get _subtotalPaisa =>
      _addedItems.fold(0, (sum, item) => sum + item.lineTotal.paisa);

  int get _discountPaisa =>
      Money.fromPkr(double.tryParse(_discountCtrl.text.trim()) ?? 0.0).paisa;

  int get _grandTotalPaisa {
    final total = _subtotalPaisa - _discountPaisa;
    return total < 0 ? 0 : total;
  }

  Future<void> _submitInvoice() async {
    if (_selectedSupplier == null) {
      AppToast.error(
        context,
        _suppliers.isEmpty
            ? 'Add a supplier from the Suppliers tab first.'
            : 'Please select a supplier from the list.',
      );
      return;
    }

    if (_addedItems.isEmpty) {
      AppToast.error(
        context,
        'Please add at least one medicine item to invoice.',
      );
      return;
    }

    final paidVal = double.tryParse(_amountPaidCtrl.text.trim()) ?? 0.0;
    final amountPaidPaisa = Money.fromPkr(paidVal).paisa;

    if (amountPaidPaisa > 0 && (_accountId == null || _accountId!.isEmpty)) {
      AppToast.error(
        context,
        'Please select a Pay From Account or set Amount Paid to 0 for credit.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final pId = PurchaseId.generate();
    final invNum = _invoiceNumCtrl.text.trim().isNotEmpty
        ? PurchaseInvoiceNumber(_invoiceNumCtrl.text.trim())
        : PurchaseInvoiceNumber.generate();

    final purchase = Purchase(
      id: pId,
      invoiceNumber: invNum,
      supplierName: _selectedSupplier!.name,
      items: List.from(_addedItems),
      subtotal: Money.fromPaisa(_subtotalPaisa),
      discount: Money.fromPaisa(_discountPaisa),
      grandTotal: Money.fromPaisa(_grandTotalPaisa),
      createdAt: now,
      updatedAt: now,
    );

    final error = await widget.controller.receivePurchase(
      purchase,
      accountId: _accountId,
      amountPaidPaisa: amountPaidPaisa,
    );

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(error);
  }

  Widget _buildSupplierField() {
    if (_loadingSuppliers) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Supplier',
          prefixIcon: Icon(Icons.local_shipping_outlined),
        ),
        child: Text('Loading suppliers...'),
      );
    }

    if (_suppliers.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Supplier',
          prefixIcon: Icon(Icons.local_shipping_outlined),
          errorText: 'No suppliers on file',
          helperText: 'Go to Suppliers tab → Add Supplier, then return here.',
        ),
        child: Text(
          'None available',
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return Autocomplete<Supplier>(
      displayStringForOption: (s) => s.name,
      optionsBuilder: (TextEditingValue tev) {
        final q = tev.text.trim().toLowerCase();
        if (q.isEmpty) return _suppliers;
        return _suppliers.where((s) {
          return s.name.toLowerCase().contains(q) ||
              s.contactPerson.toLowerCase().contains(q) ||
              s.phone.toLowerCase().contains(q);
        });
      },
      onSelected: (s) => setState(() => _selectedSupplier = s),
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (_selectedSupplier != null &&
            textController.text != _selectedSupplier!.name) {
          textController.text = _selectedSupplier!.name;
        }
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Supplier',
            hintText: 'Type to search suppliers...',
            prefixIcon: const Icon(Icons.local_shipping_outlined),
            suffixIcon: _selectedSupplier != null
                ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: () {
                textController.clear();
                setState(() => _selectedSupplier = null);
              },
            )
                : const Icon(Icons.arrow_drop_down_rounded),
            helperText: _selectedSupplier == null
                ? 'Select an existing supplier (add new ones under Suppliers).'
                : '${_selectedSupplier!.contactPerson.isEmpty ? '' : _selectedSupplier!.contactPerson}'
                '${_selectedSupplier!.phone.isEmpty ? '' : ' · ${_selectedSupplier!.phone}'}',
          ),
          onChanged: (value) {
            if (_selectedSupplier != null &&
                value.trim() != _selectedSupplier!.name) {
              setState(() => _selectedSupplier = null);
            }
          },
          validator: (_) {
            if (_selectedSupplier == null) {
              return 'Select a supplier from the list';
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.business_rounded, size: 20),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if (s.contactPerson.isNotEmpty) s.contactPerson,
                        if (s.phone.isNotEmpty) s.phone,
                      ].join(' · '),
                      style: AppTypography.caption,
                    ),
                    onTap: () => onSelected(s),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Receive Stock Purchase Invoice',
                    style: AppTypography.sectionTitle,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed:
                    _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildSupplierField()),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _invoiceNumCtrl,
                              label: 'Invoice #',
                              isRequired: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Add Medicine to Invoice',
                        style: AppTypography.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Stack(
                        children: [
                          TextFormField(
                            controller: _medSearchCtrl,
                            decoration: InputDecoration(
                              labelText: 'Search Medicine Catalog',
                              hintText:
                              'Type name or generic (e.g. Panadol, Augmentin)...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _selectedMedicine != null
                                  ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                ),
                                onPressed: _clearMedicineSelection,
                              )
                                  : null,
                            ),
                            onChanged: _searchMedicines,
                          ),
                          if (_isSearchingMed)
                            const Positioned(
                              right: 12,
                              top: 14,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final med = _searchResults[idx];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${med.name} ${med.strength}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Generic: ${med.genericName} | Form: ${med.dosageForm.label}',
                                  style: AppTypography.bodySmall,
                                ),
                                trailing: Text(
                                  'Cost: ${med.effectivePurchasePrice.display} | MRP: ${med.effectiveSellingPrice.display}',
                                  style: AppTypography.numeric,
                                ),
                                onTap: () => _selectMedicine(med),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _batchCtrl,
                              label: 'Batch #',
                              hint: 'BN-2025-01',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: _pickExpiry,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expiry Date',
                                ),
                                child: Text(
                                  '${_expiryDate.day.toString().padLeft(2, '0')}/'
                                      '${_expiryDate.month.toString().padLeft(2, '0')}/'
                                      '${_expiryDate.year}',
                                  style: AppTypography.body,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _qtyCtrl,
                              label: 'Units (Qty)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _purPriceCtrl,
                              label: 'Unit Cost (TP)',
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _mrpCtrl,
                              label: 'MRP (Box)',
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: _onMrpChanged,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _selPriceCtrl,
                              label: 'Sell Price',
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: AppButton(
                              label: 'Add',
                              icon: Icons.add_rounded,
                              variant: AppButtonVariant.primary,
                              onPressed: _addItemToInvoice,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Invoice Line Items (${_addedItems.length})',
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 120,
                          maxHeight: 220,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _addedItems.isEmpty
                            ? Center(
                          child: Text(
                            'No items added yet. Search medicine above and click "Add".',
                            style: AppTypography.bodySmall,
                          ),
                        )
                            : SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 40,
                            horizontalMargin: AppSpacing.md,
                            columnSpacing: AppSpacing.sm,
                            columns: const [
                              DataColumn(label: Text('Medicine')),
                              DataColumn(label: Text('Batch #')),
                              DataColumn(label: Text('Expiry')),
                              DataColumn(
                                label: Text('Qty'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('Unit Cost'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('MRP'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('Sell Price'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('Total Cost'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('')),
                            ],
                            rows: _addedItems.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final expStr =
                                  '${item.expiryDate.month.toString().padLeft(2, '0')}/${item.expiryDate.year}';
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      item.medicineName,
                                      style: AppTypography.tableCell,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.batchNumber,
                                      style: AppTypography.tableCell,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      expStr,
                                      style: AppTypography.tableCell,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${item.quantity}',
                                      style: AppTypography.numeric,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.purchasePrice.display,
                                      style: AppTypography.numeric,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.mrp.display,
                                      style: AppTypography.numeric,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.sellingPrice.display,
                                      style: AppTypography.numeric,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.lineTotal.display,
                                      style: AppTypography.numeric
                                          .copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Ledger / Financials ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.accounts.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String?>(
                                value: _accountId,
                                decoration: const InputDecoration(
                                  labelText: 'Pay From Account',
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('— None (On Credit) —'),
                                  ),
                                  ...widget.accounts.map(
                                        (awb) => DropdownMenuItem<String?>(
                                      value: awb.account.id.value,
                                      // AccountWithBalance has no .balance — name only
                                      child: Text(awb.account.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _accountId = v),
                              ),
                            )
                          else
                            const Expanded(flex: 2, child: SizedBox.shrink()),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _amountPaidCtrl,
                              label: 'Amount Paid (PKR)',
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _discountCtrl,
                              label: 'Discount (PKR)',
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _syncPaidAmount();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Subtotal: ${Money.fromPaisa(_subtotalPaisa).display}',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Grand Total: ${Money.fromPaisa(_grandTotalPaisa).display}',
                                style: AppTypography.sectionTitle.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                    onPressed:
                    _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Save & Receive Stock',
                    variant: AppButtonVariant.primary,
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _submitInvoice,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}