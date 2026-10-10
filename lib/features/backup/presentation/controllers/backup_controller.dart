import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/data/database_helper.dart';
import '../../domain/backup_models.dart';

class BackupController extends ChangeNotifier {
  BackupInfo _info = const BackupInfo();
  List<BackupEntry> _backups = [];
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _message;
  bool _messageIsError = false;

  VoidCallback? onDataRestored;

  BackupInfo get info => _info;
  List<BackupEntry> get backups => _backups;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  String? get message => _message;
  bool get messageIsError => _messageIsError;

  final List<NetworkNode> _nodes = [
    const NetworkNode(
      name: 'Main Terminal (POS-01)',
      type: 'Local',
      status: 'Online',
      ipAddress: '127.0.0.1',
    ),
  ];

  List<NetworkNode> get nodes => _nodes;

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> loadInfo() async {
    try {
      final dbPath = await DatabaseHelper.instance.databaseFilePath;
      final dbFile = File(dbPath);
      final dbSize = await dbFile.exists() ? (await dbFile.stat()).size : 0;
      final backupDir = await DatabaseHelper.backupDirectoryPath;

      await loadBackups();

      _info = BackupInfo(
        databasePath: dbPath,
        databaseSize: _formatSize(dbSize),
        autoBackupEnabled: true,
        backupLocation: backupDir,
        lastBackupAt: _backups.isNotEmpty ? _backups.first.createdAt : null,
      );
      notifyListeners();
    } catch (e) {
      _message = 'Failed to load info: $e';
      _messageIsError = true;
      notifyListeners();
    }
  }

  Future<void> loadBackups() async {
    try {
      final backupDirPath = await DatabaseHelper.backupDirectoryPath;
      final dir = Directory(backupDirPath);
      if (!await dir.exists()) {
        _backups = [];
        return;
      }

      final files = await dir
          .list()
          .where((e) => e is File && e.path.toLowerCase().endsWith('.db'))
          .cast<File>()
          .toList();

      final regex = RegExp(r'(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})');
      final entries = <BackupEntry>[];

      for (final f in files) {
        final stat = await f.stat();
        final name = p.basename(f.path);
        DateTime date = stat.modified;

        final match = regex.firstMatch(name);
        if (match != null) {
          final y = int.parse(match.group(1)!);
          final m = int.parse(match.group(2)!);
          final d = int.parse(match.group(3)!);
          final hr = int.parse(match.group(4)!);
          final min = int.parse(match.group(5)!);
          final sec = int.parse(match.group(6)!);
          date = DateTime(y, m, d, hr, min, sec);
        }

        entries.add(BackupEntry(
          fileName: name,
          filePath: f.path,
          createdAt: date,
          sizeBytes: stat.size,
        ));
      }

      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _backups = entries;
    } catch (e) {
      debugPrint('loadBackups error: $e');
    }
  }

  Future<bool> performBackup() async {
    _isBackingUp = true;
    _message = null;
    notifyListeners();

    try {
      final savedPath = await DatabaseHelper.createBackup();
      if (savedPath == null) {
        _message = 'Failed to create backup. Check permissions.';
        _messageIsError = true;
        _isBackingUp = false;
        notifyListeners();
        return false;
      }

      final fileName = p.basename(savedPath);
      _message = 'Backup created: $fileName';
      _messageIsError = false;

      await loadInfo();
      _isBackingUp = false;
      notifyListeners();
      return true;
    } catch (e) {
      _message = 'Backup error: $e';
      _messageIsError = true;
      _isBackingUp = false;
      notifyListeners();
      return false;
    }
  }

  /// Restores from backup path with auto-fixing for missing .db or quotes
  Future<bool> performRestore(String inputPath) async {
    _isRestoring = true;
    _message = null;
    notifyListeners();

    try {
      // 1. Sanitize user input (remove quotes, whitespace)
      var cleanPath = inputPath.trim().replaceAll('"', '').replaceAll("'", "");

      var backupFile = File(cleanPath);

      // Auto-detect missing .db extension
      if (!await backupFile.exists()) {
        if (await File('$cleanPath.db').exists()) {
          cleanPath = '$cleanPath.db';
          backupFile = File(cleanPath);
        } else {
          _message = 'File not found at: $cleanPath';
          _messageIsError = true;
          _isRestoring = false;
          notifyListeners();
          return false;
        }
      }

      final dbPath = await DatabaseHelper.instance.databaseFilePath;

      // 2. Close active SQLite connection
      await DatabaseHelper.instance.close();
      await Future.delayed(const Duration(milliseconds: 150)); // Allow Windows file handles to release

      // 3. Clear existing DB and journal files
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }

      // 4. Copy restored backup into active DB path
      await backupFile.copy(dbPath);

      // 5. Reopen connection
      await DatabaseHelper.instance.closeAndReopen();

      // 6. Notify app controllers to refresh all screens
      onDataRestored?.call();

      final fileName = p.basename(cleanPath);
      _message = 'Restored successfully from $fileName';
      _messageIsError = false;
      _isRestoring = false;

      await loadInfo();
      notifyListeners();
      return true;
    } catch (e) {
      _message = 'Restore error: $e';
      _messageIsError = true;
      _isRestoring = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteBackup(BackupEntry entry) async {
    try {
      final f = File(entry.filePath);
      if (await f.exists()) await f.delete();
      _message = 'Deleted ${entry.fileName}.';
      _messageIsError = false;
      await loadInfo();
      notifyListeners();
    } catch (e) {
      _message = 'Delete failed: $e';
      _messageIsError = true;
      notifyListeners();
    }
  }
}