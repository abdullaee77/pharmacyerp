// lib/core/network/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../error/failures.dart';
import '../result/result.dart';
import 'network_config.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _noServerMessage =
      'Server IP is not set. Please go to Network & LAN settings and enter Server IP.';

  final http.Client _http = http.Client();
  Timer? _heartbeatTimer;
  String? _token;

  void Function()? onSessionExpired;

  bool get hasSession => _token != null;

  void setToken(String? token) => _token = token;

  String? _validateAndGetBaseUrl() {
    final ip = NetworkConfig.instance.serverIp.trim();
    if (ip.isEmpty) return null;
    return NetworkConfig.instance.baseUrl;
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  void _handleUnauthorized() {
    if (_token == null) return;
    _token = null;
    onSessionExpired?.call();
  }

  Future<bool> testConnection(String ip, int port) async {
    if (ip.trim().isEmpty) return false;
    try {
      final uri = Uri.parse('http://${ip.trim()}:$port/api/status');
      final res = await _http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendHeartbeat();
    });
    _sendHeartbeat();
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final baseUrl = _validateAndGetBaseUrl();
    if (baseUrl == null) return;
    try {
      final config = NetworkConfig.instance;
      await _http
          .post(
        Uri.parse('$baseUrl/api/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientId': config.pcName,
          'pcName': config.pcName,
        }),
      )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<Result<Map<String, dynamic>>> login({
    required String username,
    required String passwordHash,
  }) async {
    final baseUrl = _validateAndGetBaseUrl();
    if (baseUrl == null) {
      return const Failure(ServerFailure(message: _noServerMessage));
    }

    try {
      final res = await _http
          .post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'passwordHash': passwordHash}),
      )
          .timeout(const Duration(seconds: 8));

      final body = _decode(res.body);
      if (res.statusCode == 200 && body['token'] is String) {
        _token = body['token'] as String;
        return Success(body);
      }
      final message = body['error']?.toString();
      if (res.statusCode == 401 || res.statusCode == 403 || res.statusCode == 429) {
        return Failure(
          AuthenticationFailure(message: message ?? 'Invalid username or password.'),
        );
      }
      return Failure(
        ServerFailure(message: message ?? 'Login failed (${res.statusCode}).'),
      );
    } on TimeoutException {
      return const Failure(ServerFailure(message: 'Server connection timed out.'));
    } catch (e) {
      return Failure(ServerFailure(message: 'Network error: $e'));
    }
  }

  Future<void> logout() async {
    final token = _token;
    _token = null;
    final baseUrl = _validateAndGetBaseUrl();
    if (token == null || baseUrl == null) return;
    try {
      await _http
          .post(
        Uri.parse('$baseUrl/api/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<Result<Map<String, dynamic>>> _post(
      String path,
      Map<String, dynamic> body, {
        Duration timeout = const Duration(seconds: 10),
      }) async {
    final baseUrl = _validateAndGetBaseUrl();
    if (baseUrl == null) {
      return const Failure(ServerFailure(message: _noServerMessage));
    }

    try {
      final res = await _http
          .post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      )
          .timeout(timeout);

      if (res.statusCode == 401) {
        _handleUnauthorized();
        return const Failure(
          AuthenticationFailure(
            message: 'Your session has expired. Please log in again.',
          ),
        );
      }

      final decoded = _decode(res.body);
      if (res.statusCode != 200) {
        return Failure(
          ServerFailure(
            message: decoded['error']?.toString() ??
                'Request failed (${res.statusCode}).',
          ),
        );
      }
      return Success(decoded);
    } on TimeoutException {
      return const Failure(ServerFailure(message: 'Server connection timed out.'));
    } catch (e) {
      return Failure(ServerFailure(message: 'Network error: $e'));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> query({
    required String table,
    String? where,
    List<dynamic>? args,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final res = await _post('/api/query', {
      'table': table,
      'where': where,
      'args': args,
      'orderBy': orderBy,
      'limit': limit,
      'offset': offset,
    });
    return res.fold(
      onSuccess: (body) =>
          Success((body['rows'] as List).cast<Map<String, dynamic>>()),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<int>> insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final res = await _post('/api/insert', {'table': table, 'data': data});
    return res.fold(
      onSuccess: (body) => Success(body['insertedId'] as int? ?? 0),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<int>> update({
    required String table,
    required Map<String, dynamic> data,
    String? where,
    List<dynamic>? args,
  }) async {
    final res = await _post('/api/update', {
      'table': table,
      'data': data,
      'where': where,
      'args': args,
    });
    return res.fold(
      onSuccess: (body) => Success(body['updatedCount'] as int? ?? 0),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<int>> delete({
    required String table,
    String? where,
    List<dynamic>? args,
  }) async {
    final res = await _post('/api/delete', {
      'table': table,
      'where': where,
      'args': args,
    });
    return res.fold(
      onSuccess: (body) => Success(body['deletedCount'] as int? ?? 0),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<List<Map<String, dynamic>>>> rawQuery({
    required String sql,
    List<dynamic>? args,
  }) async {
    final res = await _post(
      '/api/raw-query',
      {'sql': sql, 'args': args},
      timeout: const Duration(seconds: 15),
    );
    return res.fold(
      onSuccess: (body) =>
          Success((body['rows'] as List).cast<Map<String, dynamic>>()),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<int>> batch(List<Map<String, dynamic>> operations) async {
    final res = await _post(
      '/api/batch',
      {'operations': operations},
      timeout: const Duration(seconds: 20),
    );
    return res.fold(
      onSuccess: (body) => Success(body['count'] as int? ?? operations.length),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> completeSale(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/sales/complete',
      payload,
      timeout: const Duration(seconds: 20),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  // ── ATOMIC NETWORK API WRAPPERS ──

  Future<Result<void>> completePurchase(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/purchases/complete',
      payload,
      timeout: const Duration(seconds: 20),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> completeSalesReturn(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/returns/sales/complete',
      payload,
      timeout: const Duration(seconds: 20),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> completePurchaseReturn(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/returns/purchases/complete',
      payload,
      timeout: const Duration(seconds: 20),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> adjustStock(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/inventory/adjust',
      payload,
      timeout: const Duration(seconds: 15),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> recordCustomerPayment(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/payments/customer',
      payload,
      timeout: const Duration(seconds: 15),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> recordSupplierPayment(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/payments/supplier',
      payload,
      timeout: const Duration(seconds: 15),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  Future<Result<void>> completeExpense(Map<String, dynamic> payload) async {
    final res = await _post(
      '/api/expenses/complete',
      payload,
      timeout: const Duration(seconds: 15),
    );
    return res.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (f) => Failure(f),
    );
  }

  void dispose() {
    stopHeartbeat();
    _http.close();
  }
}