import 'dart:async';

/// Represents a client PC connected to this server.
class ConnectedClient {
  final String clientId;
  String pcName; // Removed 'final' to allow updates during heartbeat
  final String ipAddress;
  final DateTime connectedAt;
  DateTime lastHeartbeat;

  ConnectedClient({
    required this.clientId,
    required this.pcName,
    required this.ipAddress,
    required this.connectedAt,
    required this.lastHeartbeat,
  });

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'pcName': pcName,
    'ipAddress': ipAddress,
    'connectedAt': connectedAt.toIso8601String(),
    'lastHeartbeat': lastHeartbeat.toIso8601String(),
  };
}

class ConnectionTracker {
  final Map<String, ConnectedClient> _clients = {};
  Timer? _cleanupTimer;

  /// Start periodic cleanup of stale connections.
  void startCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => removeStale(),
    );
  }

  void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Register or refresh a client heartbeat.
  void heartbeat(String clientId, String pcName, String ipAddress) {
    final now = DateTime.now();
    if (_clients.containsKey(clientId)) {
      _clients[clientId]!.lastHeartbeat = now;
      _clients[clientId]!.pcName = pcName; // No longer errors
    } else {
      _clients[clientId] = ConnectedClient(
        clientId: clientId,
        pcName: pcName,
        ipAddress: ipAddress,
        connectedAt: now,
        lastHeartbeat: now,
      );
    }
  }

  /// Remove clients with no heartbeat for over 2 minutes.
  void removeStale() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    _clients.removeWhere((_, c) => c.lastHeartbeat.isBefore(cutoff));
  }

  /// Remove a specific client.
  void disconnect(String clientId) {
    _clients.remove(clientId);
  }

  List<ConnectedClient> get activeClients => _clients.values.toList();
  int get activeCount => _clients.length;

  void dispose() {
    stopCleanup();
    _clients.clear();
  }
}