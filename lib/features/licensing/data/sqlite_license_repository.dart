// // lib/features/licensing/data/sqlite_license_repository.dart
//
// import 'dart:convert';
// import 'package:sqflite/sqflite.dart';
// import '../../../core/data/database_helper.dart';
// import '../../../core/error/failures.dart';
// import '../../../core/result/result.dart';
// import '../domain/device_fingerprint.dart';
// import '../domain/license.dart';
// import '../domain/license_payload.dart';
// import '../domain/license_repository.dart';
// import '../domain/license_validator.dart';
//
// class SqliteLicenseRepository implements LicenseRepository {
//   final DatabaseHelper _dbHelper;
//   final LicenseValidatorImpl _validator;
//
//   SqliteLicenseRepository({
//     DatabaseHelper? dbHelper,
//     LicenseValidatorImpl? validator,
//   })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
//         _validator = validator ?? LicenseValidatorImpl();
//
//   Future<Database> get _db => _dbHelper.database;
//
//   @override
//   String getMachineId() => DeviceFingerprint.generate();
//
//   @override
//   Future<Result<LicenseInfo>> getLicenseInfo() async {
//     try {
//       final db = await _db;
//       final rows = await db.query(
//         'licenses',
//         orderBy: 'id DESC',
//         limit: 1,
//       );
//
//       if (rows.isEmpty) {
//         return Success(LicenseInfo(
//           productId: LicenseValidatorImpl.appProductId,
//           edition: 'Unlicensed',
//           status: LicenseStatus.activationRequired,
//           machineId: getMachineId(),
//         ));
//       }
//
//       final row = rows.first;
//       final rawPayload = row['raw_payload'] as String;
//
//       final validation = await _validator.validate(rawPayload);
//       return validation.fold(
//         onSuccess: (payload) {
//           final now = DateTime.now();
//           DateTime? expiry;
//           int daysRemaining = 99999;
//           LicenseStatus status = LicenseStatus.active;
//
//           if (payload.licenseType == 'time_limited' && payload.expiresAt != null) {
//             expiry = DateTime.tryParse(payload.expiresAt!);
//             if (expiry != null) {
//               daysRemaining = expiry.difference(now).inDays;
//               if (now.isAfter(expiry)) {
//                 status = LicenseStatus.expired;
//               } else if (daysRemaining <= 14) {
//                 status = LicenseStatus.expiringSoon;
//               }
//             }
//           }
//
//           return Success(LicenseInfo(
//             productId: payload.productId,
//             edition: payload.licenseType == 'lifetime' ? 'Lifetime Enterprise' : 'Time-Limited Subscription',
//             status: status,
//             licenseKey: payload.licenseId,
//             activationDate: DateTime.tryParse(row['activation_date'] as String),
//             expiryDate: expiry,
//             customerName: payload.customerName,
//             businessName: payload.businessName,
//             machineId: payload.machineId,
//             licenseType: payload.licenseType,
//             daysRemaining: daysRemaining,
//             payload: payload,
//           ));
//         },
//         onFailure: (f) {
//           return Success(LicenseInfo(
//             productId: LicenseValidatorImpl.appProductId,
//             edition: 'Invalid License',
//             status: LicenseStatus.invalid,
//             machineId: getMachineId(),
//           ));
//         },
//       );
//     } catch (e) {
//       return Failure(DatabaseFailure(message: 'Failed to read license from database: $e'));
//     }
//   }
//
//   @override
//   Future<Result<LicenseInfo>> activateLicense(String rawPayloadJson) async {
//     final validation = await _validator.validate(rawPayloadJson);
//
//     return validation.fold(
//       onSuccess: (payload) async {
//         try {
//           final db = await _db;
//           final batch = db.batch();
//
//           // Deactivate all previous stored licenses
//           batch.update('licenses', {'is_valid': 0});
//
//           final nowStr = DateTime.now().toIso8601String();
//
//           batch.insert(
//             'licenses',
//             {
//               'license_id': payload.licenseId,
//               'raw_payload': rawPayloadJson.trim(),
//               'customer_name': payload.customerName,
//               'business_name': payload.businessName,
//               'device_id': payload.machineId,
//               'license_type': payload.licenseType,
//               'activation_date': nowStr,
//               'expiry_date': payload.expiresAt,
//               'is_valid': 1,
//               'created_at': nowStr,
//             },
//             conflictAlgorithm: ConflictAlgorithm.replace,
//           );
//
//           // Update pharmacy name setting
//           batch.insert(
//             'settings',
//             {'key': 'pharmacy_name', 'value': payload.businessName, 'updated_at': nowStr},
//             conflictAlgorithm: ConflictAlgorithm.replace,
//           );
//
//           await batch.commit(noResult: true);
//           return getLicenseInfo();
//         } catch (e) {
//           return Failure(DatabaseFailure(message: 'Failed to persist license: $e'));
//         }
//       },
//       onFailure: (f) => Failure(f),
//     );
//   }
//
//   @override
//   Future<Result<bool>> validateLicense() async {
//     final info = await getLicenseInfo();
//     return info.fold(
//       onSuccess: (lic) => Success(lic.isValid),
//       onFailure: (_) => const Success(false),
//     );
//   }
//
//   @override
//   Future<Result<void>> deactivateLicense() async {
//     try {
//       final db = await _db;
//       final batch = db.batch();
//       batch.delete('licenses');
//       batch.delete('settings', where: "key LIKE 'license_%'");
//       batch.delete('settings', where: "key = 'pharmacy_name'");
//       batch.delete('users');
//       await batch.commit(noResult: true);
//       return const Success(null);
//     } catch (e) {
//       return Failure(DatabaseFailure(message: 'Deactivation failed: $e'));
//     }
//   }
// }
// lib/features/licensing/data/sqlite_license_repository.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/device_fingerprint.dart';
import '../domain/license.dart';
import '../domain/license_repository.dart';
import '../domain/license_validator.dart';

