import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../users/domain/role.dart';
import '../../domain/customer.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_form_dialog.dart';
import '../widgets/customer_profile_dialog.dart';

class CustomerListScreen extends StatefulWidget {
  final CustomerController controller;
  final AuthController authController;

  const CustomerListScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadCustomers();
    });
  }

  bool get _canAdd => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.customers, PermissionAction.add);
  bool get _canEdit => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.customers, PermissionAction.edit);
  bool get _canDelete => PermissionGate.allow(widget.authController.currentUser,
      PermissionCategory.customers, PermissionAction.delete);

  Future<void> _addCustomer() async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => CustomerFormDialog(controller: widget.controller),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Customer added.');
    }
  }

  Future<void> _editCustomer(Customer c) async {
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          CustomerFormDialog(controller: widget.controller, existing: c),
    );
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'Customer updated.');
    }
  }

  Future<void> _openProfile(CustomerWithBalance cwb) async {
    await showDialog(
      context: context,
      builder: (ctx) => CustomerProfileDialog(
        controller: widget.controller,
        customer: cwb,
        operatorName:
        widget.authController.currentUser?.fullName ?? 'Operator',
        user: widget.authController.currentUser,
        onEdit: _canEdit
            ? () {
          Navigator.of(ctx).pop();
          _editCustomer(cwb.customer);
        }
            : null,
      ),
    );
  }

  Future<void> _deleteCustomer(Customer c) async {
    final ok = await AppDialog.warning(
      context,
      title: 'Delete Customer?',
      message:
      '"${c.name}" and all their ledger entries will be removed permanently.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      final error = await widget.controller.deleteCustomer(c.id);
      if (!mounted) return;
      if (error != null) {
        AppToast.error(context, error);
      } else {
        AppToast.success(context, 'Customer deleted.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customers', style: AppTypography.pageTitle),
                    Text(
                      '${ctrl.customers.length} customers registered',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                if (_canAdd)
                  AppButton(
                    label: 'Add Customer',
                    icon: Icons.person_add_outlined,
                    variant: AppButtonVariant.primary,
                    onPressed: _addCustomer,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchBar(
              hint: 'Search by name, phone, or email...',
              maxWidth: 420,
              onSearch: ctrl.search,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildTable(ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildTable(CustomerController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(message: 'Loading customers...');
    }
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.loadCustomers,
      );
    }
    if (ctrl.customers.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No customers yet',
        subtitle:
        'Add your first customer to start tracking credit sales and payments.',
        actionLabel: _canAdd ? 'Add Customer' : null,
        onAction: _canAdd ? _addCustomer : null,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 52,
            horizontalMargin: AppSpacing.lg,
            columnSpacing: AppSpacing.xl,
            headingRowColor: WidgetStatePropertyAll(AppColors.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Credit Limit'), numeric: true),
              DataColumn(label: Text('Outstanding'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: ctrl.customers.map((cwb) {
              final c = cwb.customer;
              final out = cwb.outstanding;
              final outColor =
              out.paisa > 0 ? AppColors.warning : AppColors.textPrimary;

              return DataRow(
                onSelectChanged: (_) => _openProfile(cwb),
                cells: [
                  DataCell(
                    Text(
                      c.name,
                      style: AppTypography.tableCell.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      c.phone.isEmpty ? '—' : c.phone,
                      style: AppTypography.tableCell,
                    ),
                  ),
                  DataCell(
                    Text(
                      c.creditLimit.paisa == 0 ? '—' : c.creditLimit.display,
                      style: AppTypography.numericSmall,
                    ),
                  ),
                  DataCell(
                    Text(
                      out.paisa == 0 ? '—' : out.display,
                      style: AppTypography.numeric.copyWith(
                        color: outColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DataCell(
                    AppBadge(
                      label: c.status.label,
                      variant: c.status == CustomerStatus.active
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.neutral,
                      isDot: true,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          tooltip: 'View / Payments',
                          splashRadius: 16,
                          onPressed: () => _openProfile(cwb),
                        ),
                        if (_canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            tooltip: 'Edit',
                            splashRadius: 16,
                            onPressed: () => _editCustomer(c),
                          ),
                        if (_canDelete)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            tooltip: 'Delete',
                            splashRadius: 16,
                            onPressed: () => _deleteCustomer(c),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}