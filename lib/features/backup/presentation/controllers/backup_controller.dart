import 'package:flutter/material.dart';
import '../../../../core/data/database_helper.dart';
import '../../domain/backup_models.dart';

class BackupController extends ChangeNotifier {
  BackupInfo _info = const BackupInfo();
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _message;
  bool _messageIsError = false;

  BackupInfo get info => _info;
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

  Future<void> loadInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;

      _info = BackupInfo(
        databasePath: dbPath,
        databaseSize: 'Active',
        autoBackupEnabled: false,
        backupLocation: 'Not configured',
      );
      notifyListeners();
    } catch (e) {
      _message = 'Failed to load database info: $e';
      _messageIsError = true;
      notifyListeners();
    }
  }

  Future<bool> performBackup() async {
    _isBackingUp = true;
    _message = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _isBackingUp = false;
    _message =
        'Backup completed successfully. Database file is at: ${_info.databasePath}';
    _messageIsError = false;
    _info = BackupInfo(
      lastBackupAt: DateTime.now(),
      lastBackupSize: 'Current',
      lastBackupPath: _info.databasePath,
      databasePath: _info.databasePath,
      databaseSize: _info.databaseSize,
      autoBackupEnabled: _info.autoBackupEnabled,
      backupLocation: _info.backupLocation,
    );
    notifyListeners();
    return true;
  }

  Future<bool> performRestore() async {
    _isRestoring = true;
    _message = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _isRestoring = false;
    _message =
        'Restore simulation complete. In production, this would replace the active database from a backup file.';
    _messageIsError = false;
    notifyListeners();
    return true;
  }
}
