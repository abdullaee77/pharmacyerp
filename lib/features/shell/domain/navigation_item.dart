import 'package:flutter/material.dart';
import '../../authentication/domain/user.dart';
import '../../users/domain/role.dart';

/// Top-level navigation items. Visibility is driven by the user's permissions.
enum NavigationItem {
  home(
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    shortcutLabel: 'Alt+1',
    category: PermissionCategory.dashboard,
  ),
  sales(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    shortcutLabel: 'Alt+2',
    category: PermissionCategory.sales,
  ),
  purchases(
    label: 'Purchases',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag_rounded,
    shortcutLabel: 'Alt+3',
    category: PermissionCategory.purchases,
  ),
  inventory(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    shortcutLabel: 'Alt+4',
    category: PermissionCategory.inventory,
  ),
  medicines(
    label: 'Medicines',
    icon: Icons.medication_outlined,
    selectedIcon: Icons.medication_rounded,
    shortcutLabel: 'Alt+5',
    category: PermissionCategory.medicines,
  ),
  customers(
    label: 'Customers',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    shortcutLabel: 'Alt+6',
    category: PermissionCategory.customers,
  ),
  suppliers(
    label: 'Suppliers',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    shortcutLabel: 'Alt+7',
    category: PermissionCategory.suppliers,
  ),
  accounts(
    label: 'Accounts',
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance_rounded,
    shortcutLabel: 'Alt+8',
    category: PermissionCategory.accounts,
  ),
  reports(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
    shortcutLabel: 'Alt+9',
    category: PermissionCategory.reports,
  ),
  // "More" has no category of its own: visible if any of its sections is allowed.
  more(
    label: 'More',
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps_rounded,
    shortcutLabel: 'Alt+0',
  );

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String shortcutLabel;
  final PermissionCategory? category;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.shortcutLabel,
    this.category,
  });

  /// True when the user may see this tab.
  bool isAllowedFor(User? user) {
    if (user == null) return false;
    if (this == NavigationItem.more) {
      return MoreSection.values.any((s) => s.isAllowedFor(user));
    }
    return user.hasAnyIn(category!);
  }
}

/// Sub-tabs inside the "More" page, each gated by one permission.
enum MoreSection {
  expenses('Expenses', Permission(PermissionCategory.accounts, PermissionAction.view)),
  categories('Categories', Permission(PermissionCategory.medicines, PermissionAction.manage)),
  users('Users', Permission(PermissionCategory.users, PermissionAction.view)),
  roles('Roles & Permissions', Permission(PermissionCategory.users, PermissionAction.manage)),
  settings('Settings', Permission(PermissionCategory.settings, PermissionAction.view)),
  network('Network & LAN', Permission(PermissionCategory.settings, PermissionAction.manage)),
  license('License', Permission(PermissionCategory.licensing, PermissionAction.view)),
  backup('Backup & Network', Permission(PermissionCategory.settings, PermissionAction.manage));

  final String label;
  final Permission permission;
  const MoreSection(this.label, this.permission);

  bool isAllowedFor(User? user) =>
      user != null && user.can(permission.category, permission.action);
}