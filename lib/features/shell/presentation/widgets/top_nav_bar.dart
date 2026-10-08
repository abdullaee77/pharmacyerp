import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: visibleItems.map((item) {
                  final isSelected = selectedItem == item;
                  return _NavTabButton(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onItemSelected(item.index),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          hoverColor: AppColors.surfaceVariant,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: AppTypography.buttonSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
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