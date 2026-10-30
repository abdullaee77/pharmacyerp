// import 'package:flutter/material.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../core/theme/app_radius.dart';
// import '../../../../core/theme/app_spacing.dart';
// import '../../../../core/theme/app_typography.dart';
// import '../controllers/pos_cart_controller.dart';
// import 'package:pharmacy/features/sales/domain/pos_models.dart';
//
// class PosSearchPanel extends StatefulWidget {
//   final PosCartController controller;
//   final ValueChanged<PosSearchResult> onMedicineSelected;
//   final FocusNode? focusNode;
//   final TextEditingController? textController;
//
//   const PosSearchPanel({
//     super.key,
//     required this.controller,
//     required this.onMedicineSelected,
//     this.focusNode,
//     this.textController,
//   });
//
//   @override
//   State<PosSearchPanel> createState() => _PosSearchPanelState();
// }
//
// class _PosSearchPanelState extends State<PosSearchPanel> {
//   late TextEditingController _searchCtrl;
//   late FocusNode _searchFocus;
//   bool _internalCtrl = false;
//   bool _internalFocus = false;
//   bool _showResults = false;
//
//   @override
//   void initState() {
//     super.initState();
//     if (widget.textController != null) {
//       _searchCtrl = widget.textController!;
//     } else {
//       _searchCtrl = TextEditingController();
//       _internalCtrl = true;
//     }
//
//     if (widget.focusNode != null) {
//       _searchFocus = widget.focusNode!;
//     } else {
//       _searchFocus = FocusNode();
//       _internalFocus = true;
//     }
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _searchFocus.requestFocus();
//     });
//   }
//
//   @override
//   void dispose() {
//     if (_internalCtrl) _searchCtrl.dispose();
//     if (_internalFocus) _searchFocus.dispose();
//     super.dispose();
//   }
//
//   void _selectItem(PosSearchResult item) {
//     widget.onMedicineSelected(item);
//     _clear();
//   }
//
//   void _clear() {
//     _searchCtrl.clear();
//     widget.controller.search('');
//     if (mounted) {
//       setState(() => _showResults = false);
//     }
//     _searchFocus.requestFocus();
//   }
//
//   void _onSubmitted(String value) {
//     if (widget.controller.searchResults.isNotEmpty) {
//       _selectItem(widget.controller.searchResults.first);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
//           child: TextField(
//             controller: _searchCtrl,
//             focusNode: _searchFocus,
//             decoration: InputDecoration(
//               hintText: 'Search Name, Generic, Formula, or Manufacturer [F2] (Enter to add first)',
//               prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
//               isDense: true,
//               contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//               suffixIcon: _searchCtrl.text.isEmpty
//                   ? null
//                   : IconButton(
//                 icon: const Icon(Icons.close_rounded, size: 18),
//                 splashRadius: 16,
//                 onPressed: _clear,
//               ),
//               filled: true,
//               fillColor: AppColors.surface,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(AppRadius.md),
//                 borderSide: const BorderSide(color: AppColors.border),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(AppRadius.md),
//                 borderSide: const BorderSide(color: AppColors.border),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(AppRadius.md),
//                 borderSide: const BorderSide(color: AppColors.primary, width: 2),
//               ),
//             ),
//             onChanged: (v) {
//               final trimmed = v.trim();
//               widget.controller.search(trimmed);
//               if (mounted) {
//                 setState(() => _showResults = trimmed.isNotEmpty);
//               }
//             },
//             onSubmitted: _onSubmitted,
//           ),
//         ),
//
//         // Results Dropdown
//         if (_showResults && _searchCtrl.text.trim().isNotEmpty) _buildRichResultsList(),
//       ],
//     );
//   }
//
//   Widget _buildRichResultsList() {
//     final ctrl = widget.controller;
//
//     return Container(
//       margin: const EdgeInsets.only(top: AppSpacing.sm),
//       constraints: const BoxConstraints(maxHeight: 320),
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(AppRadius.md),
//         border: Border.all(color: AppColors.border, width: 2),
//         boxShadow: const [
//           BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
//         ],
//       ),
//       child: ctrl.isSearching
//           ? const Padding(
//         padding: EdgeInsets.all(AppSpacing.lg),
//         child: Center(
//           child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
//         ),
//       )
//           : ctrl.searchResults.isEmpty
//           ? Padding(
//         padding: const EdgeInsets.all(AppSpacing.lg),
//         child: Text('No medicines match "${_searchCtrl.text}".', style: AppTypography.bodySmall),
//       )
//           : Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             color: AppColors.surfaceVariant,
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               children: [
//                 Expanded(flex: 3, child: Text('Medicine', style: AppTypography.tableHeader)),
//                 Expanded(flex: 3, child: Text('Formula', style: AppTypography.tableHeader)),
//                 Expanded(flex: 1, child: Text('Box Size', style: AppTypography.tableHeader, textAlign: TextAlign.center)),
//                 Expanded(flex: 1, child: Text('Stock', style: AppTypography.tableHeader, textAlign: TextAlign.center)),
//                 Expanded(flex: 2, child: Text('Piece Price', style: AppTypography.tableHeader, textAlign: TextAlign.right)),
//                 Expanded(flex: 2, child: Text('Box Price', style: AppTypography.tableHeader, textAlign: TextAlign.right)),
//               ],
//             ),
//           ),
//           const Divider(height: 1),
//           Flexible(
//             child: ListView.separated(
//               shrinkWrap: true,
//               itemCount: ctrl.searchResults.length,
//               separatorBuilder: (_, __) => const Divider(height: 1),
//               itemBuilder: (ctx, i) {
//                 final item = ctrl.searchResults[i];
//                 final m = item.medicine;
//                 final isOutOfStock = item.currentStock <= 0;
//
//                 return Material(
//                   color: isOutOfStock
//                       ? AppColors.errorSurface.withValues(alpha: 0.3)
//                       : Colors.transparent,
//                   child: InkWell(
//                     onTap: () => _selectItem(item),
//                     hoverColor: AppColors.primarySurface,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                       child: Row(
//                         children: [
//                           // Medicine name + generic
//                           Expanded(
//                             flex: 3,
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(m.name, style: AppTypography.subtitle.copyWith(fontSize: 14)),
//                                 if (m.genericName.isNotEmpty)
//                                   Text(
//                                     '${m.genericName} ${m.strength}',
//                                     style: AppTypography.caption,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   )
//                                 else if (m.strength.isNotEmpty)
//                                   Text(m.strength, style: AppTypography.caption),
//                               ],
//                             ),
//                           ),
//                           // Formula — separate column
//                           Expanded(
//                             flex: 3,
//                             child: Text(
//                               m.formula.isEmpty ? '—' : m.formula,
//                               style: AppTypography.caption.copyWith(
//                                 color: m.formula.isEmpty
//                                     ? AppColors.textSecondary
//                                     : AppColors.info,
//                                 fontWeight: m.formula.isEmpty
//                                     ? FontWeight.normal
//                                     : FontWeight.w600,
//                                 fontStyle: m.formula.isEmpty
//                                     ? FontStyle.italic
//                                     : FontStyle.normal,
//                               ),
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           Expanded(
//                             flex: 1,
//                             child: Text('${m.boxSize}s', textAlign: TextAlign.center, style: AppTypography.bodySmall),
//                           ),
//                           Expanded(
//                             flex: 1,
//                             child: Text(
//                               '${item.currentStock}',
//                               textAlign: TextAlign.center,
//                               style: AppTypography.numeric.copyWith(
//                                 color: isOutOfStock ? AppColors.error : AppColors.success,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               item.displayPrice.display,
//                               textAlign: TextAlign.right,
//                               style: AppTypography.numericSmall,
//                             ),
//                           ),
//                           Expanded(
//                             flex: 2,
//                             child: Text(
//                               item.displayBoxPrice.display,
//                               textAlign: TextAlign.right,
//                               style: AppTypography.numericSmall.copyWith(
//                                 color: AppColors.primary,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Fixed row height so keyboard scrolling can be calculated exactly.
  static const double _rowHeight = 64.0;

  late TextEditingController _searchCtrl;
  late FocusNode _searchFocus;
  final ScrollController _scrollCtrl = ScrollController();
  bool _internalCtrl = false;
  bool _internalFocus = false;
  bool _showResults = false;

  // Row currently highlighted by the arrow keys.
  int _highlightedIndex = 0;

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
    _scrollCtrl.dispose();
    if (_internalCtrl) _searchCtrl.dispose();
    if (_internalFocus) _searchFocus.dispose();
    super.dispose();
  }

  int _safeIndex(int length) {
    if (length <= 0) return 0;
    return _highlightedIndex.clamp(0, length - 1);
  }

  void _selectItem(PosSearchResult item) {
    widget.onMedicineSelected(item);
    _clear();
  }

  void _clear() {
    _searchCtrl.clear();
    widget.controller.search('');
    _highlightedIndex = 0;
    if (mounted) {
      setState(() => _showResults = false);
    }
    _searchFocus.requestFocus();
  }

  // Enter key: add the highlighted medicine (first one by default).
  void _onSubmitted(String value) {
    final results = widget.controller.searchResults;
    if (results.isNotEmpty) {
      _selectItem(results[_safeIndex(results.length)]);
    }
  }

  void _scrollToHighlighted() {
    if (!_scrollCtrl.hasClients) return;
    final double top = _highlightedIndex * _rowHeight;
    final double bottom = top + _rowHeight;
    final double viewTop = _scrollCtrl.offset;
    final double viewHeight = _scrollCtrl.position.viewportDimension;
    final double viewBottom = viewTop + viewHeight;

    if (top < viewTop) {
      _scrollCtrl.jumpTo(top);
    } else if (bottom > viewBottom) {
      final double target = (bottom - viewHeight)
          .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
      _scrollCtrl.jumpTo(target);
    }
  }

  // Arrow Up / Arrow Down / Esc handling while typing in the search box.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final results = widget.controller.searchResults;
    final bool hasText = _searchCtrl.text.trim().isNotEmpty;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (!hasText || results.isEmpty) return KeyEventResult.ignored;
      setState(() {
        _showResults = true;
        _highlightedIndex = (_safeIndex(results.length) + 1) % results.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (!hasText || results.isEmpty) return KeyEventResult.ignored;
      setState(() {
        _showResults = true;
        _highlightedIndex =
            (_safeIndex(results.length) - 1 + results.length) % results.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_showResults) {
        setState(() => _showResults = false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleKey,
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText:
                'Search Name, Generic, Formula, or Manufacturer [F2] (↑ ↓ to choose, Enter to add)',
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.primary),
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  splashRadius: 16,
                  onPressed: _clear,
                ),
                filled: true,
                fillColor: AppColors.surface,
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
                  borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (v) {
                final trimmed = v.trim();
                widget.controller.search(trimmed);
                if (mounted) {
                  setState(() {
                    _highlightedIndex = 0; // new search starts at the top
                    _showResults = trimmed.isNotEmpty;
                  });
                }
              },
              onSubmitted: _onSubmitted,
            ),
          ),
        ),

        // Results Dropdown
        if (_showResults && _searchCtrl.text.trim().isNotEmpty)
          _buildRichResultsList(),
      ],
    );
  }

  Widget _buildRichResultsList() {
    final ctrl = widget.controller;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: ctrl.isSearching
          ? const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      )
          : ctrl.searchResults.isEmpty
          ? Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('No medicines match "${_searchCtrl.text}".',
            style: AppTypography.bodySmall),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Medicine',
                        style: AppTypography.tableHeader)),
                Expanded(
                    flex: 3,
                    child: Text('Formula',
                        style: AppTypography.tableHeader)),
                Expanded(
                    flex: 1,
                    child: Text('Box Size',
                        style: AppTypography.tableHeader,
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 1,
                    child: Text('Stock',
                        style: AppTypography.tableHeader,
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Piece Price',
                        style: AppTypography.tableHeader,
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text('Box Price',
                        style: AppTypography.tableHeader,
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              controller: _scrollCtrl,
              shrinkWrap: true,
              itemExtent: _rowHeight,
              itemCount: ctrl.searchResults.length,
              itemBuilder: (ctx, i) {
                final item = ctrl.searchResults[i];
                final m = item.medicine;
                final isOutOfStock = item.currentStock <= 0;
                final isHighlighted =
                    i == _safeIndex(ctrl.searchResults.length);

                return Material(
                  color: isHighlighted
                      ? AppColors.primarySurface
                      : isOutOfStock
                      ? AppColors.errorSurface
                      .withValues(alpha: 0.3)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectItem(item),
                    hoverColor: AppColors.primarySurface,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isHighlighted
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 4,
                          ),
                          bottom: const BorderSide(
                              color: AppColors.border, width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Medicine name + generic
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: AppTypography.subtitle
                                      .copyWith(
                                    fontSize: 14,
                                    fontWeight: isHighlighted
                                        ? FontWeight.w800
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (m.genericName.isNotEmpty)
                                  Text(
                                    '${m.genericName} ${m.strength}',
                                    style: AppTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (m.strength.isNotEmpty)
                                  Text(m.strength,
                                      style: AppTypography.caption),
                              ],
                            ),
                          ),
                          // Formula — separate column
                          Expanded(
                            flex: 3,
                            child: Text(
                              m.formula.isEmpty ? '—' : m.formula,
                              style: AppTypography.caption.copyWith(
                                color: m.formula.isEmpty
                                    ? AppColors.textSecondary
                                    : AppColors.info,
                                fontWeight: m.formula.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                fontStyle: m.formula.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('${m.boxSize}s',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySmall),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.currentStock}',
                              textAlign: TextAlign.center,
                              style: AppTypography.numeric.copyWith(
                                color: isOutOfStock
                                    ? AppColors.error
                                    : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.displayPrice.display,
                              textAlign: TextAlign.right,
                              style: AppTypography.numericSmall,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.displayBoxPrice.display,
                              textAlign: TextAlign.right,
                              style:
                              AppTypography.numericSmall.copyWith(
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
          const Divider(height: 1),
          Container(
            width: double.infinity,
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            child: Text(
              '↑ ↓ navigate   •   Enter add selected   •   Esc close',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}