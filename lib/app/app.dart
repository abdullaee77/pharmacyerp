import 'package:flutter/material.dart';
import '../core/data/database_helper.dart';
import '../core/network/api_client.dart';
import '../core/network/api_server.dart';
import '../core/network/connection_tracker.dart';
import '../core/network/network_config.dart';
import '../core/theme/app_theme.dart';
import '../features/authentication/data/http_auth_repository.dart';
import '../features/authentication/data/sqlite_auth_repository.dart';
import '../features/authentication/presentation/controllers/auth_controller.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/settings/data/sqlite_settings_repository.dart';
import '../features/shell/presentation/screens/shell_screen.dart';

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key});

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AuthController? _authController;
  ApiServer? _autoServer;
  bool _dbReady = false;
  String? _dbError;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 1. Ensure local SQLite database is ready
      await DatabaseHelper.instance.database;

      // 2. Load Network Configuration early to set client vs server/standalone mode
      final settingsRepo = SqliteSettingsRepository();
      final settingsResult = await settingsRepo.getAllSettings();
      settingsResult.fold(
        onSuccess: (settings) {
          final map = {for (final s in settings) s.key: s.value};
          NetworkConfig.instance.loadFromSettings(map);
        },
        onFailure: (_) {},
      );

      final isClient = NetworkConfig.instance.isClient;
      final authRepo = isClient
          ? HttpAuthRepository(
        api: ApiClient.instance,
        localFallback: SqliteAuthRepository(),
      )
          : SqliteAuthRepository();

      _authController = AuthController(authRepository: authRepo);

      // 3. Handle session expiration on LAN clients
      ApiClient.instance.onSessionExpired = isClient ? _handleSessionExpired : null;

      // 4. Auto-start background API server if this PC is configured as Main Server
      if (NetworkConfig.instance.isServer && NetworkConfig.instance.autoStartServer) {
        _startAutoServer();
      }

      if (mounted) {
        setState(() => _dbReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dbReady = false;
          _dbError = e.toString();
        });
      }
    }
  }

  void _handleSessionExpired() {
    if (_authController != null && _authController!.isAuthenticated) {
      _authController!.logout();
      // Dismiss any open modals/dialogs and return cleanly to the login screen
      final navState = _navigatorKey.currentState;
      if (navState != null && navState.canPop()) {
        navState.popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _startAutoServer() async {
    try {
      _autoServer = ApiServer(
        dbHelper: DatabaseHelper.instance,
        tracker: ConnectionTracker(),
        port: NetworkConfig.instance.port,
      );
      await _autoServer!.start();
    } catch (_) {
      // Non-fatal: user can still manage/start server from Network & LAN settings
    }
  }

  @override
  void dispose() {
    ApiClient.instance.onSessionExpired = null;
    _autoServer?.stop();
    _authController?.dispose();
    DatabaseHelper.instance.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaSuite ERP',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      home: !_dbReady || _authController == null
          ? Scaffold(
        body: Center(
          child: _dbError != null
              ? Text(
            'Database initialization error:\n$_dbError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          )
              : const CircularProgressIndicator(),
        ),
      )
          : ListenableBuilder(
        listenable: _authController!,
        builder: (context, _) {
          final user = _authController!.currentUser;
          if (user == null) {
            return LoginScreen(controller: _authController!);
          }
          // Keyed by user so a new login always builds a fresh shell
          // (menus, tabs, and cached pages never leak between users).
          return ShellScreen(
            key: ValueKey(user.id.value),
            authController: _authController!,
          );
        },
      ),
    );
  }
}