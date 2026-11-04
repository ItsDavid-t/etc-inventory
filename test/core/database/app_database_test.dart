import 'package:etc_inventory/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      resolvePath: () async => inMemoryDatabasePath,
    );
    database = await appDatabase.database;
  });

  tearDown(() => appDatabase.close());

  test('enables foreign keys and creates the versioned schema', () async {
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    final version = await database.getVersion();
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(foreignKeys.single['foreign_keys'], 1);
    expect(version, AppDatabase.schemaVersion);
    expect(
      tables.map((row) => row['name']),
      containsAll(['locations', 'devices', 'users']),
    );
  });

  test('keeps inventory numbers and location codes unique', () async {
    await _insertLocation(database, code: '000A-01');
    await _insertDevice(database, inventoryNumber: '0001-A');

    await expectLater(
      _insertLocation(database, code: '000a-01'),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      _insertDevice(database, inventoryNumber: '0001-a'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects missing locations and prevents deleting used locations', () async {
    await expectLater(
      _insertDevice(
        database,
        inventoryNumber: 'INV-1',
        locationCode: 'MISSING',
      ),
      throwsA(isA<DatabaseException>()),
    );

    await _insertLocation(database, code: 'LOC-1');
    await _insertDevice(
      database,
      inventoryNumber: 'INV-1',
      locationCode: 'LOC-1',
    );

    await expectLater(
      database.delete(
        'locations',
        where: 'code = ?',
        whereArgs: ['LOC-1'],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('enforces a single administrator in the database', () async {
    await _insertUser(database, username: 'admin1', role: 'admin');
    await _insertUser(database, username: 'reader', role: 'viewer');

    await expectLater(
      _insertUser(database, username: 'admin2', role: 'admin'),
      throwsA(isA<DatabaseException>()),
    );
  });
}

Future<void> _insertLocation(DatabaseExecutor db, {required String code}) {
  final now = DateTime.utc(2026).toIso8601String();
  return db.insert('locations', {
    'code': code,
    'name': 'Test location',
    'created_at': now,
    'updated_at': now,
  });
}

Future<void> _insertDevice(
  DatabaseExecutor db, {
  required String inventoryNumber,
  String locationCode = '000A-01',
}) {
  final now = DateTime.utc(2026).toIso8601String();
  return db.insert('devices', {
    'inventory_number': inventoryNumber,
    'name': 'Test equipment',
    'classification': 'Test category',
    'location_code': locationCode,
    'created_at': now,
    'updated_at': now,
  });
}

Future<void> _insertUser(
  DatabaseExecutor db, {
  required String username,
  required String role,
}) {
  final now = DateTime.utc(2026).toIso8601String();
  return db.insert('users', {
    'username': username,
    'password_hash': 'test-only-hash',
    'role': role,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  });
}
