import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Centralized registry of global keyboard shortcuts using SingleActivator.
class ShortcutRegistry {
  ShortcutRegistry._();

  // ── Global Navigation (Alt + 1..0) ───────────────────────────
  static const goToHome = SingleActivator(LogicalKeyboardKey.digit1, alt: true);
  static const goToSales = SingleActivator(LogicalKeyboardKey.digit2, alt: true);
  static const goToPurchases = SingleActivator(LogicalKeyboardKey.digit3, alt: true);
  static const goToInventory = SingleActivator(LogicalKeyboardKey.digit4, alt: true);
  static const goToMedicines = SingleActivator(LogicalKeyboardKey.digit5, alt: true);
  static const goToCustomers = SingleActivator(LogicalKeyboardKey.digit6, alt: true);
  static const goToSuppliers = SingleActivator(LogicalKeyboardKey.digit7, alt: true);
  static const goToAccounts = SingleActivator(LogicalKeyboardKey.digit8, alt: true);
  static const goToReports = SingleActivator(LogicalKeyboardKey.digit9, alt: true);
  static const goToMore = SingleActivator(LogicalKeyboardKey.digit0, alt: true);

  // ── Global App Actions (Ctrl + K / Cmd + K) ───────────────────
  static const quickSearchCtrl = SingleActivator(LogicalKeyboardKey.keyK, control: true);
  static const quickSearchCmd = SingleActivator(LogicalKeyboardKey.keyK, meta: true);
  static const toggleRibbon = SingleActivator(LogicalKeyboardKey.f1, control: true);
  static const toggleFullscreen = SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true);
  static const dismiss = SingleActivator(LogicalKeyboardKey.escape);

  // ── App Navigation Quick Keys ─────────────────────────────────
  static const newSale = SingleActivator(LogicalKeyboardKey.f1);
  static const newMedicine = SingleActivator(LogicalKeyboardKey.f3);
  static const newPurchase = SingleActivator(LogicalKeyboardKey.f4);
  static const refreshData = SingleActivator(LogicalKeyboardKey.f5);

  // ── Lookup Map ────────────────────────────────────────────────
  static const Map<String, String> descriptions = {
    'Alt+1': 'Dashboard',
    'Alt+2': 'Sales & POS',
    'Alt+3': 'Purchases',
    'Alt+4': 'Inventory',
    'Alt+5': 'Medicines',
    'Alt+6': 'Customers',
    'Alt+7': 'Suppliers',
    'Alt+8': 'Accounts',
    'Alt+9': 'Reports',
    'Alt+0': 'More',
    'Ctrl+K': 'Quick Search',
    'Esc': 'Dismiss / Close',
    'F1': 'Go to POS',
    'F2': 'Focus Search (in POS)',
    'F3': 'Medicines',
    'F4': 'Purchases',
    'F5': 'Refresh',
    'F8': 'Complete Sale / Pay (in POS)',
    'F9': 'Hold / Resume Sale (in POS)',
  };
}

/// Intent classes for Actions system
class NavigateHomeIntent extends Intent { const NavigateHomeIntent(); }
class NavigateSalesIntent extends Intent { const NavigateSalesIntent(); }
class NavigatePurchasesIntent extends Intent { const NavigatePurchasesIntent(); }
class NavigateInventoryIntent extends Intent { const NavigateInventoryIntent(); }
class NavigateMedicinesIntent extends Intent { const NavigateMedicinesIntent(); }
class NavigateCustomersIntent extends Intent { const NavigateCustomersIntent(); }
class NavigateSuppliersIntent extends Intent { const NavigateSuppliersIntent(); }
class NavigateAccountsIntent extends Intent { const NavigateAccountsIntent(); }
class NavigateReportsIntent extends Intent { const NavigateReportsIntent(); }
class NavigateMoreIntent extends Intent { const NavigateMoreIntent(); }

class QuickSearchIntent extends Intent { const QuickSearchIntent(); }
class ToggleRibbonIntent extends Intent { const ToggleRibbonIntent(); }
class ToggleFullscreenIntent extends Intent { const ToggleFullscreenIntent(); }
class DismissIntent extends Intent { const DismissIntent(); }

class NewSaleIntent extends Intent { const NewSaleIntent(); }
class NewPurchaseIntent extends Intent { const NewPurchaseIntent(); }
class NewMedicineIntent extends Intent { const NewMedicineIntent(); }
class RefreshDataIntent extends Intent { const RefreshDataIntent(); }