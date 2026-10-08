// lib/core/network/api_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../data/database_helper.dart';
import '../data/sale_transaction.dart';
import '../data/purchase_transaction.dart';
import '../data/return_transactions.dart';
import '../data/stock_adjustment_transaction.dart';
import '../data/payment_transaction.dart';
import '../data/expense_transaction.dart';
import 'api_permissions.dart';
import 'connection_tracker.dart';

class ApiServer {
  final DatabaseHelper _dbHelper;
  final ConnectionTracker _tracker;
  HttpServer? _server;
  int _port;
  int _dataVersion = 1;

  /// Notifies the Server's local Flutter UI in real-time whenever a LAN Client writes data
  static final ValueNotifier<int> onServerDataChanged = ValueNotifier<int>(0);

  final List<Completer<void>> _versionWaiters = [];
  final Map<String, ApiSession> _sessions = {};
  final Map<String, _FailedLogins> _failedLogins = {};

  Timer? _watchTimer;
  Timer? _sessionTimer;
  bool _watching = false;
  int _lastTotalChanges = -1;

  static const Duration _sessionIdleTimeout = Duration(hours: 12);
  static const Duration _permissionRecheck = Duration(seconds: 5);
  static const int _maxFailedLogins = 5;
  static const Duration _lockoutWindow = Duration(minutes: 1);

  static final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  static final RegExp _orderBySafe = RegExp(r'^[A-Za-z0-9_.,\s]+$');

  ApiServer({
    required DatabaseHelper dbHelper,
    required ConnectionTracker tracker,
    int port = 8080,
  })  : _dbHelper = dbHelper,
        _tracker = tracker,
        _port = port;

  bool get isRunning => _server != null;
  int get port => _port;
  int get dataVersion => _dataVersion;

  void bumpVersionFromLocalWrite() => _bumpVersion();

  void _bumpVersion() {
    _dataVersion++;

    // Broadcast change to local Server UI thread instantly
    onServerDataChanged.value = _dataVersion;

    final waiters = List<Completer<void>>.from(_versionWaiters);
    _versionWaiters.clear();
    for (final w in waiters) {
      if (!w.isCompleted) w.complete();
    }
  }

