import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/data/database_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_server.dart';
import '../../../../core/network/connection_tracker.dart';
import '../../../../core/network/network_config.dart';
import '../../../settings/domain/settings_repository.dart';

class NetworkController extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  ApiServer? _server; // Changed from 'late final' to nullable so it can be safely created & stopped
  final ConnectionTracker _tracker = ConnectionTracker();

  bool _isServerRunning = false;
  bool _isTesting = false;
  bool _isConnected = false;
  String _statusMessage = '';
  String _localIp = '';
  List<Map<String, dynamic>> _connectedClients = [];
  Timer? _refreshTimer;

  NetworkController({required SettingsRepository settingsRepo})
      : _settingsRepo = settingsRepo;

  bool get isServerRunning => _isServerRunning;
  bool get isTesting => _isTesting;
  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;
  String get localIp => _localIp;
  List<Map<String, dynamic>> get connectedClients => _connectedClients;
  NetworkConfig get config => NetworkConfig.instance;

  Future<void> initialize() async {
    _localIp = await NetworkConfig.instance.detectLocalIp();

    final result = await _settingsRepo.getAllSettings();
    result.fold(
      onSuccess: (settings) {
        final map = {for (final s in settings) s.key: s.value};
        NetworkConfig.instance.loadFromSettings(map);
      },
      onFailure: (_) {},
    );

    if (NetworkConfig.instance.isServer && NetworkConfig.instance.autoStartServer) {
      await startServer();
    }

    if (NetworkConfig.instance.isClient) {
      ApiClient.instance.startHeartbeat();
      _startClientRefresh();
    }

    notifyListeners();
  }

  Future<void> startServer() async {
    try {
      _statusMessage = 'Starting server...';
      notifyListeners();

      // Stop existing server instance if any
      if (_server != null && _server!.isRunning) {
        await _server!.stop();
      }

      _server = ApiServer(
        dbHelper: DatabaseHelper.instance,
        tracker: _tracker,
        port: NetworkConfig.instance.port,
      );

      await _server!.start();
      _isServerRunning = true;
      _statusMessage = 'Server running on $_localIp:${NetworkConfig.instance.port}';
      _startServerRefresh();
    } catch (e) {
      _isServerRunning = false;
      _statusMessage = 'Failed to start server: $e';
    }
    notifyListeners();
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    _isServerRunning = false;
    _refreshTimer?.cancel();
    _connectedClients = [];
    _statusMessage = 'Server stopped.';
    notifyListeners();
  }

  Future<void> testClientConnection() async {
    _isTesting = true;
    _statusMessage = 'Testing connection...';
    notifyListeners();

    final ip = NetworkConfig.instance.serverIp;
    final port = NetworkConfig.instance.port;
    _isConnected = await ApiClient.instance.testConnection(ip, port);
    _statusMessage = _isConnected
        ? 'Connected to server at $ip:$port'
        : 'Cannot reach server at $ip:$port';

    _isTesting = false;
    notifyListeners();
  }

  Future<void> saveConfig({
    AppMode? mode,
    String? serverIp,
    int? port,
    String? pcName,
    bool? autoStart,
  }) async {
    NetworkConfig.instance.update(
      mode: mode,
      serverIp: serverIp,
      port: port,
      pcName: pcName,
      autoStartServer: autoStart,
    );
    final map = NetworkConfig.instance.toSettingsMap();
    await _settingsRepo.saveSettings(map);
    _statusMessage = 'Network settings saved.';
    notifyListeners();
  }

  void _startServerRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _connectedClients = (_server != null && _server!.isRunning)
          ? _tracker.activeClients.map((c) => c.toJson()).toList()
          : [];
      notifyListeners();
    });
  }

  void _startClientRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await testClientConnection();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tracker.dispose();
    super.dispose();
  }
}