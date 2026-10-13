// lib/app/app.dart

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
// NOTE: We now import the unified OnboardingScreen instead of LoginScreen
import '../features/authentication/presentation/screens/onboarding_screen.dart';
import '../features/licensing/data/mock_license_repository.dart';
import '../features/licensing/domain/license.dart';
import '../features/settings/data/sqlite_settings_repository.dart';
import '../features/shell/presentation/screens/shell_screen.dart';

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key});

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> with WidgetsBindingObserver, WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AuthController? _authController;
  ApiServer? _autoServer;
  final _licenseRepo = MockLicenseRepository();

  bool _isInitialized = false;
  String? _dbError;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }

    _initApp();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.hide();
      }
      await DatabaseHelper.createBackup();
      debugPrint('[Auto-Backup] Close backup completed successfully.');
    } catch (e) {
      debugPrint('[Auto-Backup] Close backup error: $e');
    } finally {
      try {
        _autoServer?.stop();
      } catch (_) {}
      exit(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
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
          ? HttpAuthRepository(api: ApiClient.instance, localFallback: SqliteAuthRepository())
          : SqliteAuthRepository();

      _authController = AuthController(authRepository: authRepo);
      ApiClient.instance.onSessionExpired = isClient ? _handleSessionExpired : null;

      if (NetworkConfig.instance.isServer && NetworkConfig.instance.autoStartServer) {
        _startAutoServer();
      }

      await DatabaseHelper.createBackup();
      await _evaluateAppFlow();
    } catch (e) {
      if (mounted) {
        setState(() {
          _dbError = e.toString();
        });
      }
    }
  }

  Future<void> _evaluateAppFlow() async {
    // If the user was already logged in from a previous session, verify their license hasn't expired
    if (_authController!.isAuthenticated) {
      final licResult = await _licenseRepo.getLicenseInfo();
      bool isExpired = false;

      licResult.fold(
        onSuccess: (info) => isExpired = (info.status == LicenseStatus.expired),
        onFailure: (_) {},
      );

      // If expired while they were away, log them out.
      // The OnboardingScreen will force them to the renewal tab when they try to log back in.
      if (isExpired) {
        await _authController!.logout();
      }
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _handleSessionExpired() {
    if (_authController != null && _authController!.isAuthenticated) {
      _authController!.logout();
      _evaluateAppFlow();
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
    if (!_isInitialized || _authController == null) {
      return MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: _dbError != null
                ? Text(
              'Database initialization error:\n$_dbError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'PharmaSuite ERP',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: _authController!,
        builder: (context, _) {
          // 1. If user is successfully logged in (and license is valid), show the Main App
          if (_authController!.isAuthenticated) {
            return ShellScreen(
              key: ValueKey(_authController!.currentUser!.id),
              authController: _authController!,
            );
          }

          // 2. Otherwise, show the unified Onboarding / Login / Renewal split-screen
          return OnboardingScreen(
            authController: _authController!,
            onLoginSuccess: () {
              // The UI will rebuild automatically because authController is a Listenable
              // and isAuthenticated is now true.
            },
          );
        },
      ),
    );
  }
}