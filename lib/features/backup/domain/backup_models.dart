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

/// Represents a single backup file on disk.
class BackupEntry {
  final String fileName;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupEntry({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get dateFormatted {
    final d = createdAt;
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hourNum = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final hour = hourNum.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final sec = d.second.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$day/$mon/$year  $hour:$min:$sec $ampm';
  }
}