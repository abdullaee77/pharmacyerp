import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'network_config.dart';

/// Keeps a long-poll request open to the server's /api/version.
///
/// The server holds the request until the data version changes, so a change
/// made on any PC reaches this PC within milliseconds (no 2-second polling).
/// When the version changes, [notifyListeners] fires and ShellScreen reloads.
///
/// If the server is an older build that answers immediately, the loop slows
/// down to [start]'s `interval`, so it never hammers the network.
class DataSyncService extends ChangeNotifier {
  DataSyncService._();
  static final DataSyncService instance = DataSyncService._();

  static const int _waitSeconds = 25;

  final http.Client _http = http.Client();
  int _lastVersion = 0;
  bool _running = false;
  int _generation = 0;
  Duration _retryDelay = const Duration(seconds: 2);

  int get lastVersion => _lastVersion;
  bool get isRunning => _running;

  /// [interval] is only the delay between retries after an error.
  void start({Duration interval = const Duration(seconds: 2)}) {
    if (_running) return;
    _running = true;
    _retryDelay = interval;
    _loop(++_generation);
  }

  void stop() {
    _running = false;
    _generation++;
  }

  Future<void> _loop(int generation) async {
    bool active() => _running && generation == _generation;

    while (active()) {
      final config = NetworkConfig.instance;
      if (!config.isClient || config.serverIp.trim().isEmpty) {
        await Future.delayed(_retryDelay);
        continue;
      }

      final startedAt = DateTime.now();
      try {
        final uri = Uri.parse(
          '${config.baseUrl}/api/version?since=$_lastVersion&wait=$_waitSeconds',
        );
        final res = await _http
            .get(uri)
            .timeout(const Duration(seconds: _waitSeconds + 10));
        if (!active()) break;

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final version = (body['version'] as num?)?.toInt() ?? 0;

          var changed = false;
          if (version != _lastVersion) {
            final isFirst = _lastVersion == 0;
            _lastVersion = version;
            changed = !isFirst;
          }
          if (changed) notifyListeners();

          // Reply came back instantly with no change => the server does not
          // support long-poll. Fall back to a gentle poll.
          final elapsed = DateTime.now().difference(startedAt);
          if (!changed && elapsed < const Duration(milliseconds: 500)) {
            await Future.delayed(_retryDelay);
          }
        } else {
          await Future.delayed(_retryDelay);
        }
      } catch (_) {
        // Server offline or request timed out: wait, then try again.
        if (!active()) break;
        await Future.delayed(_retryDelay);
      }
    }
  }

  /// Force a UI refresh on this PC (e.g. after a local write).
  void bumpLocal() {
    _lastVersion++;
    notifyListeners();
  }

  void disposeService() {
    stop();
    _http.close();
  }
}