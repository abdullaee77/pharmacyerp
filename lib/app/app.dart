import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
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

class _PharmacyAppState extends State<PharmacyApp>
    with WidgetsBindingObserver, WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AuthController? _authController;
  ApiServer? _autoServer;
  bool _dbReady = false;
  String? _dbError;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register desktop window close listener
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }

    _initApp();
  }

  // ── Intercept desktop "X" (close) button ──
  @override
  void onWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      // 1. Instantly hide the window — user sees it close immediately with 0 lag
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.hide();
      }

      // 2. Perform the backup in the background
      await DatabaseHelper.createBackup();
      debugPrint('[Auto-Backup] Close backup completed successfully.');
    } catch (e) {
      debugPrint('[Auto-Backup] Close backup error: $e');
    } finally {
      // 3. Cleanly and immediately terminate the application process
      try {
        _autoServer?.stop();
      } catch (_) {}
      exit(0);
    }
  }

  // ── Mobile lifecycle fallback ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      DatabaseHelper.createBackup();
    }
  }

  Future<void> _initApp() async {
    try {
      await DatabaseHelper.instance.database;

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
      ApiClient.instance.onSessionExpired =
      isClient ? _handleSessionExpired : null;

      if (NetworkConfig.instance.isServer &&
          NetworkConfig.instance.autoStartServer) {
        _startAutoServer();
      }

      // Auto-backup on startup (keeps latest 3 copies)
      DatabaseHelper.createBackup();

      if (mounted) setState(() => _dbReady = true);
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
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }

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
          return ShellScreen(
            key: ValueKey(user.id.value),
            authController: _authController!,
          );
        },
      ),
    );
  }
}