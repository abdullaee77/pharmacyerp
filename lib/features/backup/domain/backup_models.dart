import '../../../core/domain/value_object.dart';

enum ServerStatus {
  local(label: 'Local Only'),
  connected(label: 'Connected'),
  disconnected(label: 'Disconnected'),
  notConfigured(label: 'Not Configured');

  final String label;
  const ServerStatus({required this.label});
}

class BackupInfo extends ValueObject {
  final String? lastBackupPath;
  final DateTime? lastBackupAt;
  final String? lastBackupSize;
  final bool autoBackupEnabled;
  final String backupLocation;
  final String databaseSize;
  final String databasePath;

  const BackupInfo({
    this.lastBackupPath,
    this.lastBackupAt,
    this.lastBackupSize,
    this.autoBackupEnabled = false,
    this.backupLocation = '',
    this.databaseSize = 'Unknown',
    this.databasePath = '',
  });
}

class NetworkNode {
  final String name;
  final String type;
  final String status;
  final String? lastConnected;
  final String? ipAddress;

  const NetworkNode({
    required this.name,
    required this.type,
    required this.status,
    this.lastConnected,
    this.ipAddress,
  });
}