  Future<int> _totalChanges() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('SELECT total_changes() AS c');
    return (rows.first['c'] as num).toInt();
  }

  Future<void> _syncBaselineSilently() async {
    try {
      _lastTotalChanges = await _totalChanges();
    } catch (_) {}
  }

  Future<void> _afterWrite() async {
    await _syncBaselineSilently();
    _bumpVersion();
  }

  void _startWatcher() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (_watching) return;
      _watching = true;
      try {
        final c = await _totalChanges();
        if (_lastTotalChanges < 0) {
          _lastTotalChanges = c;
        } else if (c != _lastTotalChanges) {
          _lastTotalChanges = c;
          _bumpVersion();
        }
      } catch (_) {
      } finally {
        _watching = false;
      }
    });
  }

  String _newToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<Set<String>> _loadPermissionKeys(dynamic db, String roleId) async {
    final rows = await db.rawQuery(
      'SELECT category, action FROM role_permissions WHERE role_id = ?',
      [roleId],
    );
    return {
      for (final r in rows) '${r['category']}.${r['action']}',
    };
  }

  Future<bool> _refreshSession(ApiSession s) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT status, role_id FROM users WHERE id = ?',
      [s.userId],
    );
    if (rows.isEmpty) return false;
    final status = rows.first['status'] as String? ?? 'active';
    if (status == 'inactive' || status == 'locked') return false;
    s.roleId = rows.first['role_id'] as String? ?? '';
    s.permissions = await _loadPermissionKeys(db, s.roleId);
    s.lastChecked = DateTime.now();
    return true;
  }

  Future<ApiSession?> _authenticate(Request req) async {
    final header = req.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) return null;
    final token = header.substring(7).trim();
    final session = _sessions[token];
    if (session == null) return null;

    final now = DateTime.now();
    if (now.difference(session.lastUsed) > _sessionIdleTimeout) {
      _sessions.remove(token);
      return null;
    }
    session.lastUsed = now;

    if (now.difference(session.lastChecked) > _permissionRecheck) {
      final ok = await _refreshSession(session);
      if (!ok) {
        _sessions.remove(token);
        return null;
      }
    }
    return session;
  }

  Future<Map<String, dynamic>> _readJson(Request req) async {
    final text = await req.readAsString();
    if (text.trim().isEmpty) return {};
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON object expected');
    }
    return decoded;
  }

  Future<Response> _guarded(
      Request req,
      Future<Response> Function(ApiSession session, Map<String, dynamic> body)
      handler,
      ) async {
    try {
      final session = await _authenticate(req);
      if (session == null) {
        return _jsonResponse(
          {'error': 'Authentication required. Please log in again.'},
          status: 401,
        );
      }
      final body = await _readJson(req);
      return await handler(session, body);
    } on FormatException catch (e) {
      return _jsonResponse({'error': 'Bad request: ${e.message}'}, status: 400);
    } on SaleException catch (e) {
      return _jsonResponse({'error': e.message}, status: 409);
    } on PurchaseException catch (e) {
      return _jsonResponse({'error': e.message}, status: 409);
    } on ReturnException catch (e) {
      return _jsonResponse({'error': e.message}, status: 409);
    } on AdjustmentException catch (e) {
      return _jsonResponse({'error': e.message}, status: 409);
    } on PaymentException catch (e) {
      return _jsonResponse({'error': e.message}, status: 409);
    } on ExpenseException catch (e) {
      return _jsonResponse({'error': e.message}, status: 409);
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 500);
    }
  }

  List<dynamic>? _args(dynamic v) => v is List ? v.cast<dynamic>() : null;

  int? _asInt(dynamic v) => v is num ? v.toInt() : null;

  Map<String, dynamic> _dataMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _sanitizeRows(List<Map<String, Object?>> rows) {
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m.remove('password_hash');
      return m;
    }).toList();
  }

  Response? _checkFragments(ApiSession s, List<String?> fragments) {
    final used = <String>{};
    for (final f in fragments) {
      if (f == null || f.trim().isEmpty) continue;
      final err = ApiAccess.scanTables(f, used);
      if (err != null) return _jsonResponse({'error': err}, status: 403);
    }
    for (final t in used) {
      if (!ApiAccess.canRead(s, t)) {
        return _jsonResponse(
          {'error': 'Permission denied: cannot read $t.'},
          status: 403,
        );
      }
    }
    return null;
  }

  Response? _checkRead(ApiSession s, String table, List<String?> fragments) {
    if (!ApiAccess.knownTable(table)) {
      return _jsonResponse({'error': 'Table not allowed'}, status: 403);
    }
    if (!ApiAccess.canRead(s, table)) {
      return _jsonResponse(
        {'error': 'Permission denied: cannot read $table.'},
        status: 403,
      );
    }
    return _checkFragments(s, fragments);
  }

  Response? _checkWrite(
      ApiSession s,
      String table,
      String op, {
        Map<String, dynamic>? data,
        String? where,
      }) {
    if (!ApiAccess.knownTable(table)) {
      return _jsonResponse({'error': 'Table not allowed'}, status: 403);
    }
    if (data != null) {
      for (final key in data.keys) {
        if (!_identifier.hasMatch(key)) {
          return _jsonResponse({'error': 'Invalid column name.'}, status: 400);
        }
      }
    }
    if (op != 'insert') {
      if (where == null || where.trim().isEmpty) {
        return _jsonResponse(
          {'error': 'A WHERE clause is required for $op.'},
          status: 400,
        );
      }
      final frag = _checkFragments(s, [where]);
      if (frag != null) return frag;
    }
    final denied = ApiAccess.checkWrite(s, table, op, data: data);
    if (denied != null) {
      return _jsonResponse({'error': denied}, status: 403);
    }
    return null;
  }

  Future<void> start() async {
    if (_server != null) return;

    final router = Router();

    router.get('/api/status', (Request req) {
      return _jsonResponse({
        'status': 'ok',
        'app': 'PharmaSuite ERP Server',
        'connections': _tracker.activeCount,
        'version': _dataVersion,
      });
    });

    router.get('/api/version', (Request req) async {
      final since = int.tryParse(req.url.queryParameters['since'] ?? '');
      final wait = int.tryParse(req.url.queryParameters['wait'] ?? '') ?? 0;
      if (since != null && since == _dataVersion && wait > 0) {
        final waiter = Completer<void>();
        _versionWaiters.add(waiter);
        await waiter.future.timeout(
          Duration(seconds: wait.clamp(1, 30).toInt()),
          onTimeout: () {},
        );
        _versionWaiters.remove(waiter);
      }
      return _jsonResponse({'version': _dataVersion});
    });

    router.post('/api/heartbeat', (Request req) async {
      try {
        final body = await _readJson(req);
        final clientId = body['clientId'] as String? ?? '';
        final pcName = body['pcName'] as String? ?? 'Unknown';
        String ip = 'unknown';
        try {
          final info =
          req.context['shelf.io.connection_info'] as HttpConnectionInfo?;
          if (info != null) ip = info.remoteAddress.address;
        } catch (_) {}
        _tracker.heartbeat(clientId, pcName, ip);
        return _jsonResponse({'status': 'ok', 'version': _dataVersion});
      } catch (e) {
        return _jsonResponse({'error': e.toString()}, status: 400);
      }
    });

    router.get('/api/connections', (Request req) {
      return _jsonResponse({
        'clients': _tracker.activeClients.map((c) => c.toJson()).toList(),
      });
    });

    // ── Login with real-time LAN terminal logging ──
    router.post('/api/login', (Request req) async {
      String remoteIp = 'unknown';
      try {
        final info =
        req.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        if (info != null) remoteIp = info.remoteAddress.address;
      } catch (_) {}

      try {
        final body = await _readJson(req);
        final username = (body['username'] as String? ?? '').trim();
        final hash = (body['passwordHash'] as String? ?? '').trim();

        print('🔑 [API Login Request] IP: $remoteIp | User: "$username"');

        if (username.isEmpty || hash.isEmpty) {
          print('⚠️ [Login Failed] Missing username or password hash.');
          return _jsonResponse(
            {'error': 'Username and password are required.'},
            status: 400,
          );
        }

        final key = username.toLowerCase();
        final failed = _failedLogins[key];
        if (failed != null) {
          if (DateTime.now().difference(failed.first) > _lockoutWindow) {
            _failedLogins.remove(key);
          } else if (failed.count >= _maxFailedLogins) {
            print('🚫 [Login Failed] Rate limited/Locked out: "$username"');
            return _jsonResponse(
              {'error': 'Too many failed attempts. Try again in a minute.'},
              status: 429,
            );
          }
        }

        final db = await _dbHelper.database;
        final rows = await db.rawQuery(
          '''
          SELECT u.id, u.username, u.full_name, u.role_id, u.status,
                 u.password_hash, r.name AS role_name
          FROM users u
          LEFT JOIN roles r ON u.role_id = r.id
          WHERE LOWER(u.username) = LOWER(?)
          LIMIT 1
          ''',
          [username],
        );

        final row = rows.isEmpty ? null : rows.first;
        if (row == null) {
          print('❌ [Login Failed] User "$username" not found in SQLite.');
        }

        final stored = row?['password_hash'] as String? ?? '';
        final valid = row != null && _constantTimeEquals(stored, hash);

        if (!valid) {
          if (row != null) {
            print('❌ [Login Failed] Password hash mismatch for user "$username"');
            print('   ├─ Stored: "$stored"');
            print('   └─ Sent:   "$hash"');
          }
          final current = _failedLogins[key];
          _failedLogins[key] = current == null
              ? _FailedLogins(1, DateTime.now())
              : _FailedLogins(current.count + 1, current.first);
          return _jsonResponse(
            {'error': 'Invalid username or password.'},
            status: 401,
          );
        }

        final status = row['status'] as String? ?? 'active';
        if (status.toLowerCase() == 'inactive') {
          print('❌ [Login Failed] Account is inactive: "$username"');
          return _jsonResponse(
            {'error': 'This account is inactive. Contact an administrator.'},
            status: 403,
          );
        }
        if (status.toLowerCase() == 'locked') {
          print('❌ [Login Failed] Account is locked: "$username"');
          return _jsonResponse(
            {'error': 'This account is locked. Contact an administrator.'},
            status: 403,
          );
        }

        _failedLogins.remove(key);

        final nowIso = DateTime.now().toIso8601String();
        await db.update(
          'users',
          {'last_login_at': nowIso, 'updated_at': nowIso},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        await _syncBaselineSilently();

        final roleId = row['role_id'] as String? ?? '';
        final perms = await _loadPermissionKeys(db, roleId);
        final token = _newToken();
        _sessions[token] = ApiSession(
          token: token,
          userId: row['id'] as String,
          username: row['username'] as String,
          fullName: row['full_name'] as String,
          roleId: roleId,
          permissions: perms,
        );

        print('🎉 [Login Success] User: "$username" logged in successfully from $remoteIp.');

        return _jsonResponse({
          'token': token,
          'user': {
            'id': row['id'],
            'username': row['username'],
            'fullName': row['full_name'],
            'roleId': roleId,
            'roleName': row['role_name'],
          },
          'permissions': perms.toList(),
          'version': _dataVersion,
        });
      } on FormatException catch (e) {
        return _jsonResponse({'error': 'Bad request: ${e.message}'}, status: 400);
      } catch (e) {
        print('🚨 [Server Exception] $e');
        return _jsonResponse({'error': e.toString()}, status: 500);
      }
    });

    router.post('/api/logout', (Request req) async {
      final header = req.headers['authorization'] ?? '';
      if (header.startsWith('Bearer ')) {
        _sessions.remove(header.substring(7).trim());
      }
      return _jsonResponse({'status': 'ok'});
    });

    router.post('/api/query', (Request req) => _guarded(req, (s, body) async {
      final table = body['table'] as String? ?? '';
      final where = body['where'] as String?;
      final orderBy = body['orderBy'] as String?;

      final denied = _checkRead(s, table, [where, orderBy]);
      if (denied != null) return denied;
      if (orderBy != null && !_orderBySafe.hasMatch(orderBy)) {
        return _jsonResponse({'error': 'Invalid orderBy.'}, status: 400);
      }

      final db = await _dbHelper.database;
      final rows = await db.query(
        table,
        where: where,
        whereArgs: _args(body['args']),
        orderBy: orderBy,
        limit: _asInt(body['limit']),
        offset: _asInt(body['offset']),
      );
      return _jsonResponse({
        'rows': _sanitizeRows(rows),
        'version': _dataVersion,
      });
    }));

    router.post('/api/insert', (Request req) => _guarded(req, (s, body) async {
      final table = body['table'] as String? ?? '';
      final data = _dataMap(body['data']);

      final denied = _checkWrite(s, table, 'insert', data: data);
      if (denied != null) return denied;

      final db = await _dbHelper.database;
      final id = await db.insert(table, data);
      await _afterWrite();
      return _jsonResponse({'insertedId': id, 'version': _dataVersion});
    }));

    router.post('/api/update', (Request req) => _guarded(req, (s, body) async {
      final table = body['table'] as String? ?? '';
      final data = _dataMap(body['data']);
      final where = body['where'] as String?;

      final denied =
      _checkWrite(s, table, 'update', data: data, where: where);
      if (denied != null) return denied;

      final db = await _dbHelper.database;
      final count = await db.update(
        table,
        data,
        where: where,
        whereArgs: _args(body['args']),
      );
      if (count > 0) await _afterWrite();
      return _jsonResponse({'updatedCount': count, 'version': _dataVersion});
    }));

    router.post('/api/delete', (Request req) => _guarded(req, (s, body) async {
      final table = body['table'] as String? ?? '';
      final where = body['where'] as String?;

      final denied = _checkWrite(s, table, 'delete', where: where);
      if (denied != null) return denied;

      final db = await _dbHelper.database;
      final count = await db.delete(
        table,
        where: where,
        whereArgs: _args(body['args']),
      );
      if (count > 0) await _afterWrite();
      return _jsonResponse({'deletedCount': count, 'version': _dataVersion});
    }));

    router.post('/api/raw-query', (Request req) => _guarded(req, (s, body) async {
      final sql = body['sql'] as String? ?? '';
      if (!sql.trim().toUpperCase().startsWith('SELECT')) {
        return _jsonResponse(
          {'error': 'Only SELECT queries allowed'},
          status: 403,
        );
      }
      final denied = _checkFragments(s, [sql]);
      if (denied != null) return denied;

      final db = await _dbHelper.database;
      final rows = await db.rawQuery(sql, _args(body['args']));
      return _jsonResponse({
        'rows': _sanitizeRows(rows),
        'version': _dataVersion,
      });
    }));

    router.post('/api/batch', (Request req) => _guarded(req, (s, body) async {
      final ops = body['operations'];
      if (ops is! List) {
        return _jsonResponse({'error': 'operations must be a list'}, status: 400);
      }
      if (ops.length > 500) {
        return _jsonResponse({'error': 'Too many operations.'}, status: 400);
      }

      final parsed = <Map<String, dynamic>>[];
      for (final raw in ops) {
        if (raw is! Map) {
          return _jsonResponse({'error': 'Invalid operation.'}, status: 400);
        }
        final op = Map<String, dynamic>.from(raw);
        final type = op['type'] as String? ?? '';
        final table = op['table'] as String? ?? '';
        final data = _dataMap(op['data']);
        final where = op['where'] as String?;

        final denied = _checkWrite(
          s,
          table,
          type,
          data: type == 'delete' ? null : data,
          where: where,
        );
        if (denied != null) return denied;
        parsed.add({
          'type': type,
          'table': table,
          'data': data,
          'where': where,
          'args': _args(op['args']),
        });
      }

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final op in parsed) {
          final table = op['table'] as String;
          switch (op['type']) {
            case 'insert':
              batch.insert(table, op['data'] as Map<String, dynamic>);
              break;
            case 'update':
              batch.update(
                table,
                op['data'] as Map<String, dynamic>,
                where: op['where'] as String?,
                whereArgs: op['args'] as List<dynamic>?,
              );
              break;
            case 'delete':
              batch.delete(
                table,
                where: op['where'] as String?,
                whereArgs: op['args'] as List<dynamic>?,
              );
              break;
          }
        }
        await batch.commit(noResult: true);
      });

      if (parsed.isNotEmpty) await _afterWrite();
      return _jsonResponse({
        'status': 'ok',
        'count': parsed.length,
        'version': _dataVersion,
      });
    }));

    router.post('/api/sales/complete', (Request req) => _guarded(req, (s, body) async {
      if (!s.has('sales.add')) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot create sales.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await SaleTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/purchases/complete', (Request req) => _guarded(req, (s, body) async {
      if (!s.has('purchases.add')) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot register purchases.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await PurchaseTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/returns/sales/complete', (Request req) => _guarded(req, (s, body) async {
      if (!s.hasAny(['sales.returnAction', 'sales.manage'])) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot handle sales returns.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await SalesReturnTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/returns/purchases/complete', (Request req) => _guarded(req, (s, body) async {
      if (!s.hasAny(['purchases.returnAction', 'purchases.manage'])) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot handle purchase returns.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await PurchaseReturnTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/inventory/adjust', (Request req) => _guarded(req, (s, body) async {
      if (!s.hasAny(['inventory.adjust', 'inventory.manage'])) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot adjust inventory levels.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await StockAdjustmentTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/payments/customer', (Request req) => _guarded(req, (s, body) async {
      if (!s.hasAny(['customers.edit', 'accounts.manage'])) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot post customer payments.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await CustomerPaymentTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/payments/supplier', (Request req) => _guarded(req, (s, body) async {
      if (!s.hasAny(['suppliers.edit', 'accounts.manage'])) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot post supplier payments.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await SupplierPaymentTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    router.post('/api/expenses/complete', (Request req) => _guarded(req, (s, body) async {
      if (!s.hasAny(['accounts.manage'])) {
        return _jsonResponse(
          {'error': 'Permission denied: you cannot ledger expenses.'},
          status: 403,
        );
      }
      final db = await _dbHelper.database;
      await ExpenseTransaction.run(db, body);
      await _afterWrite();
      return _jsonResponse({'status': 'ok', 'version': _dataVersion});
    }));

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    _tracker.startCleanup();

    await _syncBaselineSilently();
    _startWatcher();
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final now = DateTime.now();
      _sessions.removeWhere(
            (_, s) => now.difference(s.lastUsed) > _sessionIdleTimeout,
      );
      _failedLogins.removeWhere(
            (_, f) => now.difference(f.first) > const Duration(minutes: 5),
      );
    });
  }

  Future<void> stop() async {
    _tracker.stopCleanup();
    _watchTimer?.cancel();
    _watchTimer = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessions.clear();
    for (final w in List<Completer<void>>.from(_versionWaiters)) {
      if (!w.isCompleted) w.complete();
    }
    _versionWaiters.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Response _jsonResponse(Map<String, dynamic> data, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

class _FailedLogins {
  final int count;
  final DateTime first;
  const _FailedLogins(this.count, this.first);
}