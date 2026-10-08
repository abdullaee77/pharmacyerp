import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../authentication/domain/user.dart';
import '../../domain/navigation_item.dart';

class TopNavBar extends StatelessWidget {
  final NavigationItem selectedItem;
  final ValueChanged<int> onItemSelected;
  final bool isRibbonCollapsed;
  final VoidCallback? onToggleRibbon;
  final User? user;

  const TopNavBar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
    this.isRibbonCollapsed = true,
    this.onToggleRibbon,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    // Only show tabs the user has permission to see
    final visibleItems = NavigationItem.values
        .where((item) => item.isAllowedFor(user))
        .toList();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in visibleItems)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _NavButton(
                    item: item,
                    isSelected: selectedItem == item,
                    onTap: () => onItemSelected(item.index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;

    final Color bg = selected
        ? AppColors.primary
        : _hovered
        ? AppColors.surfaceVariant
        : Colors.transparent;

    final Color fg = selected ? AppColors.textInverse : AppColors.textSecondary;

    return Tooltip(
      message: '${widget.item.label} (${widget.item.shortcutLabel})',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected
                    ? AppColors.primaryDark
                    : _hovered
                    ? AppColors.border
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? widget.item.selectedIcon : widget.item.icon,
                  size: 18,
                  color: fg,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.item.label,
                  style: AppTypography.buttonSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}