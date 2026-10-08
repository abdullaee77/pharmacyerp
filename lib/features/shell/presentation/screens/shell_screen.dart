// lib/features/shell/presentation/screens/shell_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_shortcut_scope.dart';
import '../../../../core/widgets/app_responsive_layout.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/data_sync_service.dart';
import '../../../../core/network/api_server.dart';
import '../../../accounts/data/sqlite_account_repository.dart';
import '../../../accounts/data/http_account_repository.dart';
import '../../../accounts/presentation/controllers/account_controller.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../authentication/domain/user.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../backup/presentation/controllers/backup_controller.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../categories/data/sqlite_category_repository.dart';
import '../../../categories/data/http_category_repository.dart';
import '../../../categories/presentation/controllers/category_controller.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../customers/data/sqlite_customer_repository.dart';
import '../../../customers/data/http_customer_repository.dart';
import '../../../customers/presentation/controllers/customer_controller.dart';
import '../../../customers/presentation/screens/customer_list_screen.dart';
import '../../../expenses/data/sqlite_expense_repository.dart';
import '../../../expenses/data/http_expense_repository.dart';
import '../../../expenses/presentation/controllers/expense_controller.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../inventory/data/sqlite_inventory_repository.dart';
import '../../../inventory/data/http_inventory_repository.dart';
import '../../../inventory/data/sqlite_batch_repository.dart';
import '../../../inventory/data/http_batch_repository.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';
import '../../../inventory/presentation/controllers/batch_controller.dart';
import '../../../inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../../inventory/presentation/screens/inventory_list_screen.dart';
import '../../../inventory/presentation/screens/batch_list_screen.dart';
import '../../../licensing/data/mock_license_repository.dart';
import '../../../licensing/presentation/controllers/license_controller.dart';
import '../../../licensing/presentation/screens/license_screen.dart';
import '../../../medicines/data/sqlite_medicine_repository.dart';
import '../../../medicines/data/http_medicine_repository.dart';
import '../../../medicines/presentation/controllers/medicine_controller.dart';
import '../../../medicines/presentation/screens/medicine_list_screen.dart';
import '../../../network/presentation/controllers/network_controller.dart';
import '../../../network/presentation/screens/network_settings_screen.dart';
import '../../../purchases/data/sqlite_purchase_repository.dart';
import '../../../purchases/data/http_purchase_repository.dart';
import '../../../purchases/presentation/controllers/purchase_controller.dart';
import '../../../purchases/presentation/screens/purchase_workspace_screen.dart';
import '../../../reports/data/sqlite_report_repository.dart';
import '../../../reports/data/http_report_repository.dart';
import '../../../reports/presentation/controllers/report_controller.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../reports/presentation/screens/business_dashboard_screen.dart';
import '../../../sales/data/sqlite_pos_repository.dart';
import '../../../sales/data/sqlite_sales_repository.dart';
import '../../../sales/data/http_pos_repository.dart';
import '../../../sales/data/http_sales_repository.dart';
import '../../../sales/presentation/controllers/pos_cart_controller.dart';
import '../../../sales/presentation/controllers/sales_controller.dart';
import '../../../sales/presentation/screens/pos_screen.dart';
import '../../../sales/presentation/screens/sales_history_screen.dart';
import '../../../settings/data/sqlite_settings_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../suppliers/data/sqlite_supplier_repository.dart';
import '../../../suppliers/data/http_supplier_repository.dart';
import '../../../suppliers/presentation/controllers/supplier_controller.dart';
import '../../../suppliers/presentation/screens/supplier_list_screen.dart';
import '../../../users/data/sqlite_user_repository.dart';
import '../../../users/data/http_user_repository.dart';
import '../../../users/domain/role.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../../users/presentation/screens/users_screen.dart';
import '../../../users/presentation/screens/roles_screen.dart';
import '../../domain/navigation_item.dart';
import '../controllers/shell_controller.dart';
import '../controllers/workspace_controller.dart';
import '../widgets/top_bar.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/global_search_dialog.dart';

class _SubTab {
  final String label;
  final Widget Function() build;
  _SubTab(this.label, this.build);
}

