import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pharmacy/core/result/result.dart';
import '../../../medicines/data/sqlite_medicine_repository.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../customers/data/sqlite_customer_repository.dart';
import '../../../suppliers/data/sqlite_supplier_repository.dart';

enum GlobalSearchResultType { medicine, customer, supplier }

class GlobalSearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final GlobalSearchResultType type;
  final int targetTabIndex;
  final dynamic rawData;

  GlobalSearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.type,
    required this.targetTabIndex,
    required this.rawData,
  });
}

class GlobalSearchDialog extends StatefulWidget {
  final SqliteMedicineRepository? medicineRepository;
  final SqliteCustomerRepository? customerRepository;
  final SqliteSupplierRepository? supplierRepository;
  final ValueChanged<int>? onSelectTab;

  const GlobalSearchDialog({
    super.key,
    this.medicineRepository,
    this.customerRepository,
    this.supplierRepository,
    this.onSelectTab,
  });

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<GlobalSearchResultItem> _results = [];
  int _selectedIndex = 0;
  bool _isLoading = false;

  Timer? _debounce;
  int _searchGeneration = 0;

  SqliteMedicineRepository get _medicineRepo =>
      widget.medicineRepository ?? SqliteMedicineRepository();

  SqliteCustomerRepository get _customerRepo =>
      widget.customerRepository ?? SqliteCustomerRepository();

  SqliteSupplierRepository get _supplierRepo =>
      widget.supplierRepository ?? SqliteSupplierRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<dynamic> _unwrapResult(dynamic result) {
    if (result == null) return <dynamic>[];
    if (result is List) return result;

    if (result is Result) {
      final value = result.valueOrNull;
      if (value is List) return value;
      return <dynamic>[];
    }

    try {
      final dynamic val = (result as dynamic).value;
      if (val is List) return val;
    } catch (_) {}

    try {
      final dynamic data = (result as dynamic).data;
      if (data is List) return data;
    } catch (_) {}

    return <dynamic>[];
  }

