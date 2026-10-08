import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';

class RoleId extends ValueObject {
  final String value;
  const RoleId(this.value);

  factory RoleId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return RoleId('role_${ts}_$rand');
  }

  /// Well-known built-in role IDs.
  static const admin = RoleId('role_admin');
  static const manager = RoleId('role_manager');
  static const pharmacist = RoleId('role_pharmacist');
  static const cashier = RoleId('role_cashier');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RoleId &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Permission categories matching the application's feature modules.
enum PermissionCategory {
  dashboard(label: 'Dashboard'),
  sales(label: 'Sales / POS'),
  purchases(label: 'Purchases'),
  inventory(label: 'Inventory'),
  medicines(label: 'Medicines'),
  customers(label: 'Customers'),
  suppliers(label: 'Suppliers'),
  accounts(label: 'Accounts'),
  reports(label: 'Reports'),
  users(label: 'Users & Roles'),
  settings(label: 'Settings'),
  licensing(label: 'Licensing');

  final String label;
  const PermissionCategory({required this.label});
}

/// Granular permission actions.
enum PermissionAction {
  view(label: 'View'),
  add(label: 'Add / Create'),
  edit(label: 'Edit'),
  delete(label: 'Delete'),
  approve(label: 'Approve'),
  returnAction(label: 'Return'),
  discount(label: 'Discount'),
  adjust(label: 'Adjust Stock'),
  export(label: 'Export / Print'),
  manage(label: 'Manage');

  final String label;
  const PermissionAction({required this.label});
}

/// A single permission = category + action.
class Permission {
  final PermissionCategory category;
  final PermissionAction action;

  const Permission(this.category, this.action);

  String get key => '${category.name}.${action.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Permission &&
              runtimeType == other.runtimeType &&
              category == other.category &&
              action == other.action;

  @override
  int get hashCode => Object.hash(category, action);

  @override
  String toString() => key;

  /// All possible permissions.
  static List<Permission> get all => [
    for (final cat in PermissionCategory.values)
      for (final act in PermissionAction.values) Permission(cat, act),
  ];

  /// Default permissions per built-in role.
  static Set<Permission> defaultsFor(RoleId roleId) {
    if (roleId == RoleId.admin) return all.toSet();

    if (roleId == RoleId.manager) {
      return all
          .where((p) => p.category != PermissionCategory.licensing)
          .toSet();
    }

    if (roleId == RoleId.pharmacist) {
      return {
        const Permission(PermissionCategory.dashboard, PermissionAction.view),
        const Permission(PermissionCategory.sales, PermissionAction.view),
        const Permission(PermissionCategory.sales, PermissionAction.add),
        const Permission(PermissionCategory.sales, PermissionAction.edit),
        const Permission(
          PermissionCategory.sales,
          PermissionAction.returnAction,
        ),
        const Permission(PermissionCategory.purchases, PermissionAction.view),
        const Permission(PermissionCategory.inventory, PermissionAction.view),
        const Permission(PermissionCategory.inventory, PermissionAction.adjust),
        const Permission(PermissionCategory.medicines, PermissionAction.view),
        const Permission(PermissionCategory.medicines, PermissionAction.add),
        const Permission(PermissionCategory.medicines, PermissionAction.edit),
        const Permission(PermissionCategory.customers, PermissionAction.view),
        const Permission(PermissionCategory.customers, PermissionAction.add),
        const Permission(PermissionCategory.suppliers, PermissionAction.view),
        const Permission(PermissionCategory.reports, PermissionAction.view),
        const Permission(PermissionCategory.reports, PermissionAction.export),
      };
    }

    if (roleId == RoleId.cashier) {
      return {
        const Permission(PermissionCategory.dashboard, PermissionAction.view),
        const Permission(PermissionCategory.sales, PermissionAction.view),
        const Permission(PermissionCategory.sales, PermissionAction.add),
        const Permission(PermissionCategory.customers, PermissionAction.view),
        const Permission(PermissionCategory.customers, PermissionAction.add),
      };
    }

    return {};
  }
}

/// Builds a permission set from `role_permissions` rows. Unknown rows are skipped.
Set<Permission> permissionsFromRows(Iterable<Map<String, dynamic>> rows) {
  final result = <Permission>{};
  for (final r in rows) {
    final cats = PermissionCategory.values.where((e) => e.name == r['category']);
    final acts = PermissionAction.values.where((e) => e.name == r['action']);
    if (cats.isNotEmpty && acts.isNotEmpty) {
      result.add(Permission(cats.first, acts.first));
    }
  }
  return result;
}

/// Role entity.
class Role extends Entity<RoleId> {
  final String name;
  final String description;
  final bool isBuiltIn;
  final Set<Permission> permissions;
  final DateTime createdAt;

  const Role({
    required super.id,
    required this.name,
    this.description = '',
    this.isBuiltIn = false,
    this.permissions = const {},
    required this.createdAt,
  });

  bool hasPermission(Permission p) => permissions.contains(p);

  bool hasPermissionIn(PermissionCategory cat) =>
      permissions.any((p) => p.category == cat);

  Role copyWith({
    String? name,
    String? description,
    Set<Permission>? permissions,
  }) {
    return Role(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      isBuiltIn: isBuiltIn,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt,
    );
  }
}