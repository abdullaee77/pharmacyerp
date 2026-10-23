// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:window_manager/window_manager.dart';
// import 'app/app.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Initialize SQLite FFI database factory for Windows/Linux desktop
//   if (Platform.isWindows || Platform.isLinux) {
//     sqfliteFfiInit();
//     databaseFactory = databaseFactoryFfi;
//   }
//
//   // Initialize WindowManager on desktop to intercept 'X' close button
//   if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//     await windowManager.ensureInitialized();
//
//     const windowOptions = WindowOptions(
//       center: true,
//       backgroundColor: Colors.transparent,
//       skipTaskbar: false,
//       title: 'PharmaSuite ERP',
//     );
//
//     await windowManager.waitUntilReadyToShow(windowOptions, () async {
//       await windowManager.show();
//       await windowManager.focus();
//     });
//
//     // Prevent immediate termination so we can complete DB backup first
//     await windowManager.setPreventClose(true);
//   }
//
//   runApp(const PharmacyApp());
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Fixed DB location (not dependent on working directory)
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'databases'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    await databaseFactory.setDatabasesPath(dbDir.path);
    debugPrint('[DB] Path: ${dbDir.path}');
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'PharmaSuite ERP',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await windowManager.setPreventClose(true);
  }

  runApp(const PharmacyApp());
}