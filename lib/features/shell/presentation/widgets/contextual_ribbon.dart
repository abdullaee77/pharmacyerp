import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/domain/user.dart';
import '../../domain/navigation_item.dart';
import '../../domain/ribbon_action.dart';

class ContextualRibbon extends StatelessWidget {
  final NavigationItem currentItem;
  final bool isCollapsed;
  final ValueChanged<String> onAction;
  final User? user;

  const ContextualRibbon({
    super.key,
    required this.currentItem,
    required this.isCollapsed,
    required this.onAction,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final allActions = RibbonAction.getActionsFor(currentItem);
    // Filter: keep only actions the user is allowed to perform.
    final actions = allActions.where((a) {
      if (a.requiredPermission == null) return true;
      return PermissionGate.allow(user, a.requiredPermission!.category, a.requiredPermission!.action);
    }).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      child: isCollapsed || actions.isEmpty
          ? const SizedBox.shrink()
          : Container(
        height: 50,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 6,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.borderDark, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(currentItem.selectedIcon, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    currentItem.label.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 24, color: AppColors.borderDark),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: actions.map((action) {
                    return _RibbonActionButton(
                      action: action,
                      onTap: () => onAction(action.id),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonActionButton extends StatelessWidget {
  final RibbonAction action;
  final VoidCallback onTap;

  const _RibbonActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Tooltip(
        message: action.shortcut != null
            ? '${action.label} (${action.shortcut})'
            : action.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            hoverColor: action.isPrimary ? AppColors.primaryDark : AppColors.surfaceHover,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: action.isPrimary ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: action.isPrimary ? AppColors.primaryDark : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 16,
                      color: action.isPrimary ? AppColors.textInverse : AppColors.textPrimary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(action.label,
                      style: AppTypography.buttonSmall.copyWith(
                        color: action.isPrimary ? AppColors.textInverse : AppColors.textPrimary,
                        fontWeight: action.isPrimary ? FontWeight.w600 : FontWeight.w500,
                      )),
                  if (action.shortcut != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: action.isPrimary ? AppColors.primaryDark : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(action.shortcut!,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: action.isPrimary ? AppColors.textInverse : AppColors.textSecondary,
                          )),
                    ),
                  ],
                  if (action.badgeText != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(action.badgeText!,
                          style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textInverse,
                          )),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}