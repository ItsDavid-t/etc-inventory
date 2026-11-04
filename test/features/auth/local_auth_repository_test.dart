import 'package:etc_inventory/core/database/app_database.dart';
import 'package:etc_inventory/core/errors/failure.dart';
import 'package:etc_inventory/features/auth/data/bcrypt_password_hasher.dart';
import 'package:etc_inventory/features/auth/data/local_auth_repository.dart';
import 'package:etc_inventory/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late LocalAuthRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      resolvePath: () async => inMemoryDatabasePath,
    );
    repository = LocalAuthRepository(database, BcryptPasswordHasher());
  });

  tearDown(() => database.close());

  test('creates the first administrator without a built-in credential', () async {
    expect(
      (await repository.isInitialSetupRequired()).match(
        (_) => null,
        (value) => value,
      ),
      isTrue,
    );

    final created = await repository.createInitialAdministrator(
      username: 'admin.local',
      password: 'CorrectHorseBattery',
    );

    expect(created.match((_) => null, (user) => user.role), UserRole.administrator);
    expect(
      (await repository.isInitialSetupRequired()).match(
        (_) => null,
        (value) => value,
      ),
      isFalse,
    );
    expect(
      await repository.createInitialAdministrator(
        username: 'another.admin',
        password: 'AnotherSecurePass',
      ),
      isA<Left<Failure, AppUser>>(),
    );
  });

  test('authenticates securely and returns one generic failure for bad logins',
      () async {
    await repository.createInitialAdministrator(
      username: 'admin.local',
      password: 'CorrectHorseBattery',
    );
    await repository.signOut();

    final successful = await repository.signIn(
      username: 'ADMIN.LOCAL',
      password: 'CorrectHorseBattery',
    );
    final wrongPassword = await repository.signIn(
      username: 'admin.local',
      password: 'WrongPassword000',
    );
    final unknownUser = await repository.signIn(
      username: 'unknown.user',
      password: 'WrongPassword000',
    );

    expect(_isRight(successful), isTrue);
    expect(
      wrongPassword.match((failure) => failure.message, (_) => null),
      unknownUser.match((failure) => failure.message, (_) => null),
    );
    expect(
      unknownUser,
      isA<Left<Failure, AppUser>>(),
    );
  });

  test('restores the authenticated user without storing the password', () async {
    await repository.createInitialAdministrator(
      username: 'admin.local',
      password: 'CorrectHorseBattery',
    );

    final reopenedRepository = LocalAuthRepository(
      database,
      BcryptPasswordHasher(),
    );
    final restored = await reopenedRepository.restoreSession();

    expect(
      restored.match((_) => null, (user) => user?.username),
      'admin.local',
    );
    await reopenedRepository.signOut();
    expect(
      await repository.restoreSession(),
      isA<Right<Failure, AppUser?>>(),
    );
    expect(
      (await repository.restoreSession()).match((_) => null, (user) => user),
      isNull,
    );
  });

  test('viewer cannot perform account administration even through the repository',
      () async {
    await repository.createInitialAdministrator(
      username: 'admin.local',
      password: 'CorrectHorseBattery',
    );
    await repository.createViewer(
      username: 'reader.one',
      initialPassword: 'ReaderPassword123',
    );
    await repository.signOut();
    await repository.signIn(
      username: 'reader.one',
      password: 'ReaderPassword123',
    );

    expect(
      await repository.createViewer(
        username: 'reader.two',
        initialPassword: 'ReaderPassword456',
      ),
      isA<Left<Failure, Unit>>(),
    );
    expect(await repository.listUsers(), isA<Left<Failure, List<AppUser>>>());
    expect(
      await repository.setViewerActive(userId: 2, isActive: false),
      isA<Left<Failure, Unit>>(),
    );

    await repository.signOut();
    await repository.signIn(
      username: 'admin.local',
      password: 'CorrectHorseBattery',
    );
    final users = await repository.listUsers();
    expect(users.match((_) => <AppUser>[], (value) => value), hasLength(2));

    expect(
      await repository.setViewerActive(userId: 2, isActive: false),
      isA<Right<Failure, Unit>>(),
    );
    await repository.signOut();
    final disabledLogin = await repository.signIn(
      username: 'reader.one',
      password: 'ReaderPassword123',
    );
    expect(disabledLogin, isA<Left<Failure, AppUser>>());
  });

  test('rejects short passwords and invalid usernames before storing them',
      () async {
    expect(
      await repository.createInitialAdministrator(
        username: 'a',
        password: 'short',
      ),
      isA<Left<Failure, AppUser>>(),
    );
    expect(_isRight(await repository.isInitialSetupRequired()), isTrue);
  });
}

bool _isRight<L, R>(Either<L, R> result) => result.isRight();