  String _safeString(dynamic obj) {
    if (obj == null) return '';
    try {
      final val = obj.value;
      if (val != null) return val.toString();
    } catch (_) {}
    return obj.toString();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _selectedIndex = 0;
          _isLoading = false;
        });
      }
      return;
    }

    final generation = ++_searchGeneration;
    setState(() => _isLoading = true);

    final List<GlobalSearchResultItem> items = [];

    // ── 1. Search Medicines ──
    try {
      final medResult = await _medicineRepo.getMedicines();
      if (generation == _searchGeneration) {
        final medicines = _unwrapResult(medResult);

        for (final dynamic m in medicines) {
          if (m == null) continue;

          String name = '';
          try { name = m.name; } catch (_) {}

          String generic = '';
          try { generic = m.genericName; } catch (_) {}

          String manufacturer = '';
          try { manufacturer = m.manufacturer; } catch (_) {}

          String barcode = '';
          try { barcode = _safeString(m.barcode); } catch (_) {}

          String rack = '';
          try { rack = m.rackLocation; } catch (_) {}

          String strength = '';
          try { strength = m.strength; } catch (_) {}

          String category = '';
          try { category = m.category; } catch (_) {}

          String dosageLabel = '';
          try { dosageLabel = m.dosageForm.label; } catch (_) {}

          String id = '';
          try { id = m.id.value; } catch (_) {}

          if (name.toLowerCase().contains(trimmed) ||
              generic.toLowerCase().contains(trimmed) ||
              manufacturer.toLowerCase().contains(trimmed) ||
              barcode.toLowerCase().contains(trimmed) ||
              rack.toLowerCase().contains(trimmed) ||
              strength.toLowerCase().contains(trimmed) ||
              category.toLowerCase().contains(trimmed)) {
            items.add(GlobalSearchResultItem(
              id: id,
              title: name,
              subtitle: [
                if (generic.isNotEmpty) generic,
                if (manufacturer.isNotEmpty) manufacturer,
                if (dosageLabel.isNotEmpty) dosageLabel,
                if (strength.isNotEmpty) strength,
                if (rack.isNotEmpty) '📍 Rack: $rack',
              ].join(' • '),
              tag: 'MEDICINE',
              type: GlobalSearchResultType.medicine,
              targetTabIndex: 4,
              rawData: m,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('⚠ GlobalSearch medicine error: $e');
    }

    // ── 2. Search Customers ──
    try {
      final custResult = await _customerRepo.getCustomers(searchQuery: trimmed);
      if (generation == _searchGeneration) {
        final customers = _unwrapResult(custResult);

        for (final dynamic c in customers) {
          if (c == null) continue;

          String name = '';
          String phone = '';
          String id = '';
          String pkr = '0.00';

          dynamic customerObj;
          try { customerObj = c.customer; } catch (_) {}
          customerObj ??= c;

          try { name = customerObj.name; } catch (_) {}
          try { phone = customerObj.phone; } catch (_) {}
          try { id = _safeString(customerObj.id); } catch (_) {}

          try {
            dynamic rawBalance;
            try { rawBalance = c.balance; } catch (_) {}
            num amountInPaisa = 0;
            if (rawBalance != null) {
              try {
                amountInPaisa = rawBalance.paisa;
              } catch (_) {
                try {
                  amountInPaisa = rawBalance.amount;
                } catch (_) {
                  amountInPaisa = num.tryParse(rawBalance.toString()) ?? 0;
                }
              }
            }
            pkr = (amountInPaisa / 100).toStringAsFixed(2);
          } catch (_) {}

          if (name.toLowerCase().contains(trimmed) || phone.toLowerCase().contains(trimmed)) {
            items.add(GlobalSearchResultItem(
              id: id,
              title: name,
              subtitle: 'Phone: $phone • Balance: PKR $pkr',
              tag: 'CUSTOMER',
              type: GlobalSearchResultType.customer,
              targetTabIndex: 5,
              rawData: c,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('⚠ GlobalSearch customer error: $e');
    }

    // ── 3. Search Suppliers ──
    try {
      final suppResult = await _supplierRepo.getSuppliers(searchQuery: trimmed);
      if (generation == _searchGeneration) {
        final suppliers = _unwrapResult(suppResult);

        for (final dynamic s in suppliers) {
          if (s == null) continue;

          String name = '';
          String phone = '';
          String company = '';
          String id = '';
          String pkr = '0.00';

          dynamic supplierObj;
          try { supplierObj = s.supplier; } catch (_) {}
          supplierObj ??= s;

          try { name = supplierObj.name; } catch (_) {}
          try { phone = supplierObj.phone; } catch (_) {}
          try { id = _safeString(supplierObj.id); } catch (_) {}
          try {
            company = supplierObj.companyName ?? supplierObj.company ?? supplierObj.contactPerson ?? '';
          } catch (_) {}

          try {
            dynamic rawBalance;
            try { rawBalance = s.balance; } catch (_) {}
            num amountInPaisa = 0;
            if (rawBalance != null) {
              try {
                amountInPaisa = rawBalance.paisa;
              } catch (_) {
                try {
                  amountInPaisa = rawBalance.amount;
                } catch (_) {
                  amountInPaisa = num.tryParse(rawBalance.toString()) ?? 0;
                }
              }
            }
            pkr = (amountInPaisa / 100).toStringAsFixed(2);
          } catch (_) {}

          if (name.toLowerCase().contains(trimmed) || phone.toLowerCase().contains(trimmed)) {
            items.add(GlobalSearchResultItem(
              id: id,
              title: name,
              subtitle: [
                if (company.isNotEmpty) company,
                'Phone: $phone',
                'Balance: PKR $pkr',
              ].join(' • '),
              tag: 'SUPPLIER',
              type: GlobalSearchResultType.supplier,
              targetTabIndex: 6,
              rawData: s,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('⚠ GlobalSearch supplier error: $e');
    }

    if (mounted && generation == _searchGeneration) {
      setState(() {
        _results = items;
        _selectedIndex = 0;
        _isLoading = false;
      });
    }
  }

  void _handleSelect(GlobalSearchResultItem item) {
    widget.onSelectTab?.call(item.targetTabIndex);
    Navigator.of(context).pop();
  }

  void _onKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _results.length;
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _results.length) % _results.length;
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_results.isNotEmpty && _selectedIndex < _results.length) {
        _handleSelect(_results[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  Color _getTagColor(GlobalSearchResultType type) {
    switch (type) {
      case GlobalSearchResultType.medicine:
        return const Color(0xFF0EA5E9);
      case GlobalSearchResultType.customer:
        return const Color(0xFF10B981);
      case GlobalSearchResultType.supplier:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getTagIcon(GlobalSearchResultType type) {
    switch (type) {
      case GlobalSearchResultType.medicine:
        return Icons.medication_outlined;
      case GlobalSearchResultType.customer:
        return Icons.person_outline_rounded;
      case GlobalSearchResultType.supplier:
        return Icons.local_shipping_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _onKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        color: Color(0xFF64748B), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                          'Search medicines, customers, suppliers... (Ctrl+K)',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: const Color(0xFF64748B),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                  child: Text(
                    _searchController.text.trim().isEmpty
                        ? 'Type to search across all pharmacy records'
                        : 'No matching records found',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                )
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    final isSelected = index == _selectedIndex;
                    final tagColor = _getTagColor(item.type);

                    return InkWell(
                      onTap: () => _handleSelect(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF1F5F9)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0EA5E9)
                                  : Colors.transparent,
                              width: 4,
                            ),
                            bottom: const BorderSide(
                              color: Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getTagIcon(item.type),
                                      size: 14, color: tagColor),
                                  const SizedBox(width: 4),
                                  Text(item.tag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: tagColor,
                                      )),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      )),
                                  const SizedBox(height: 2),
                                  Text(item.subtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Navigate',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                    SizedBox(width: 16),
                    Icon(Icons.keyboard_return_rounded,
                        size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Select',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                    SizedBox(width: 16),
                    Text('ESC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        )),
                    SizedBox(width: 4),
                    Text('Dismiss',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}