class ShellScreen extends StatefulWidget {
  final AuthController authController;
  const ShellScreen({super.key, required this.authController});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with TickerProviderStateMixin {
  late final ShellController _navController;
  late final WorkspaceController _workspaceController;
  late final MedicineController _medicineController;
  late final InventoryController _inventoryController;
  late final BatchController _batchController;
  late final CategoryController _categoryController;
  late final PosCartController _posCartController;
  late final SalesController _salesController;
  late final PurchaseController _purchaseController;
  late final CustomerController _customerController;
  late final SupplierController _supplierController;
  late final AccountController _accountController;
  late final ExpenseController _expenseController;
  late final ReportController _reportController;
  late final UserController _userController;
  late final SettingsController _settingsController;
  late final LicenseController _licenseController;
  late final BackupController _backupController;
  late final NetworkController _networkController;

  late final TabController _inventoryTabCtrl;
  late final TabController _salesTabCtrl;
  late final TabController _moreTabCtrl;

  late final List<Widget> _pages;

  Timer? _reloadDebounce;

  late final bool _hasAccess;
  late final List<MoreSection> _moreSections;
  late final List<_SubTab> _salesTabs;

  @override
  void initState() {
    super.initState();

    final user = widget.authController.currentUser;
    final allowed =
    NavigationItem.values.where((i) => i.isAllowedFor(user)).toList();
    _hasAccess = allowed.isNotEmpty;

    _navController = ShellController(
      initialItem: _hasAccess ? allowed.first : NavigationItem.home,
    );
    _navController.addListener(_onNavChange);
    _workspaceController = WorkspaceController();
    _workspaceController.addListener(_onWorkspaceChange);

    final isClient = NetworkConfig.instance.isClient;

    final medicineRepo = isClient ? HttpMedicineRepository() : SqliteMedicineRepository();
    final inventoryRepo = isClient ? HttpInventoryRepository() : SqliteInventoryRepository();
    final customerRepo = isClient ? HttpCustomerRepository() : SqliteCustomerRepository();
    final batchRepo = isClient ? HttpBatchRepository() : SqliteBatchRepository();
    final salesRepo = isClient ? HttpSalesRepository() : SqliteSalesRepository();
    final posRepo = isClient ? HttpPosRepository(batchRepo: batchRepo) : SqlitePosRepository();
    final purchaseRepo = isClient ? HttpPurchaseRepository() : SqlitePurchaseRepository();
    final supplierRepo = isClient ? HttpSupplierRepository() : SqliteSupplierRepository();
    final categoryRepo = isClient ? HttpCategoryRepository() : SqliteCategoryRepository();
    final reportRepo = isClient ? HttpReportRepository() : SqliteReportRepository();
    final accountRepo = isClient ? HttpAccountRepository() : SqliteAccountRepository();
    final expenseRepo = isClient ? HttpExpenseRepository() : SqliteExpenseRepository();
    final userRepo = isClient ? HttpUserRepository() : SqliteUserRepository();

    final settingsRepo = SqliteSettingsRepository();

    _medicineController = MedicineController(repository: medicineRepo);
    _inventoryController = InventoryController(repository: inventoryRepo);
    _batchController = BatchController(repository: batchRepo);
    _categoryController = CategoryController(repository: categoryRepo);
    _posCartController = PosCartController(repository: posRepo);
    _salesController = SalesController(
      salesRepository: salesRepo,
      inventoryRepository: inventoryRepo,
      customerRepository: customerRepo,
    );
    _purchaseController = PurchaseController(
      purchaseRepository: purchaseRepo,
      inventoryRepository: inventoryRepo,
      batchRepository: batchRepo,
      supplierRepository: supplierRepo,
    );
    _customerController = CustomerController(repository: customerRepo);
    _supplierController = SupplierController(repository: supplierRepo);
    _accountController = AccountController(repository: accountRepo);
    _expenseController = ExpenseController(
      expenseRepository: expenseRepo,
      accountRepository: accountRepo,
    );
    _reportController = ReportController(repository: reportRepo);
    _userController = UserController(repository: userRepo);
    _settingsController = SettingsController(repository: settingsRepo);
    _licenseController = LicenseController(repository: MockLicenseRepository());
    _backupController = BackupController();
    _networkController = NetworkController(settingsRepo: settingsRepo);

    _moreSections =
        MoreSection.values.where((s) => s.isAllowedFor(user)).toList();
    _salesTabs = [
      if (_can(PermissionCategory.sales, PermissionAction.add))
        _SubTab(
          'Point of Sale (POS)',
              () => PosScreen(
            controller: _posCartController,
            salesController: _salesController,
            authController: widget.authController,
          ),
        ),
      if (_can(PermissionCategory.sales, PermissionAction.view))
        _SubTab(
          'Sales History & Returns',
              () => SalesHistoryScreen(
            controller: _salesController,
            authController: widget.authController,
          ),
        ),
    ];

    _inventoryTabCtrl = TabController(length: 3, vsync: this);
    _salesTabCtrl =
        TabController(length: math.max(1, _salesTabs.length), vsync: this);
    _moreTabCtrl =
        TabController(length: math.max(1, _moreSections.length), vsync: this);

    _pages = [
      _gatedPage(
        NavigationItem.home,
            () => BusinessDashboardScreen(
          controller: _reportController,
          onNavigateToTab: (int index) {
            _navigateToIndex(index);
            if (index == 3) {
              _inventoryTabCtrl.animateTo(1);
            } else if (index == 1 && _salesTabs.isNotEmpty) {
              _salesTabCtrl.animateTo(0);
            }
          },
        ),
      ),
      _gatedPage(NavigationItem.sales, _buildSalesPage),
      _gatedPage(
        NavigationItem.purchases,
            () => PurchaseWorkspaceScreen(
          controller: _purchaseController,
          batchController: _batchController,
          authController: widget.authController,
        ),
      ),
      _gatedPage(NavigationItem.inventory, _buildInventoryPage),
      _gatedPage(
        NavigationItem.medicines,
            () => MedicineListScreen(
          controller: _medicineController,
          authController: widget.authController,
        ),
      ),
      _gatedPage(
        NavigationItem.customers,
            () => CustomerListScreen(
          controller: _customerController,
          authController: widget.authController,
        ),
      ),
      _gatedPage(
        NavigationItem.suppliers,
            () => SupplierListScreen(
          controller: _supplierController,
          authController: widget.authController,
        ),
      ),
      _gatedPage(
        NavigationItem.accounts,
            () => AccountsScreen(
          controller: _accountController,
          authController: widget.authController,
        ),
      ),
      _gatedPage(
        NavigationItem.reports,
            () => ReportsScreen(controller: _reportController),
      ),
      _gatedPage(NavigationItem.more, _buildMorePage),
    ];

    if (isClient) {
      DataSyncService.instance.addListener(_onRemoteDataChanged);
      DataSyncService.instance.start(interval: const Duration(seconds: 2));
    } else {
      // Connect local Server UI to background API mutation broadcasts
      ApiServer.onServerDataChanged.addListener(_onRemoteDataChanged);
    }
  }

  bool _can(PermissionCategory c, PermissionAction a) =>
      widget.authController.currentUser?.can(c, a) ?? false;

  VoidCallback? _gatedCallback(
      PermissionCategory c, PermissionAction a, VoidCallback cb) {
    return _can(c, a) ? cb : null;
  }

  Widget _gatedPage(NavigationItem item, Widget Function() build) {
    return item.isAllowedFor(widget.authController.currentUser)
        ? _wrap(build())
        : const SizedBox.shrink();
  }

  Widget _noAccess() => const Center(
    child: Text('You do not have permission to view this section.'),
  );

  Widget _moreSectionWidget(MoreSection s) {
    switch (s) {
      case MoreSection.expenses:
        return ExpensesScreen(
          controller: _expenseController,
          accountController: _accountController,
          authController: widget.authController,
        );
      case MoreSection.categories:
        return CategoriesScreen(
          controller: _categoryController,
          authController: widget.authController,
        );
      case MoreSection.users:
        return UsersScreen(
          controller: _userController,
          authController: widget.authController,
        );
      case MoreSection.roles:
        return RolesScreen(
          controller: _userController,
          authController: widget.authController,
        );
      case MoreSection.settings:
        return SettingsScreen(
          controller: _settingsController,
          authController: widget.authController,
        );
      case MoreSection.network:
        return NetworkSettingsScreen(controller: _networkController);
      case MoreSection.license:
        return LicenseScreen(controller: _licenseController);
      case MoreSection.backup:
        return BackupScreen(controller: _backupController);
    }
  }

  void _onRemoteDataChanged() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _reloadAllData();
    });
  }

  Future<void> _reloadAllData() async {
    final user = widget.authController.currentUser;
    if (user == null) return;

    if (NavigationItem.home.isAllowedFor(user)) {
      _reportController.loadMetrics(silent: true);
    }
    if (NavigationItem.sales.isAllowedFor(user)) {
      _salesController.loadHistory(silent: true);
    }
    if (NavigationItem.purchases.isAllowedFor(user)) {
      _purchaseController.loadPurchases(silent: true);
    }
    if (NavigationItem.inventory.isAllowedFor(user)) {
      _inventoryController.loadStockLevels(silent: true);
      _batchController.loadBatches(silent: true);
    }
    if (NavigationItem.medicines.isAllowedFor(user)) {
      _medicineController.loadMedicines(silent: true);
    }
    if (NavigationItem.customers.isAllowedFor(user)) {
      _customerController.loadCustomers(silent: true);
    }
    if (NavigationItem.suppliers.isAllowedFor(user)) {
      _supplierController.loadSuppliers(silent: true);
    }
    if (NavigationItem.accounts.isAllowedFor(user)) {
      _accountController.loadAccounts(silent: true);
    }
    if (NavigationItem.reports.isAllowedFor(user)) {
      _reportController.generateReport(silent: true);
    }
    if (MoreSection.expenses.isAllowedFor(user)) {
      _expenseController.loadAll(silent: true);
    }
    if (MoreSection.categories.isAllowedFor(user)) {
      _categoryController.loadAll(silent: true);
    }
    if (MoreSection.users.isAllowedFor(user)) {
      _userController.loadUsers(silent: true);
    }
    if (MoreSection.roles.isAllowedFor(user)) {
      _userController.loadRoles(silent: true);
    }
  }

  Widget _wrap(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: child,
    );
  }

  Widget _buildSalesPage() {
    if (_salesTabs.isEmpty) return _noAccess();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _salesTabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _salesTabs) Tab(text: t.label)],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: TabBarView(
            controller: _salesTabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final t in _salesTabs) t.build()],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _inventoryTabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Live Stock'),
            Tab(text: 'Batches'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: TabBarView(
            controller: _inventoryTabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              InventoryDashboardScreen(
                inventoryController: _inventoryController,
                batchController: _batchController,
              ),
              InventoryListScreen(
                controller: _inventoryController,
                authController: widget.authController,
              ),
              BatchListScreen(
                controller: _batchController,
                authController: widget.authController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMorePage() {
    if (_moreSections.isEmpty) return _noAccess();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.apps_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Text('Administration & Settings', style: AppTypography.pageTitle),
        ]),
        const SizedBox(height: AppSpacing.lg),
        TabBar(
          controller: _moreTabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final s in _moreSections) Tab(text: s.label)],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: TabBarView(
            controller: _moreTabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final s in _moreSections) _moreSectionWidget(s)],
          ),
        ),
      ],
    );
  }

  void _onNavChange() {
    _workspaceController.setActiveContext(_navController.selectedItem.name);
    setState(() {});
  }

  void _onWorkspaceChange() => setState(() {});

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    if (NetworkConfig.instance.isClient) {
      DataSyncService.instance.removeListener(_onRemoteDataChanged);
      DataSyncService.instance.stop();
    } else {
      ApiServer.onServerDataChanged.removeListener(_onRemoteDataChanged);
    }

    _navController.removeListener(_onNavChange);
    _navController.dispose();
    _workspaceController.removeListener(_onWorkspaceChange);
    _workspaceController.dispose();
    _inventoryTabCtrl.dispose();
    _salesTabCtrl.dispose();
    _moreTabCtrl.dispose();
    _medicineController.dispose();
    _inventoryController.dispose();
    _batchController.dispose();
    _categoryController.dispose();
    _posCartController.dispose();
    _salesController.dispose();
    _purchaseController.dispose();
    _customerController.dispose();
    _supplierController.dispose();
    _accountController.dispose();
    _expenseController.dispose();
    _reportController.dispose();
    _userController.dispose();
    _settingsController.dispose();
    _licenseController.dispose();
    _backupController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  void _navigateToIndex(int index) {
    final navValues = NavigationItem.values;
    final user = widget.authController.currentUser;

    if (index >= 0 && index < navValues.length) {
      final item = navValues[index];
      if (item.isAllowedFor(user)) {
        _navController.selectItem(item);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: You do not have permission to view this section.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openSearchDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GlobalSearchDialog(
        user: widget.authController.currentUser,
        onSelectTab: _navigateToIndex,
      ),
    );
  }

  void _handleDismiss() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your role has no permissions assigned. Contact an administrator.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.authController.logout,
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _navController.selectedItem;
    final selectedIndex = selected.index;

    return AppShortcutScope(
      onQuickSearch: _openSearchDialog,
      onToggleFullscreen: () {},
      onDismiss: _handleDismiss,
      onNewSale: _gatedCallback(
        PermissionCategory.sales,
        PermissionAction.add,
            () {
          _navigateToIndex(1);
          if (_salesTabs.isNotEmpty) _salesTabCtrl.animateTo(0);
        },
      ),
      onNewPurchase: _gatedCallback(
        PermissionCategory.purchases,
        PermissionAction.add,
            () => _navigateToIndex(2),
      ),
      onNewMedicine: _gatedCallback(
        PermissionCategory.medicines,
        PermissionAction.add,
            () => _navigateToIndex(4),
      ),
      onRefreshData: _reloadAllData,
      onNavigateToTab: _navigateToIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AppResponsiveLayout(
          builder: (context, breakpoint, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _workspaceController.updateBreakpoint(breakpoint);
            });

            return Column(
              children: [
                TopBar(
                  onSearchTap: _openSearchDialog,
                  authController: widget.authController,
                ),
                TopNavBar(
                  selectedItem: selected,
                  onItemSelected: _navigateToIndex,
                  user: widget.authController.currentUser,
                ),
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    sizing: StackFit.expand,
                    children: _pages,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}