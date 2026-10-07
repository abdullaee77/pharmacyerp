import 'package:flutter/material.dart';

/// Top-level navigation items for the Pharmacy ERP application.
enum NavigationItem {
  home(
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    shortcutLabel: 'Alt+1',
  ),
  sales(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    shortcutLabel: 'Alt+2',
  ),
  purchases(
    label: 'Purchases',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag_rounded,
    shortcutLabel: 'Alt+3',
  ),
  inventory(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    shortcutLabel: 'Alt+4',
  ),
  medicines(
    label: 'Medicines',
    icon: Icons.medication_outlined,
    selectedIcon: Icons.medication_rounded,
    shortcutLabel: 'Alt+5',
  ),
  customers(
    label: 'Customers',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    shortcutLabel: 'Alt+6',
  ),
  suppliers(
    label: 'Suppliers',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    shortcutLabel: 'Alt+7',
  ),
  accounts(
    label: 'Accounts',
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance_rounded,
    shortcutLabel: 'Alt+8',
  ),
  reports(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
    shortcutLabel: 'Alt+9',
  ),
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

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.shortcutLabel,
  });
}