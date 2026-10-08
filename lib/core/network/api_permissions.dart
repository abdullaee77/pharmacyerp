// lib/core/network/api_permissions.dart

class ApiSession {
  final String token;
  final String userId;
  final String username;
  final String fullName;
  String roleId;
  Set<String> permissions;
  DateTime lastUsed;
  DateTime lastChecked;

  ApiSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.roleId,
    required this.permissions,
  })  : lastUsed = DateTime.now(),
        lastChecked = DateTime.now();

  bool get isAdmin => roleId == 'role_admin';

  bool has(String key) => isAdmin || permissions.contains(key);

  bool hasAny(List<String> keys) => isAdmin || keys.any(permissions.contains);

  bool hasAnyIn(String category) =>
      isAdmin || permissions.any((p) => p.startsWith('$category.'));

  bool hasWriteIn(String category) =>
      isAdmin ||
          permissions.any(
                (p) => p.startsWith('$category.') && p != '$category.view',
          );
}

const List<String> _salesReaders = [
  'sales', 'reports', 'dashboard', 'accounts', 'customers',
];
const List<String> _purchaseReaders = [
  'purchases', 'reports', 'dashboard', 'accounts', 'suppliers',
];
const List<String> _referenceReaders = [
  'medicines', 'inventory', 'purchases', 'sales', 'reports', 'dashboard',
];
const List<String> _customerReaders = [
  'customers', 'sales', 'reports', 'dashboard', 'accounts',
];
const List<String> _supplierReaders = [
  'suppliers', 'purchases', 'reports', 'dashboard', 'accounts',
];
const List<String> _moneyReaders = [
  'accounts', 'reports', 'dashboard', 'sales', 'purchases', 'customers',
  'suppliers',
];

class ApiAccess {
  ApiAccess._();

  static const Map<String, List<String>> _read = {
    'medicines': _referenceReaders,
    'inventory_stocks': _referenceReaders,
    'inventory_movements': ['inventory', 'medicines', 'reports', 'dashboard'],
    'batches': _referenceReaders,
    'categories': _referenceReaders,
    'manufacturers': _referenceReaders,
    'sales': _salesReaders,
    'sale_items': _salesReaders,
    'sale_payments': _salesReaders,
    'sales_returns': _salesReaders,
    'sales_return_items': _salesReaders,
    'purchases': _purchaseReaders,
    'purchase_items': _purchaseReaders,
    'purchase_returns': _purchaseReaders,
    'purchase_return_items': _purchaseReaders,
    'customers': _customerReaders,
    'customer_ledger_entries': _customerReaders,
    'suppliers': _supplierReaders,
    'supplier_ledger_entries': _supplierReaders,
    'accounts': _moneyReaders,
    'financial_transactions': _moneyReaders,
    'expense_categories': ['accounts', 'reports', 'dashboard'],
    'expenses': ['accounts', 'reports', 'dashboard'],
    'roles': ['users'],
    'role_permissions': ['users'],
    'users': ['users'],
    'settings': [],
    'connected_clients': ['settings'],
  };

  static const Set<String> _protectedTables = {
    'users', 'roles', 'role_permissions', 'settings', 'connected_clients',
  };

  static bool knownTable(String table) => _read.containsKey(table);

  static bool canRead(ApiSession s, String table) {
    if (!_read.containsKey(table)) return false;
    if (s.isAdmin || table == 'settings') return true;
    return _read[table]!.any(s.hasAnyIn);
  }

  /// Returns null if the write is allowed, or an error message if not.
  /// Admin bypasses everything. Otherwise every table is now gated by the
  /// exact action (<module>.add / .edit / .delete / .adjust / etc.).
  static String? checkWrite(
      ApiSession s,
      String table,
      String op, {
        Map<String, dynamic>? data,
      }) {
    if (!_read.containsKey(table)) return 'Table not allowed.';
    if (op != 'insert' && op != 'update' && op != 'delete') {
      return 'Unknown operation.';
    }
    if (s.isAdmin) return null;

    final allowed = _allowed(s, table, op);
    if (!allowed) return 'Permission denied: cannot $op on $table.';

    // Extra rules for the users table.
    if (table == 'users' && data != null) {
      if (data['role_id'] == 'role_admin') {
        return 'Only an administrator can assign the administrator role.';
      }
      if (op == 'update' &&
          data.containsKey('role_id') &&
          !s.has('users.manage')) {
        return 'Changing a user\'s role requires the Manage permission.';
      }
    }
    return null;
  }

