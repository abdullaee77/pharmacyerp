// lib/features/licensing/data/mock_license_repository.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:pharmacy/core/data/database_helper.dart';
import 'package:pharmacy/core/error/failures.dart';
import 'package:pharmacy/core/result/result.dart';
import 'package:pharmacy/features/licensing/domain/license.dart';
import 'package:pharmacy/features/licensing/domain/license_repository.dart';

class MockLicenseRepository implements LicenseRepository {
  final DatabaseHelper _dbHelper;

  MockLicenseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<Result<LicenseInfo>> getLicenseInfo() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'settings',
        where: 'key LIKE ?',
        whereArgs: ['license_%'],
      );

      final settings = {for (final r in rows) r['key'] as String: r['value'] as String};

      final key = settings['license_key'] ?? '';
      if (key.isEmpty) {
        return const Success(LicenseInfo(
          productId: 'PHARMASUITE-ERP',
          edition: 'Express',
          status: LicenseStatus.activationRequired,
        ));
      }

      return _evaluateKey(key, settings['license_activation_date']);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read license settings: $e'));
    }
  }

  @override
  Future<Result<LicenseInfo>> activateLicense(String key) async {
    final sanitizedKey = key.trim();
    if (sanitizedKey.isEmpty) {
      return const Failure(ValidationFailure(message: 'License key cannot be empty.'));
    }

    final evalResult = await _evaluateKey(sanitizedKey, null);
    return evalResult.fold(
      onSuccess: (info) async {
        if (info.status == LicenseStatus.invalid) {
          return const Failure(ValidationFailure(message: 'Invalid license key entered.'));
        }

        try {
          final db = await _db;
          final batch = db.batch();
          final nowStr = DateTime.now().toIso8601String();

          final payload = {
            'license_key': sanitizedKey,
            'license_activation_date': nowStr,
            'license_expiry_date': info.expiryDate?.toIso8601String() ?? '',
            'license_type': info.edition,
            'license_licensed_to': info.licensedTo,
          };

          for (final entry in payload.entries) {
            batch.insert(
              'settings',
              {'key': entry.key, 'value': entry.value, 'updated_at': nowStr},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          await batch.commit(noResult: true);
          return Success(info);
        } catch (e) {
          return Failure(DatabaseFailure(message: 'Failed to save activation settings: $e'));
        }
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<bool>> validateLicense() async {
    final result = await getLicenseInfo();
    return result.fold(
      onSuccess: (info) => Success(info.isValid),
      onFailure: (_) => const Success(false),
    );
  }

  /// Wipes all license data and registered administrators from SQLite settings & users tables.
  Future<Result<void>> deactivateLicense() async {
    try {
      final db = await _db;
      final batch = db.batch();

      // Wipe licensing records
      batch.delete('settings', where: "key LIKE 'license_%'");
      batch.delete('settings', where: "key = 'pharmacy_name'");

      // Wipe master users so fresh onboarding is triggered
      batch.delete('users');

      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Deactivation failed: $e'));
    }
  }

  Future<Result<LicenseInfo>> _evaluateKey(String key, String? originalActivationDate) async {
    final now = DateTime.now();
    final activation = originalActivationDate != null
        ? DateTime.parse(originalActivationDate)
        : now;

    DateTime? expiry;
    LicenseStatus status;
    String licensedTo;
    String edition;
    int daysRemaining = 0;

    if (key == 'TEST-LIFETIME-KEY') {
      expiry = null;
      status = LicenseStatus.active;
      licensedTo = 'Demo Pharmacy (Lifetime)';
      edition = 'Enterprise Lifetime';
      daysRemaining = 99999;
    } else if (key == 'TEST-ACTIVE-YEARLY') {
      expiry = activation.add(const Duration(days: 365));
      status = now.isBefore(expiry) ? LicenseStatus.active : LicenseStatus.expired;
      licensedTo = 'Demo Pharmacy (1 Year)';
      edition = 'Professional Annual';
      daysRemaining = expiry.difference(now).inDays;
    } else if (key == 'TEST-2DAYS-TRIAL') {
      expiry = activation.add(const Duration(days: 2));
      status = now.isBefore(expiry) ? LicenseStatus.trial : LicenseStatus.expired;
      licensedTo = 'Evaluation Store';
      edition = 'Evaluation License';
      daysRemaining = expiry.difference(now).inDays;
    } else if (key == 'TEST-EXPIRED-DEMO') {
      final backdatedActivation = now.subtract(const Duration(days: 10));
      expiry = backdatedActivation.add(const Duration(days: 5));
      status = LicenseStatus.expired;
      licensedTo = 'Expired Demonstration Sandbox';
      edition = 'Evaluation License (Expired)';
      daysRemaining = expiry.difference(now).inDays;
    } else {
      return const Success(LicenseInfo(
        productId: 'PHARMASUITE-ERP',
        edition: 'Unknown',
        status: LicenseStatus.invalid,
      ));
    }

    return Success(LicenseInfo(
      productId: 'PHARMASUITE-ERP',
      edition: edition,
      status: status,
      licenseKey: key,
      activationDate: activation,
      expiryDate: expiry,
      licensedTo: licensedTo,
      maxUsers: key == 'TEST-LIFETIME-KEY' ? 99 : 5,
      maxCounters: key == 'TEST-LIFETIME-KEY' ? 10 : 2,
      daysRemaining: daysRemaining,
      enabledModules: const [
        'Dashboard', 'Medicines', 'Inventory', 'Sales',
        'Purchases', 'Customers', 'Suppliers', 'Accounts',
        'Reports', 'Users', 'Settings', 'Licensing',
      ],
    ));
  }
}