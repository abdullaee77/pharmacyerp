import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../features/users/domain/role.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'pharmasuite.db';
  static const int _dbVersion = 13;
  static const int _maxBackups = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> get databaseFilePath async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _dbName);
  }

  /// Backup folder: Documents/PharmaSuite Backups/
  static Future<String> get backupDirectoryPath async {
    String basePath;
    final userProfile =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (userProfile != null && userProfile.isNotEmpty) {
      basePath = p.join(userProfile, 'Documents', 'PharmaSuite Backups');
    } else {
      final dbPath = await getDatabasesPath();
      basePath = p.join(dbPath, 'backups');
    }
    final dir = Directory(basePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return basePath;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await db.execute('PRAGMA journal_mode=WAL');
    await db.execute('PRAGMA synchronous=NORMAL');
    return db;
  }

  Future<void> closeAndReopen() async {
    await close();
    _database = await _initDatabase();
  }

  /// Creates a backup in Documents/PharmaSuite Backups/
  /// Uses live SQLite VACUUM INTO to avoid Windows file sharing lock errors.
  /// Keeps only the last 3 backups, automatically deleting older ones.
  static Future<String?> createBackup() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final backupDir = await backupDirectoryPath;

      final now = DateTime.now();
      final ts = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final fileName = 'PharmaSuite_Backup_$ts.db';
      final targetPath = p.join(backupDir, fileName);

      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 1. Live SQLite snapshot (prevents sharing lock conflicts on Windows)
      final escapedPath = targetPath.replaceAll(r'\', '/');
      try {
        await db.execute("VACUUM INTO '$escapedPath'");
      } catch (_) {
        // Fallback: Checkpoint WAL and copy file
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        final dbPath = await DatabaseHelper.instance.databaseFilePath;
        final sourceFile = File(dbPath);
        await sourceFile.copy(targetPath);
      }

      // 2. Keep only the newest 3 backups
      await _cleanupOldBackups(backupDir);

      return targetPath;
    } catch (e, stack) {
      debugPrint('DatabaseHelper.createBackup error: $e\n$stack');
      return null;
    }
  }

  /// Deletes oldest backups so only [_maxBackups] remain.
  static Future<void> _cleanupOldBackups(String backupDir) async {
    try {
      final dir = Directory(backupDir);
      if (!await dir.exists()) return;

      final files = await dir
          .list()
          .where((e) => e is File && e.path.toLowerCase().endsWith('.db'))
          .cast<File>()
          .toList();

      if (files.length <= _maxBackups) return;

      // Sort by filename timestamp ascending (oldest first)
      files.sort((a, b) => a.path.compareTo(b.path));

      final toDelete = files.take(files.length - _maxBackups);
      for (final f in toDelete) {
        await f.delete();
      }
    } catch (_) {}
  }

  // ──────────────────────────── Schema ────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createMedicinesTable(db);
    await _createInventoryTables(db);
    await _createBatchesTable(db);
    await _createClassificationTables(db);
    await _createSalesTables(db);
    await _createPurchaseTables(db);
    await _createCustomerTables(db);
    await _createSupplierTables(db);
    await _createAccountsTables(db);
    await _createExpensesTables(db);
    await _createUsersTables(db);
    await _seedBuiltInPermissions(db);
    await _createSettingsTable(db);
    await _createConnectedClientsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createInventoryTables(db);
    if (oldVersion < 3) await _createBatchesTable(db);
    if (oldVersion < 4) await _createClassificationTables(db);
    if (oldVersion < 5) await _createSalesTables(db);
    if (oldVersion < 6) await _createPurchaseTables(db);
    if (oldVersion < 7) {
      await _createCustomerTables(db);
      await _createSupplierTables(db);
    }
    if (oldVersion < 8) {
      await _createAccountsTables(db);
      await _createExpensesTables(db);
    }
    if (oldVersion < 9) {
      await _createUsersTables(db);
      await _createSettingsTable(db);
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE medicines ADD COLUMN box_size INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE medicines ADD COLUMN box_price INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 11) {
      await db.execute("ALTER TABLE medicines ADD COLUMN rack_location TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE medicines ADD COLUMN drug_schedule TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE medicines ADD COLUMN storage_instructions TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE medicines ADD COLUMN unit TEXT NOT NULL DEFAULT 'Tab'");
    }
    if (oldVersion < 12) {
      await _createConnectedClientsTable(db);
    }
    if (oldVersion < 13) {
      await _seedBuiltInPermissions(db);
    }
  }

  Future<void> _createMedicinesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        generic_name TEXT NOT NULL DEFAULT '',
        manufacturer TEXT NOT NULL DEFAULT '',
        dosage_form TEXT NOT NULL DEFAULT '',
        strength TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT 'Tab',
        rack_location TEXT NOT NULL DEFAULT '',
        drug_schedule TEXT NOT NULL DEFAULT '',
        storage_instructions TEXT NOT NULL DEFAULT '',
        barcode TEXT UNIQUE,
        prescription_required INTEGER NOT NULL DEFAULT 0,
        min_stock_level INTEGER NOT NULL DEFAULT 0,
        purchase_price INTEGER NOT NULL DEFAULT 0,
        selling_price INTEGER NOT NULL DEFAULT 0,
        mrp INTEGER NOT NULL DEFAULT 0,
        box_size INTEGER NOT NULL DEFAULT 1,
        box_price INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_medicines_name ON medicines(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_medicines_generic ON medicines(generic_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_medicines_barcode ON medicines(barcode)');
  }

  Future<void> _createInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_stocks (
        medicine_id TEXT PRIMARY KEY,
        quantity INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_movements (
        id TEXT PRIMARY KEY,
        medicine_id TEXT NOT NULL,
        batch_id TEXT,
        type TEXT NOT NULL,
        quantity_changed INTEGER NOT NULL,
        reason TEXT,
        reference TEXT,
        operator_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createBatchesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS batches (
        id TEXT PRIMARY KEY,
        medicine_id TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        purchase_price INTEGER NOT NULL DEFAULT 0,
        selling_price INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createClassificationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS manufacturers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        contact TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSalesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_name TEXT NOT NULL,
        operator_name TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER NOT NULL,
        grand_total INTEGER NOT NULL,
        amount_received INTEGER NOT NULL,
        change_amount INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        medicine_strength TEXT NOT NULL,
        batch_id TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        discount_percent INTEGER NOT NULL,
        line_total INTEGER NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_payments (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        method TEXT NOT NULL,
        amount INTEGER NOT NULL,
        reference TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_returns (
        id TEXT PRIMARY KEY,
        original_sale_id TEXT NOT NULL,
        original_invoice_number TEXT NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        total_refund INTEGER NOT NULL,
        operator_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (original_sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_return_items (
        id TEXT PRIMARY KEY,
        return_id TEXT NOT NULL,
        original_sale_item_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        batch_id TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        refund_amount INTEGER NOT NULL,
        FOREIGN KEY (return_id) REFERENCES sales_returns (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createPurchaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL UNIQUE,
        supplier_name TEXT NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER NOT NULL,
        grand_total INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        purchase_price INTEGER NOT NULL,
        selling_price INTEGER NOT NULL,
        line_total INTEGER NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_returns (
        id TEXT PRIMARY KEY,
        original_purchase_id TEXT NOT NULL,
        original_invoice_number TEXT NOT NULL,
        supplier_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        total_refund INTEGER NOT NULL,
        operator_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (original_purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_return_items (
        id TEXT PRIMARY KEY,
        return_id TEXT NOT NULL,
        original_purchase_item_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        refund_amount INTEGER NOT NULL,
        FOREIGN KEY (return_id) REFERENCES purchase_returns (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCustomerTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        credit_limit INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_ledger_entries (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        description TEXT NOT NULL,
        reference TEXT,
        debit INTEGER NOT NULL DEFAULT 0,
        credit INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT,
        operator_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSupplierTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact_person TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        payment_terms TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_ledger_entries (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        description TEXT NOT NULL,
        reference TEXT,
        debit INTEGER NOT NULL DEFAULT 0,
        credit INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT,
        operator_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAccountsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        source TEXT NOT NULL,
        description TEXT NOT NULL,
        reference TEXT,
        debit INTEGER NOT NULL DEFAULT 0,
        credit INTEGER NOT NULL DEFAULT 0,
        operator_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createExpensesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        account_id TEXT,
        reference TEXT,
        operator_name TEXT NOT NULL,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');
    final defaults = ['Rent', 'Utilities', 'Salaries', 'Maintenance', 'Transport', 'Supplies', 'Other'];
    final now = DateTime.now().toIso8601String();
    for (final name in defaults) {
      await db.insert(
        'expense_categories',
        {'id': 'ec_${name.toLowerCase()}', 'name': name, 'description': '', 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createUsersTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        is_built_in INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        role_id TEXT NOT NULL,
        category TEXT NOT NULL,
        action TEXT NOT NULL,
        PRIMARY KEY (role_id, category, action),
        FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL DEFAULT '',
        role_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        password_hash TEXT NOT NULL DEFAULT '',
        last_login_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT
      )
    ''');

    final now = DateTime.now().toIso8601String();
    final builtInRoles = [
      {'id': 'role_admin', 'name': 'Administrator', 'description': 'Full system access'},
      {'id': 'role_manager', 'name': 'Manager', 'description': 'Management access excluding licensing'},
      {'id': 'role_pharmacist', 'name': 'Pharmacist', 'description': 'Pharmacy operations access'},
      {'id': 'role_cashier', 'name': 'Cashier', 'description': 'POS and basic customer access'},
    ];
    for (final r in builtInRoles) {
      await db.insert(
        'roles',
        {...r, 'is_built_in': 1, 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final hash = sha256.convert(utf8.encode('admin123')).toString();
    await db.insert(
      'users',
      {
        'id': 'usr_default_admin',
        'full_name': 'System Administrator',
        'username': 'admin',
        'phone': '',
        'role_id': 'role_admin',
        'status': 'active',
        'password_hash': hash,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _seedBuiltInPermissions(Database db) async {
    for (final roleId in [
      RoleId.admin,
      RoleId.manager,
      RoleId.pharmacist,
      RoleId.cashier,
    ]) {
      final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM role_permissions WHERE role_id = ?',
        [roleId.value],
      )) ??
          0;
      if (count > 0) continue;

      final batch = db.batch();
      for (final perm in Permission.defaultsFor(roleId)) {
        batch.insert(
          'role_permissions',
          {
            'role_id': roleId.value,
            'category': perm.category.name,
            'action': perm.action.name,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createConnectedClientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS connected_clients (
        client_id TEXT PRIMARY KEY,
        pc_name TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        connected_at TEXT NOT NULL,
        last_heartbeat TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}