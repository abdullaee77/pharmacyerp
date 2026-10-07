import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/pos_cart_controller.dart';
import 'package:pharmacy/features/sales/domain/pos_models.dart';

class PosSearchPanel extends StatefulWidget {
  final PosCartController controller;
  final ValueChanged<PosSearchResult> onMedicineSelected;
  final FocusNode? focusNode;
  final TextEditingController? textController;

  const PosSearchPanel({
    super.key,
    required this.controller,
    required this.onMedicineSelected,
    this.focusNode,
    this.textController,
  });

  @override
  State<PosSearchPanel> createState() => _PosSearchPanelState();
}

class _PosSearchPanelState extends State<PosSearchPanel> {
  late TextEditingController _searchCtrl;
  late FocusNode _searchFocus;
  bool _internalCtrl = false;
  bool _internalFocus = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.textController != null) {
      _searchCtrl = widget.textController!;
    } else {
      _searchCtrl = TextEditingController();
      _internalCtrl = true;
    }

    if (widget.focusNode != null) {
      _searchFocus = widget.focusNode!;
    } else {
      _searchFocus = FocusNode();
      _internalFocus = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    if (_internalCtrl) _searchCtrl.dispose();
    if (_internalFocus) _searchFocus.dispose();
    super.dispose();
  }

  void _selectItem(PosSearchResult item) {
    widget.onMedicineSelected(item);
    _clear();
  }

  void _clear() {
    _searchCtrl.clear();
    widget.controller.search('');
    if (mounted) {
      setState(() => _showResults = false);
    }
    _searchFocus.requestFocus();
  }

  void _onSubmitted(String value) {
    if (widget.controller.searchResults.isNotEmpty) {
      _selectItem(widget.controller.searchResults.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layout container with outer background/border/shadow completely removed
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Search Medicine Name, Generic, or Manufacturer [F2] (Press Enter to add first match)',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                splashRadius: 16,
                onPressed: _clear,
              ),
              filled: true,
              fillColor: AppColors.surface,
              // Strictly using clean, native OutlineInputBorders on the TextField itself
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (v) {
              final trimmed = v.trim();
              widget.controller.search(trimmed);
              if (mounted) {
                setState(() => _showResults = trimmed.isNotEmpty);
              }
            },
            onSubmitted: _onSubmitted,
          ),
        ),

        // Results Dropdown
        if (_showResults && _searchCtrl.text.trim().isNotEmpty) _buildRichResultsList(),
      ],
    );
  }

  Widget _buildRichResultsList() {
    final ctrl = widget.controller;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: ctrl.isSearching
          ? const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      )
          : ctrl.searchResults.isEmpty
          ? Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('No medicines match "${_searchCtrl.text}".', style: AppTypography.bodySmall),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Medicine', style: AppTypography.tableHeader)),
                Expanded(flex: 1, child: Text('Box Size', style: AppTypography.tableHeader, textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Stock', style: AppTypography.tableHeader, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Piece Price', style: AppTypography.tableHeader, textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Box Price', style: AppTypography.tableHeader, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ctrl.searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = ctrl.searchResults[i];
                final m = item.medicine;
                final isOutOfStock = item.currentStock <= 0;

                return Material(
                  color: isOutOfStock
                      ? AppColors.errorSurface.withValues(alpha: 0.3)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectItem(item),
                    hoverColor: AppColors.primarySurface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: AppTypography.subtitle.copyWith(fontSize: 14)),
                                Text(
                                  m.genericName.isNotEmpty
                                      ? '${m.genericName} ${m.strength}'
                                      : m.strength,
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('${m.boxSize}s', textAlign: TextAlign.center, style: AppTypography.bodySmall),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.currentStock}',
                              textAlign: TextAlign.center,
                              style: AppTypography.numeric.copyWith(
                                color: isOutOfStock ? AppColors.error : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(m.sellingPrice.display, textAlign: TextAlign.right, style: AppTypography.numericSmall),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              m.boxPrice.display,
                              textAlign: TextAlign.right,
                              style: AppTypography.numericSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}