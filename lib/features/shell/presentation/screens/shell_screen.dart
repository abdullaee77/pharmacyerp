import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_shortcut_scope.dart';
import '../../../../core/widgets/app_responsive_layout.dart';
import '../../../accounts/data/sqlite_account_repository.dart';
import '../../../accounts/presentation/controllers/account_controller.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../backup/presentation/controllers/backup_controller.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../barcodes/presentation/controllers/barcode_controller.dart';
import '../../../barcodes/presentation/screens/barcode_management_screen.dart';
import '../../../categories/data/sqlite_category_repository.dart';
import '../../../categories/presentation/controllers/category_controller.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../customers/data/sqlite_customer_repository.dart';
import '../../../customers/presentation/controllers/customer_controller.dart';
import '../../../customers/presentation/screens/customer_list_screen.dart';
import '../../../expenses/data/sqlite_expense_repository.dart';
import '../../../expenses/presentation/controllers/expense_controller.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../inventory/data/sqlite_inventory_repository.dart';
import '../../../inventory/data/sqlite_batch_repository.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';
import '../../../inventory/presentation/controllers/batch_controller.dart';
import '../../../inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../../inventory/presentation/screens/inventory_list_screen.dart';
import '../../../inventory/presentation/screens/batch_list_screen.dart';
import '../../../licensing/data/mock_license_repository.dart';
import '../../../licensing/presentation/controllers/license_controller.dart';
import '../../../licensing/presentation/screens/license_screen.dart';
import '../../../medicines/data/sqlite_medicine_repository.dart';
import '../../../medicines/presentation/controllers/medicine_controller.dart';
import '../../../medicines/presentation/screens/medicine_list_screen.dart';
import '../../../purchases/data/sqlite_purchase_repository.dart';
import '../../../purchases/presentation/controllers/purchase_controller.dart';
import '../../../purchases/presentation/screens/purchase_workspace_screen.dart';
import '../../../reports/data/sqlite_report_repository.dart';
import '../../../reports/presentation/controllers/report_controller.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../reports/presentation/screens/business_dashboard_screen.dart';
import '../../../sales/data/sqlite_pos_repository.dart';
import '../../../sales/data/sqlite_sales_repository.dart';
import '../../../sales/presentation/controllers/pos_cart_controller.dart';
import '../../../sales/presentation/controllers/sales_controller.dart';
import '../../../sales/presentation/screens/pos_screen.dart';
import '../../../sales/presentation/screens/sales_history_screen.dart';
import '../../../settings/data/sqlite_settings_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../suppliers/data/sqlite_supplier_repository.dart';
import '../../../suppliers/presentation/controllers/supplier_controller.dart';
import '../../../suppliers/presentation/screens/supplier_list_screen.dart';
import '../../../users/data/sqlite_user_repository.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../../users/presentation/screens/users_screen.dart';
import '../../../users/presentation/screens/roles_screen.dart';
import '../../domain/navigation_item.dart';
import '../controllers/shell_controller.dart';
import '../controllers/workspace_controller.dart';
import '../widgets/top_bar.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/global_search_dialog.dart';

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
  late final BarcodeController _barcodeController;
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

  late final TabController _inventoryTabCtrl;
  late final TabController _salesTabCtrl;
  late final TabController _moreTabCtrl;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _navController = ShellController();
    _navController.addListener(_onNavChange);
    _workspaceController = WorkspaceController();
    _workspaceController.addListener(_onWorkspaceChange);

    _inventoryTabCtrl = TabController(length: 3, vsync: this);
    _salesTabCtrl = TabController(length: 2, vsync: this);
    _moreTabCtrl = TabController(length: 8, vsync: this);

    final medicineRepo = SqliteMedicineRepository();
    final inventoryRepo = SqliteInventoryRepository();
    final salesRepo = SqliteSalesRepository();
    final purchaseRepo = SqlitePurchaseRepository();
    final batchRepo = SqliteBatchRepository();
    final customerRepo = SqliteCustomerRepository();
    final supplierRepo = SqliteSupplierRepository();
    final accountRepo = SqliteAccountRepository();
    final expenseRepo = SqliteExpenseRepository();
    final reportRepo = SqliteReportRepository();
    final userRepo = SqliteUserRepository();
    final settingsRepo = SqliteSettingsRepository();

    _medicineController = MedicineController(repository: medicineRepo);
    _inventoryController = InventoryController(repository: inventoryRepo);
    _batchController = BatchController(repository: batchRepo);
    _barcodeController = BarcodeController(medicineRepository: medicineRepo);
    _categoryController = CategoryController(repository: SqliteCategoryRepository());
    _posCartController = PosCartController(repository: SqlitePosRepository());
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

    _pages = [
      _wrap(BusinessDashboardScreen(
        controller: _reportController,
        onNavigateToTab: (int index) {
          _navigateToIndex(index);
          if (index == 3) {
            _inventoryTabCtrl.animateTo(1);
          } else if (index == 1) {
            _salesTabCtrl.animateTo(0);
          }
        },
      )),
      _wrap(_buildSalesPage()),
      _wrap(PurchaseWorkspaceScreen(
        controller: _purchaseController,
        batchController: _batchController,
        authController: widget.authController,
      )),
      _wrap(_buildInventoryPage()),
      _wrap(MedicineListScreen(controller: _medicineController)),
      _wrap(CustomerListScreen(
        controller: _customerController,
        authController: widget.authController,
      )),
      _wrap(SupplierListScreen(
        controller: _supplierController,
        authController: widget.authController,
      )),
      _wrap(AccountsScreen(controller: _accountController)),
      _wrap(ReportsScreen(controller: _reportController)),
      _wrap(_buildMorePage()),
    ];
  }

  Widget _wrap(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: child,
    );
  }

  Widget _buildSalesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _salesTabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Point of Sale (POS)'),
            Tab(text: 'Sales History & Returns'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: TabBarView(
            controller: _salesTabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              PosScreen(
                controller: _posCartController,
                salesController: _salesController,
                authController: widget.authController,
              ),
              SalesHistoryScreen(
                controller: _salesController,
                authController: widget.authController,
              ),
            ],
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
            Tab(text: 'Overview Dashboard'),
            Tab(text: 'Live Stock Levels'),
            Tab(text: 'Batches & Expiry'),
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
              BatchListScreen(controller: _batchController),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMorePage() {
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
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Categories & Manufacturers'),
            Tab(text: 'Barcode Management'),
            Tab(text: 'Users'),
            Tab(text: 'Roles & Permissions'),
            Tab(text: 'Application Settings'),
            Tab(text: 'License'),
            Tab(text: 'Backup & Network'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: TabBarView(
            controller: _moreTabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ExpensesScreen(
                controller: _expenseController,
                accountController: _accountController,
                authController: widget.authController,
              ),
              CategoriesScreen(controller: _categoryController),
              BarcodeManagementScreen(controller: _barcodeController),
              UsersScreen(controller: _userController),
              RolesScreen(controller: _userController),
              SettingsScreen(controller: _settingsController),
              LicenseScreen(controller: _licenseController),
              BackupScreen(controller: _backupController),
            ],
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
    _barcodeController.dispose();
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
    super.dispose();
  }

  void _navigateToIndex(int index) {
    final navValues = NavigationItem.values;
    if (index >= 0 && index < navValues.length) {
      _navController.selectItem(navValues[index]);
    }
  }

  void _openSearchDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GlobalSearchDialog(
        onSelectTab: (int index) {
          _navigateToIndex(index);
        },
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
    final selected = _navController.selectedItem;
    final selectedIndex = selected.index;

    return AppShortcutScope(
      onQuickSearch: _openSearchDialog,
      onToggleFullscreen: () {},
      onDismiss: _handleDismiss,
      onNewSale: () {
        _navigateToIndex(1);
        _salesTabCtrl.animateTo(0);
      },
      onNewPurchase: () => _navigateToIndex(2),
      onNewMedicine: () => _navigateToIndex(4),
      onRefreshData: () {},
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
                  onItemSelected: _navController.selectItem,
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