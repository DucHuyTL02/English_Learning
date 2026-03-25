import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static const String databaseName = 'database.db';
  static bool _ffiReady = false;

  static Future<Database> open({
    required int version,
    required OnDatabaseCreateFn onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseConfigureFn? onConfigure,
  }) async {
    await _configureDatabaseFactory();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, databaseName);
    return openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onConfigure: onConfigure,
    );
  }

  static Future<void> _configureDatabaseFactory() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite local database is not supported on web.');
    }
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (isDesktop && !_ffiReady) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiReady = true;
    }
  }
}
