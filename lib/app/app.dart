// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:window_manager/window_manager.dart';
//
// import '../core/data/database_helper.dart';
// import '../core/network/api_client.dart';
// import '../core/network/api_server.dart';
// import '../core/network/connection_tracker.dart';
// import '../core/network/network_config.dart';
// import '../core/theme/app_theme.dart';
// import '../features/authentication/data/http_auth_repository.dart';
// import '../features/authentication/data/sqlite_auth_repository.dart';
// import '../features/authentication/presentation/controllers/auth_controller.dart';
// import '../features/authentication/presentation/screens/onboarding_screen.dart';
// import '../features/licensing/data/sqlite_license_repository.dart';
// import '../features/licensing/presentation/controllers/license_controller.dart';
// import '../features/settings/data/sqlite_settings_repository.dart';
// import '../features/shell/presentation/screens/shell_screen.dart';
//
// class PharmacyApp extends StatefulWidget {
//   const PharmacyApp({super.key});
//
//   @override
//   State<PharmacyApp> createState() => _PharmacyAppState();
// }
//
// class _PharmacyAppState extends State<PharmacyApp>
//     with WidgetsBindingObserver, WindowListener {
//   final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
//   AuthController? _authController;
//   ApiServer? _autoServer;
//   final _licenseRepo = SqliteLicenseRepository();
//   late final LicenseController _licenseController;
//
//   bool _isInitialized = false;
//   String? _dbError;
//   bool _isClosing = false;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       windowManager.addListener(this);
//     }
//
//     _licenseController = LicenseController(repository: _licenseRepo);
//     _initApp();
//   }
//
//   @override
//   void onWindowClose() async {
//     if (_isClosing) return;
//     _isClosing = true;
//
//     try {
//       if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//         await windowManager.hide();
//       }
//       await DatabaseHelper.createBackup();
//       debugPrint('[Auto-Backup] Close backup completed successfully.');
//     } catch (e) {
//       debugPrint('[Auto-Backup] Close backup error: $e');
//     } finally {
//       try {
//         _autoServer?.stop();
//       } catch (_) {}
//       exit(0);
//     }
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.paused ||
//         state == AppLifecycleState.detached) {
//       DatabaseHelper.createBackup();
//     }
//   }
//
//   Future<void> _initApp() async {
//     try {
//       await DatabaseHelper.instance.database;
//
//       final settingsRepo = SqliteSettingsRepository();
//       final settingsResult = await settingsRepo.getAllSettings();
//       settingsResult.fold(
//         onSuccess: (settings) {
//           final map = {for (final s in settings) s.key: s.value};
//           NetworkConfig.instance.loadFromSettings(map);
//         },
//         onFailure: (_) {},
//       );
//
//       final isClient = NetworkConfig.instance.isClient;
//       final authRepo = isClient
//           ? HttpAuthRepository(
//         api: ApiClient.instance,
//         localFallback: SqliteAuthRepository(),
//       )
//           : SqliteAuthRepository();
//
//       _authController = AuthController(authRepository: authRepo);
//       ApiClient.instance.onSessionExpired =
//       isClient ? _handleSessionExpired : null;
//
//       if (NetworkConfig.instance.isServer &&
//           NetworkConfig.instance.autoStartServer) {
//         _startAutoServer();
//       }
//
//       await DatabaseHelper.createBackup();
//
//       if (mounted) {
//         setState(() => _isInitialized = true);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _dbError = e.toString());
//       }
//     }
//   }
//
//   void _handleSessionExpired() {
//     if (_authController != null && _authController!.isAuthenticated) {
//       _authController!.logout();
//     }
//   }
//
//   Future<void> _startAutoServer() async {
//     try {
//       _autoServer = ApiServer(
//         dbHelper: DatabaseHelper.instance,
//         tracker: ConnectionTracker(),
//         port: NetworkConfig.instance.port,
//       );
//       await _autoServer!.start();
//     } catch (_) {}
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       windowManager.removeListener(this);
//     }
//     ApiClient.instance.onSessionExpired = null;
//     _autoServer?.stop();
//     _licenseController.dispose();
//     _authController?.dispose();
//     DatabaseHelper.instance.close();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_isInitialized || _authController == null) {
//       return MaterialApp(
//         theme: AppTheme.light,
//         debugShowCheckedModeBanner: false,
//         home: Scaffold(
//           body: Center(
//             child: _dbError != null
//                 ? Text(
//               'Database initialization error:\n$_dbError',
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Colors.red),
//             )
//                 : const CircularProgressIndicator(),
//           ),
//         ),
//       );
//     }
//
//     // Always open to auth flow. License is enforced at login, not at startup.
//     return MaterialApp(
//       title: 'PharmaSuite ERP',
//       debugShowCheckedModeBanner: false,
//       navigatorKey: _navigatorKey,
//       theme: AppTheme.light,
//       home: ListenableBuilder(
//         listenable: _authController!,
//         builder: (context, _) {
//           if (_authController!.isAuthenticated) {
//             return ShellScreen(
//               key: ValueKey(_authController!.currentUser!.id),
//               authController: _authController!,
//             );
//           }
//
//           return OnboardingScreen(
//             authController: _authController!,
//             licenseController: _licenseController,
//             onLoginSuccess: () {},
//           );
//         },
//       ),
//     );
//   }
// }
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
import '../features/authentication/presentation/screens/onboarding_screen.dart';
import '../features/licensing/data/sqlite_license_repository.dart';
import '../features/licensing/presentation/controllers/license_controller.dart';
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
  final _licenseRepo = SqliteLicenseRepository();
  late final LicenseController _licenseController;

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

    _licenseController = LicenseController(repository: _licenseRepo);
    _initApp();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      // 1. Hide the window immediately for a better user experience
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.hide();
      }

      // 2. Perform backups
      await DatabaseHelper.createBackup();
      debugPrint('[Auto-Backup] Close backup completed successfully.');
    } catch (e) {
      debugPrint('[Auto-Backup] Close backup error: $e');
    } finally {
      // 3. Stop background services
      try {
        _autoServer?.stop();
      } catch (_) {}

      // 4. CRITICAL: Safely close the database to flush WAL locks
      try {
        await DatabaseHelper.instance.close();
        debugPrint('[DB] Database closed cleanly.');
      } catch (e) {
        debugPrint('[DB] Close error: $e');
      }

      // 5. Safely destroy the window process (Do NOT use exit(0))
      await windowManager.destroy();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Prevent reopening/backing up the DB while the window is closing
    if (_isClosing) return;

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

      await DatabaseHelper.createBackup();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dbError = e.toString());
      }
    }
  }

  void _handleSessionExpired() {
    if (_authController != null && _authController!.isAuthenticated) {
      _authController!.logout();
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
    _licenseController.dispose();
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

    // Always open to auth flow. License is enforced at login, not at startup.
    return MaterialApp(
      title: 'PharmaSuite ERP',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: _authController!,
        builder: (context, _) {
          if (_authController!.isAuthenticated) {
            return ShellScreen(
              key: ValueKey(_authController!.currentUser!.id),
              authController: _authController!,
            );
          }

          return OnboardingScreen(
            authController: _authController!,
            licenseController: _licenseController,
            onLoginSuccess: () {},
          );
        },
      ),
    );
  }
}