  /// Exact action-level check per table. Each table maps to its proper
  /// `<module>.<action>` permission, with `manage` as a universal override.
  static bool _allowed(ApiSession s, String table, String op) {
    switch (table) {
    // ── Medicines & reference data ───────────────────────────────
      case 'medicines':
        return _writeOne(s, 'medicines', op);
      case 'categories':
      case 'manufacturers':
      // Managed via medicines module (per Permission Mapping).
        return s.hasAny(['medicines.manage', 'medicines.$_a(op)']);

    // ── Inventory ────────────────────────────────────────────────
      case 'inventory_stocks':
      case 'inventory_movements':
      // Any stock change is an "adjust" operation.
        return s.hasAny(['inventory.adjust', 'inventory.manage']);
      case 'batches':
        return _writeOne(s, 'inventory', op);

    // ── Sales ────────────────────────────────────────────────────
      case 'sales':
      case 'sale_items':
      case 'sale_payments':
        return _writeOne(s, 'sales', op);
      case 'sales_returns':
      case 'sales_return_items':
        return s.hasAny(['sales.returnAction', 'sales.manage']);

    // ── Purchases ────────────────────────────────────────────────
      case 'purchases':
      case 'purchase_items':
        return _writeOne(s, 'purchases', op);
      case 'purchase_returns':
      case 'purchase_return_items':
        return s.hasAny(['purchases.returnAction', 'purchases.manage']);

    // ── Customers ────────────────────────────────────────────────
      case 'customers':
        return _writeOne(s, 'customers', op);
      case 'customer_ledger_entries':
      // Writes to customer ledger happen for new credit sales and
      // payments; allow sales.add OR customers.add OR accounts.add.
        return s.hasAny([
          'customers.add', 'customers.manage',
          'sales.add', 'sales.manage',
          'accounts.add', 'accounts.manage',
        ]);

    // ── Suppliers ────────────────────────────────────────────────
      case 'suppliers':
        return _writeOne(s, 'suppliers', op);
      case 'supplier_ledger_entries':
        return s.hasAny([
          'suppliers.add', 'suppliers.manage',
          'purchases.add', 'purchases.manage',
          'accounts.add', 'accounts.manage',
        ]);

    // ── Accounts & expenses ──────────────────────────────────────
      case 'accounts':
        return _writeOne(s, 'accounts', op);
      case 'financial_transactions':
      // Written by expenses, sales, purchases, customer/supplier payments.
        return s.hasAny([
          'accounts.add', 'accounts.manage',
          'sales.add', 'sales.manage',
          'purchases.add', 'purchases.manage',
          'customers.add', 'customers.manage',
          'suppliers.add', 'suppliers.manage',
        ]);
      case 'expense_categories':
        return s.hasAny(['accounts.manage', 'accounts.$_a(op)']);
      case 'expenses':
        return _writeOne(s, 'accounts', op);

    // ── Users & roles ────────────────────────────────────────────
      case 'users':
        if (op == 'insert') return s.hasAny(['users.add', 'users.manage']);
        if (op == 'update') return s.hasAny(['users.edit', 'users.manage']);
        return s.hasAny(['users.delete', 'users.manage']);
      case 'roles':
      case 'role_permissions':
        return s.has('users.manage');

    // ── Settings & network ───────────────────────────────────────
      case 'settings':
        return s.hasAny(['settings.edit', 'settings.manage']);
      case 'connected_clients':
        return s.has('settings.manage');
    }
    return false;
  }

  /// Standard CRUD mapping for a module: insert→add, update→edit, delete→delete.
  /// `manage` is a universal override.
  static bool _writeOne(ApiSession s, String module, String op) {
    final action = _a(op);
    return s.hasAny(['$module.manage', '$module.$action']);
  }

  static String _a(String op) {
    switch (op) {
      case 'insert':
        return 'add';
      case 'update':
        return 'edit';
      case 'delete':
        return 'delete';
    }
    return op;
  }

  // ── SQL scanning helpers (unchanged) ─────────────────────────────
  static final RegExp _literal = RegExp(r"'(?:[^']|'')*'");

  static final RegExp _tableWords = RegExp(
    r'\b(' + _read.keys.join('|') + r')\b',
    caseSensitive: false,
  );

  static final RegExp _targets = RegExp(
    r'''\b(?:from|join)\s*[("`\[']*\s*([A-Za-z_][A-Za-z0-9_]*)''',
    caseSensitive: false,
  );

  static String? scanTables(String sql, Set<String> out) {
    if (sql.contains(';') ||
        sql.contains('--') ||
        sql.contains('/*') ||
        sql.contains('*/')) {
      return 'Unsafe SQL fragment.';
    }
    final lower = sql.toLowerCase();
    for (final bad in const [
      'pragma', 'attach', 'sqlite_', 'load_extension', 'vacuum',
    ]) {
      if (lower.contains(bad)) return 'Unsafe SQL fragment.';
    }

    final stripped = sql.replaceAll(_literal, "''");
    for (final m in _tableWords.allMatches(stripped)) {
      out.add(m.group(1)!.toLowerCase());
    }

    for (final m in _targets.allMatches(sql)) {
      final name = m.group(1)!.toLowerCase();
      if (name == 'select' || name == 'with' || name == 'values') continue;
      if (!_read.containsKey(name)) return 'Table not allowed: $name';
      out.add(name);
    }

    for (final m in _literal.allMatches(sql)) {
      final text = m.group(0)!;
      final inner = text.substring(1, text.length - 1).trim().toLowerCase();
      if (_protectedTables.contains(inner)) out.add(inner);
    }
    return null;
  }
}