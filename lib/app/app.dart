import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/data/database_helper.dart';
import '../features/authentication/data/sqlite_auth_repository.dart';
import '../features/authentication/presentation/controllers/auth_controller.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/shell/presentation/screens/shell_screen.dart';

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key});

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> {
  late final SqliteAuthRepository _authRepository;
  late final AuthController _authController;
  bool _dbReady = false;
  String? _dbError;

  @override
  void initState() {
    super.initState();
    _authRepository = SqliteAuthRepository();
    _authController = AuthController(authRepository: _authRepository);
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      await DatabaseHelper.instance.database;
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

  @override
  void dispose() {
    _authController.dispose();
    DatabaseHelper.instance.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaSuite ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: !_dbReady
          ? Scaffold(
        body: Center(
          child: _dbError != null
              ? Text('Database error: $_dbError')
              : const CircularProgressIndicator(),
        ),
      )
          : ListenableBuilder(
        listenable: _authController,
        builder: (context, _) {
          if (!_authController.isAuthenticated) {
            return LoginScreen(controller: _authController);
          }
          return ShellScreen(authController: _authController);
        },
      ),
    );
  }
}