class SqliteLicenseRepository implements LicenseRepository {
  final DatabaseHelper _dbHelper;
  final LicenseValidatorImpl _validator;

  SqliteLicenseRepository({
    DatabaseHelper? dbHelper,
    LicenseValidatorImpl? validator,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _validator = validator ?? LicenseValidatorImpl();

  Future<Database> get _db => _dbHelper.database;

  @override
  String getMachineId() => DeviceFingerprint.generate();

  @override
  Future<Result<LicenseInfo>> getLicenseInfo() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'licenses',
        orderBy: 'id DESC',
        limit: 1,
      );

      if (rows.isEmpty) {
        return Success(LicenseInfo(
          productId: LicenseValidatorImpl.appProductId,
          edition: 'Unlicensed',
          status: LicenseStatus.activationRequired,
          machineId: getMachineId(),
        ));
      }

      final row = rows.first;
      final rawPayload = row['raw_payload'] as String;

      final validation = await _validator.validate(rawPayload);
      return validation.fold(
        onSuccess: (payload) {
          final now = DateTime.now();
          DateTime? expiry;
          int daysRemaining = 99999;
          LicenseStatus status = LicenseStatus.active;

          if (payload.licenseType == 'time_limited' && payload.expiresAt != null) {
            expiry = DateTime.tryParse(payload.expiresAt!);
            if (expiry != null) {
              daysRemaining = expiry.difference(now).inDays;
              if (now.isAfter(expiry)) {
                status = LicenseStatus.expired;
              } else if (daysRemaining <= 14) {
                status = LicenseStatus.expiringSoon;
              }
            }
          }

          return Success(LicenseInfo(
            productId: payload.productId,
            edition: payload.licenseType == 'lifetime' ? 'Lifetime Enterprise' : 'Time-Limited Subscription',
            status: status,
            licenseKey: payload.licenseId,
            activationDate: DateTime.tryParse(row['activation_date'] as String),
            expiryDate: expiry,
            customerName: payload.customerName,
            businessName: payload.businessName,
            machineId: payload.machineId,
            licenseType: payload.licenseType,
            daysRemaining: daysRemaining,
            payload: payload,
          ));
        },
        onFailure: (f) {
          debugPrint('License re-validation failed on load: ${f.message}');
          final expired = f.message.toLowerCase().contains('expired');
          return Success(LicenseInfo(
            productId: LicenseValidatorImpl.appProductId,
            edition: expired ? 'Expired License' : 'Invalid License',
            status: expired ? LicenseStatus.expired : LicenseStatus.invalid,
            statusMessage: f.message,
            machineId: getMachineId(),
          ));
        },
      );
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read license from database: $e'));
    }
  }

  @override
  Future<Result<LicenseInfo>> activateLicense(String rawPayloadJson) async {
    final validation = await _validator.validate(rawPayloadJson);

    return validation.fold(
      onSuccess: (payload) async {
        try {
          final db = await _db;
          final batch = db.batch();

          // Deactivate all previous stored licenses
          batch.update('licenses', {'is_valid': 0});

          final nowStr = DateTime.now().toIso8601String();

          batch.insert(
            'licenses',
            {
              'license_id': payload.licenseId,
              'raw_payload': rawPayloadJson.trim(),
              'customer_name': payload.customerName,
              'business_name': payload.businessName,
              'device_id': payload.machineId,
              'license_type': payload.licenseType,
              'activation_date': nowStr,
              'expiry_date': payload.expiresAt,
              'is_valid': 1,
              'created_at': nowStr,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Update pharmacy name setting
          batch.insert(
            'settings',
            {'key': 'pharmacy_name', 'value': payload.businessName, 'updated_at': nowStr},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          await batch.commit(noResult: true);
          return getLicenseInfo();
        } catch (e) {
          return Failure(DatabaseFailure(message: 'Failed to persist license: $e'));
        }
      },
      onFailure: (f) => Failure(f),
    );
  }

  @override
  Future<Result<bool>> validateLicense() async {
    final info = await getLicenseInfo();
    return info.fold(
      onSuccess: (lic) => Success(lic.isValid),
      onFailure: (_) => const Success(false),
    );
  }

  @override
  Future<Result<void>> deactivateLicense() async {
    try {
      final db = await _db;
      final batch = db.batch();
      batch.delete('licenses');
      batch.delete('settings', where: "key LIKE 'license_%'");
      batch.delete('settings', where: "key = 'pharmacy_name'");
      // NOTE: the original also ran batch.delete('users') here, which wipes
      // every user account. Removed on purpose.
      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Deactivation failed: $e'));
    }
  }
}