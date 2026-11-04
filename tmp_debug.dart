import 'package:etc_inventory/core/database/app_database.dart';
import 'package:etc_inventory/features/auth/data/bcrypt_password_hasher.dart';
import 'package:etc_inventory/features/auth/data/local_auth_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  final database = AppDatabase(
    factory: databaseFactoryFfi,
    resolvePath: () async => inMemoryDatabasePath,
  );
  final repo = LocalAuthRepository(database, BcryptPasswordHasher());
  print('before setup: ${await repo.isInitialSetupRequired()}');
  final created = await repo.createInitialAdministrator(username: 'admin.local', password: 'CorrectHorseBattery');
  print('create result: $created');
  final after = await repo.isInitialSetupRequired();
  print('after setup: $after');
  final db = await database.database;
  final rows = await db.query('users');
  print('rows: $rows');
}
