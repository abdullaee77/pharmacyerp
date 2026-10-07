import 'package:flutter/material.dart';
import '../services/shortcut_registry.dart' as reg;

class AppShortcutScope extends StatelessWidget {
  final Widget child;
  final VoidCallback? onQuickSearch;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onDismiss;
  final VoidCallback? onNewSale;
  final VoidCallback? onNewPurchase;
  final VoidCallback? onNewMedicine;
  final VoidCallback? onRefreshData;
  final ValueChanged<int>? onNavigateToTab;

  const AppShortcutScope({
    super.key,
    required this.child,
    this.onQuickSearch,
    this.onToggleFullscreen,
    this.onDismiss,
    this.onNewSale,
    this.onNewPurchase,
    this.onNewMedicine,
    this.onRefreshData,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Navigation (Alt + 1..0)
        reg.ShortcutRegistry.goToHome: const reg.NavigateHomeIntent(),
        reg.ShortcutRegistry.goToSales: const reg.NavigateSalesIntent(),
        reg.ShortcutRegistry.goToPurchases: const reg.NavigatePurchasesIntent(),
        reg.ShortcutRegistry.goToInventory: const reg.NavigateInventoryIntent(),
        reg.ShortcutRegistry.goToMedicines: const reg.NavigateMedicinesIntent(),
        reg.ShortcutRegistry.goToCustomers: const reg.NavigateCustomersIntent(),
        reg.ShortcutRegistry.goToSuppliers: const reg.NavigateSuppliersIntent(),
        reg.ShortcutRegistry.goToAccounts: const reg.NavigateAccountsIntent(),
        reg.ShortcutRegistry.goToReports: const reg.NavigateReportsIntent(),
        reg.ShortcutRegistry.goToMore: const reg.NavigateMoreIntent(),

        // Global Actions (Ctrl + K / Cmd + K)
        reg.ShortcutRegistry.quickSearchCtrl: const reg.QuickSearchIntent(),
        reg.ShortcutRegistry.quickSearchCmd: const reg.QuickSearchIntent(),
        reg.ShortcutRegistry.toggleFullscreen: const reg.ToggleFullscreenIntent(),
        reg.ShortcutRegistry.dismiss: const reg.DismissIntent(),

        // App-Level Navigation
        reg.ShortcutRegistry.newSale: const reg.NewSaleIntent(),
        reg.ShortcutRegistry.newPurchase: const reg.NewPurchaseIntent(),
        reg.ShortcutRegistry.newMedicine: const reg.NewMedicineIntent(),
        reg.ShortcutRegistry.refreshData: const reg.RefreshDataIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // Navigation
          reg.NavigateHomeIntent: CallbackAction<reg.NavigateHomeIntent>(
            onInvoke: (_) => onNavigateToTab?.call(0),
          ),
          reg.NavigateSalesIntent: CallbackAction<reg.NavigateSalesIntent>(
            onInvoke: (_) => onNavigateToTab?.call(1),
          ),
          reg.NavigatePurchasesIntent: CallbackAction<reg.NavigatePurchasesIntent>(
            onInvoke: (_) => onNavigateToTab?.call(2),
          ),
          reg.NavigateInventoryIntent: CallbackAction<reg.NavigateInventoryIntent>(
            onInvoke: (_) => onNavigateToTab?.call(3),
          ),
          reg.NavigateMedicinesIntent: CallbackAction<reg.NavigateMedicinesIntent>(
            onInvoke: (_) => onNavigateToTab?.call(4),
          ),
          reg.NavigateCustomersIntent: CallbackAction<reg.NavigateCustomersIntent>(
            onInvoke: (_) => onNavigateToTab?.call(5),
          ),
          reg.NavigateSuppliersIntent: CallbackAction<reg.NavigateSuppliersIntent>(
            onInvoke: (_) => onNavigateToTab?.call(6),
          ),
          reg.NavigateAccountsIntent: CallbackAction<reg.NavigateAccountsIntent>(
            onInvoke: (_) => onNavigateToTab?.call(7),
          ),
          reg.NavigateReportsIntent: CallbackAction<reg.NavigateReportsIntent>(
            onInvoke: (_) => onNavigateToTab?.call(8),
          ),
          reg.NavigateMoreIntent: CallbackAction<reg.NavigateMoreIntent>(
            onInvoke: (_) => onNavigateToTab?.call(9),
          ),

          // Global Actions
          reg.QuickSearchIntent: CallbackAction<reg.QuickSearchIntent>(
            onInvoke: (_) {
              onQuickSearch?.call();
              return null;
            },
          ),
          reg.ToggleFullscreenIntent: CallbackAction<reg.ToggleFullscreenIntent>(
            onInvoke: (_) {
              onToggleFullscreen?.call();
              return null;
            },
          ),
          reg.DismissIntent: CallbackAction<reg.DismissIntent>(
            onInvoke: (_) {
              onDismiss?.call();
              return null;
            },
          ),

          // App-Level Navigation
          reg.NewSaleIntent: CallbackAction<reg.NewSaleIntent>(
            onInvoke: (_) {
              onNewSale?.call();
              return null;
            },
          ),
          reg.NewPurchaseIntent: CallbackAction<reg.NewPurchaseIntent>(
            onInvoke: (_) {
              onNewPurchase?.call();
              return null;
            },
          ),
          reg.NewMedicineIntent: CallbackAction<reg.NewMedicineIntent>(
            onInvoke: (_) {
              onNewMedicine?.call();
              return null;
            },
          ),
          reg.RefreshDataIntent: CallbackAction<reg.RefreshDataIntent>(
            onInvoke: (_) {
              onRefreshData?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}