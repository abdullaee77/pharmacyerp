import 'package:flutter/material.dart';
import '../../../core/domain/value_object.dart';
import 'navigation_item.dart';

/// Value object representing an executable action inside the contextual ribbon.
class RibbonAction extends ValueObject {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final String? shortcut;
  final String? badgeText;

  const RibbonAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.shortcut,
    this.badgeText,
  });

  /// Factory providing contextual actions tailored to the active [NavigationItem].
  static List<RibbonAction> getActionsFor(NavigationItem item) {
    switch (item) {
      case NavigationItem.home:
        return [
          RibbonAction(
            id: 'home_quick_sale',
            label: 'Quick Sale',
            icon: Icons.add_shopping_cart_rounded,
            isPrimary: true,
            shortcut: 'F1',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'home_check_stock',
            label: 'Check Stock',
            icon: Icons.search_rounded,
            shortcut: 'Ctrl+F',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'home_expiring',
            label: 'Near Expiry Alerts',
            icon: Icons.warning_amber_rounded,
            badgeText: '12',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'home_daily_report',
            label: 'Daily Summary',
            icon: Icons.summarize_outlined,
            onPressed: () {},
          ),
        ];

      case NavigationItem.sales:
        return [
          RibbonAction(
            id: 'sale_new',
            label: 'New Invoice',
            icon: Icons.add_rounded,
            isPrimary: true,
            shortcut: 'F1',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'sale_hold',
            label: 'Held Invoices',
            icon: Icons.pause_circle_outline_rounded,
            badgeText: '3',
            shortcut: 'F4',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'sale_return',
            label: 'Sales Return',
            icon: Icons.assignment_return_outlined,
            shortcut: 'F8',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'sale_history',
            label: 'History / Register',
            icon: Icons.history_rounded,
            onPressed: () {},
          ),
        ];

      case NavigationItem.purchases:
        return [
          RibbonAction(
            id: 'purchase_new',
            label: 'New Purchase',
            icon: Icons.add_shopping_cart_rounded,
            isPrimary: true,
            shortcut: 'F2',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'purchase_order',
            label: 'Purchase Order',
            icon: Icons.note_add_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'purchase_return',
            label: 'Purchase Return',
            icon: Icons.assignment_return_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'purchase_bills',
            label: 'Supplier Bills',
            icon: Icons.receipt_long_outlined,
            onPressed: () {},
          ),
        ];

      case NavigationItem.inventory:
        return [
          RibbonAction(
            id: 'inv_adjustment',
            label: 'Stock Adjustment',
            icon: Icons.tune_rounded,
            isPrimary: true,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'inv_batches',
            label: 'Batch Tracking',
            icon: Icons.layers_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'inv_expiry',
            label: 'Expiry Control',
            icon: Icons.event_busy_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'inv_movement',
            label: 'Stock Ledger',
            icon: Icons.swap_horiz_rounded,
            onPressed: () {},
          ),
        ];

      case NavigationItem.medicines:
        return [
          RibbonAction(
            id: 'med_new',
            label: 'Add Medicine',
            icon: Icons.add_circle_outline_rounded,
            isPrimary: true,
            shortcut: 'F3',
            onPressed: () {},
          ),
          RibbonAction(
            id: 'med_categories',
            label: 'Generics & Categories',
            icon: Icons.category_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'med_pricing',
            label: 'Price List',
            icon: Icons.sell_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'med_barcodes',
            label: 'Barcode Generator',
            icon: Icons.qr_code_2_rounded,
            onPressed: () {},
          ),
        ];

      case NavigationItem.customers:
        return [
          RibbonAction(
            id: 'cust_new',
            label: 'New Customer',
            icon: Icons.person_add_outlined,
            isPrimary: true,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'cust_credit',
            label: 'Credit Ledger',
            icon: Icons.credit_score_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'cust_loyalty',
            label: 'Loyalty Points',
            icon: Icons.card_giftcard_outlined,
            onPressed: () {},
          ),
        ];

      case NavigationItem.suppliers:
        return [
          RibbonAction(
            id: 'sup_new',
            label: 'New Supplier',
            icon: Icons.add_business_outlined,
            isPrimary: true,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'sup_payable',
            label: 'Payables Ledger',
            icon: Icons.payment_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'sup_contacts',
            label: 'Supplier Directory',
            icon: Icons.contact_phone_outlined,
            onPressed: () {},
          ),
        ];

      case NavigationItem.accounts:
        return [
          RibbonAction(
            id: 'acc_expense',
            label: 'Record Expense',
            icon: Icons.money_off_rounded,
            isPrimary: true,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'acc_cashbook',
            label: 'Cash Book',
            icon: Icons.account_balance_wallet_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'acc_bank',
            label: 'Bank Accounts',
            icon: Icons.account_balance_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'acc_journal',
            label: 'Journal Entry',
            icon: Icons.menu_book_rounded,
            onPressed: () {},
          ),
        ];

      case NavigationItem.reports:
        return [
          RibbonAction(
            id: 'rep_sales',
            label: 'Sales Report',
            icon: Icons.trending_up_rounded,
            isPrimary: true,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'rep_profit',
            label: 'Profit & Loss',
            icon: Icons.analytics_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'rep_stock_val',
            label: 'Stock Valuation',
            icon: Icons.inventory_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'rep_tax',
            label: 'Tax / GST Summary',
            icon: Icons.receipt_outlined,
            onPressed: () {},
          ),
        ];

      case NavigationItem.more:
        return [
          RibbonAction(
            id: 'more_users',
            label: 'User Management',
            icon: Icons.manage_accounts_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'more_settings',
            label: 'Settings',
            icon: Icons.settings_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'more_backup',
            label: 'Backup & Restore',
            icon: Icons.cloud_sync_outlined,
            onPressed: () {},
          ),
          RibbonAction(
            id: 'more_license',
            label: 'License Info',
            icon: Icons.verified_user_outlined,
            onPressed: () {},
          ),
        ];
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RibbonAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}