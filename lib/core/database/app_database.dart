import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({
    DatabaseFactory? factory,
    Future<String> Function()? resolvePath,
  }) : _factory = factory ?? databaseFactory,
       _resolvePath = resolvePath ?? _defaultPath;

  static const int schemaVersion = 2;
  static const String databaseName = 'etc_inventory.db';

  final DatabaseFactory _factory;
  final Future<String> Function() _resolvePath;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final rawPath = await _resolvePath();
    final path = _normalizeDatabasePath(rawPath);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 1 && newVersion >= 1) {
            await _createSchema(db);
          }
          if (oldVersion < 2 && newVersion >= 2) {
            await _createSessionSchema(db);
          }
        },
      ),
    );
  }

  static String _normalizeDatabasePath(String rawPath) {
    final trimmed = rawPath.trim();
    final isMemoryDatabase = trimmed.isEmpty ||
        trimmed == ':memory:' ||
        trimmed == 'file::memory:' ||
        trimmed.startsWith('file::memory:') ||
        trimmed.contains('mode=memory');

    if (!isMemoryDatabase) {
      return trimmed;
    }

    final fileName = 'etc_inventory_${DateTime.now().microsecondsSinceEpoch}.db';
    return p.join(Directory.systemTemp.path, fileName);
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;

    final db = await opening;
    await db.close();
    _opening = null;
  }

  static Future<String> _defaultPath() async {
    final directory = await getDatabasesPath();
    return p.join(directory, databaseName);
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE locations (
        code TEXT PRIMARY KEY COLLATE NOCASE
          CHECK (length(trim(code)) > 0),
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE devices (
        inventory_number TEXT PRIMARY KEY COLLATE NOCASE
          CHECK (length(trim(inventory_number)) > 0),
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        classification TEXT NOT NULL CHECK (length(trim(classification)) > 0),
        location_code TEXT NOT NULL COLLATE NOCASE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (location_code)
          REFERENCES locations(code)
          ON UPDATE CASCADE
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE
          CHECK (length(trim(username)) > 0),
        password_hash TEXT NOT NULL CHECK (length(password_hash) > 0),
        role TEXT NOT NULL CHECK (role IN ('admin', 'viewer')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_users_single_admin
      ON users(role)
      WHERE role = 'admin'
    ''');
    await _createSessionSchema(db);
    await db.execute(
      'CREATE INDEX idx_devices_location ON devices(location_code)',
    );
    await db.execute(
      'CREATE INDEX idx_devices_classification ON devices(classification)',
    );
    await db.execute(
      'CREATE INDEX idx_devices_name ON devices(name COLLATE NOCASE)',
    );
  }

  static Future<void> _createSessionSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id)
          REFERENCES users(id)
          ON DELETE CASCADE
      )
    ''');
  }
}
