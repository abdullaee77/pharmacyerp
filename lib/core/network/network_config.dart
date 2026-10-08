import 'dart:io';
import 'package:flutter/foundation.dart';

enum AppMode {
  standalone('Standalone (Single PC)'),
  server('Server (Main PC)'),
  client('Client (Connected PC)');

  final String label;
  const AppMode(this.label);
}

class NetworkConfig extends ChangeNotifier {
  NetworkConfig._();
  static final NetworkConfig instance = NetworkConfig._();

  AppMode _mode = AppMode.standalone;
  String _serverIp = '';
  int _port = 8080;
  String _pcName = '';
  bool _autoStartServer = false;

  AppMode get mode => _mode;
  String get serverIp => _serverIp;
  int get port => _port;
  String get pcName => _pcName;
  bool get autoStartServer => _autoStartServer;

  bool get isStandalone => _mode == AppMode.standalone;
  bool get isServer => _mode == AppMode.server;
  bool get isClient => _mode == AppMode.client;

  String get baseUrl => 'http://$_serverIp:$_port';

  Future<String> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void loadFromSettings(Map<String, String> settings) {
    final modeStr = settings['network_mode'] ?? 'standalone';
    _mode = AppMode.values.firstWhere(
          (e) => e.name == modeStr,
      orElse: () => AppMode.standalone,
    );
    _serverIp = settings['network_server_ip'] ?? '';
    _port = int.tryParse(settings['network_port'] ?? '8080') ?? 8080;
    _pcName = settings['network_pc_name'] ?? '';
    _autoStartServer = settings['network_auto_start'] == 'true';
    notifyListeners();
  }

  Map<String, String> toSettingsMap() {
    return {
      'network_mode': _mode.name,
      'network_server_ip': _serverIp,
      'network_port': _port.toString(),
      'network_pc_name': _pcName,
      'network_auto_start': _autoStartServer.toString(),
    };
  }

  void update({
    AppMode? mode,
    String? serverIp,
    int? port,
    String? pcName,
    bool? autoStartServer,
  }) {
    if (mode != null) _mode = mode;
    if (serverIp != null) _serverIp = serverIp;
    if (port != null) _port = port;
    if (pcName != null) _pcName = pcName;
    if (autoStartServer != null) _autoStartServer = autoStartServer;
    notifyListeners();
  }
}