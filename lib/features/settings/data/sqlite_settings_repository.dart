import 'package:sqflite/sqflite.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/error/failures.dart';
import '../../../core/result/result.dart';
import '../domain/setting.dart';
import '../domain/settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  final DatabaseHelper _dbHelper;

  SqliteSettingsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<Result<List<Setting>>> getAllSettings() async {
    try {
      final db = await _db;
      final rows = await db.query('settings', orderBy: 'key ASC');
      final settings = rows.map((r) {
        final key = r['key'] as String;
        final cat = _categoryForKey(key);
        return Setting(
          key: key,
          value: r['value'] as String? ?? '',
          category: cat,
          label: _labelForKey(key),
        );
      }).toList();
      return Success(settings);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to load settings: $e'));
    }
  }

  @override
  Future<Result<String>> getSetting(String key) async {
    try {
      final db = await _db;
      final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
      if (rows.isEmpty) return const Success('');
      return Success(rows.first['value'] as String? ?? '');
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read setting: $e'));
    }
  }

  @override
  Future<Result<void>> saveSetting(String key, String value) async {
    try {
      final db = await _db;
      await db.insert(
        'settings',
        {'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save setting: $e'));
    }
  }

  @override
  Future<Result<void>> saveSettings(Map<String, String> settings) async {
    try {
      final db = await _db;
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final entry in settings.entries) {
        batch.insert(
          'settings',
          {'key': entry.key, 'value': entry.value, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to save settings: $e'));
    }
  }

  SettingCategory _categoryForKey(String key) {
    if (key.startsWith('pharmacy_')) return SettingCategory.pharmacy;
    if (key.startsWith('invoice_')) return SettingCategory.invoice;
    if (key.startsWith('tax_')) return SettingCategory.tax;
    if (key.startsWith('pos_')) return SettingCategory.pos;
    if (key.startsWith('printer_')) return SettingCategory.printer;
    if (key.startsWith('network_')) return SettingCategory.network;
    if (key.startsWith('notif_')) return SettingCategory.notifications;
    if (key.startsWith('backup_')) return SettingCategory.backup;
    return SettingCategory.pharmacy;
  }

  String _labelForKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}