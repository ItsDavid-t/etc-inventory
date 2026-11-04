import 'dart:convert';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/failure.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import 'bcrypt_password_hasher.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._database, this._passwordHasher);

  static const String _genericSignInError = 'Usuario o contraseña incorrectos.';
  static const String _usernamePattern = r'^[A-Za-z0-9._-]{3,32}$';

  final AppDatabase _database;
  final BcryptPasswordHasher _passwordHasher;
  int? _sessionUserId;
  Future<String>? _dummyPasswordHash;

  @override
  Future<Either<Failure, bool>> isInitialSetupRequired() async {
    try {
      final db = await _database.database;
      final admins = await db.query(
        'users',
        columns: ['id'],
        where: 'role = ?',
        whereArgs: ['admin'],
        limit: 1,
      );
      return Right(admins.isEmpty);
    } on DatabaseException {
      return const Left(DatabaseFailure('No se pudo consultar la base de datos.'));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const Left(AuthenticationFailure(_genericSignInError));
    }

    try {
      final db = await _database.database;
      final rows = await db.query(
        'users',
        columns: ['id', 'username', 'password_hash', 'role', 'is_active'],
        where: 'username = ?',
        whereArgs: [username.trim()],
        limit: 1,
      );
      final row = rows.isEmpty ? null : rows.single;
      final storedHash = row == null
          ? await _dummyHash()
          : row['password_hash']! as String;
      final passwordMatches = await _passwordHasher.verify(password, storedHash);

      if (row == null ||
          !passwordMatches ||
          (row['is_active']! as int) != 1) {
        return const Left(AuthenticationFailure(_genericSignInError));
      }

      final user = _mapUser(row);
      _sessionUserId = user.id;
      await _saveSession(user.id, db);
      return Right(user);
    } on DatabaseException {
      return const Left(DatabaseFailure('No se pudo consultar la base de datos.'));
    } on FormatException {
      return const Left(
        DatabaseFailure('Las credenciales almacenadas no son válidas.'),
      );
    }
  }

  @override
  Future<Either<Failure, AppUser?>> restoreSession() async {
    try {
      final db = await _database.database;
      final sessions = await db.query(
        'auth_session',
        columns: ['user_id'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (sessions.isEmpty) return const Right(null);

      final userId = sessions.single['user_id']! as int;
      final rows = await db.query(
        'users',
        columns: ['id', 'username', 'role', 'is_active'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.delete('auth_session', where: 'id = ?', whereArgs: [1]);
        return const Right(null);
      }

      final user = _mapUser(rows.single);
      _sessionUserId = user.id;
      return Right(user);
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo restaurar la sesión guardada.'),
      );
    } on FormatException {
      return const Left(
        DatabaseFailure('La sesión guardada no es válida.'),
      );
    }
  }

  @override
  Future<Either<Failure, AppUser>> createInitialAdministrator({
    required String username,
    required String password,
  }) async {
    final usernameError = _validateUsername(username);
    if (usernameError != null) return Left(usernameError);
    final passwordError = _validatePassword(password);
    if (passwordError != null) return Left(passwordError);

    final normalizedUsername = username.trim();
    final passwordHash = await _passwordHasher.hash(password);
    try {
      final db = await _database.database;
      final userId = await db.transaction((txn) async {
        final existingAdmin = await txn.query(
          'users',
          columns: ['id'],
          where: 'role = ?',
          whereArgs: ['admin'],
          limit: 1,
        );
        if (existingAdmin.isNotEmpty) throw const _AdminAlreadyExists();

        final now = DateTime.now().toUtc().toIso8601String();
        return txn.insert('users', {
          'username': normalizedUsername,
          'password_hash': passwordHash,
          'role': UserRole.administrator.databaseValue,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      });

      _sessionUserId = userId;
      await _saveSession(userId, db);
      return Right(
        AppUser(
          id: userId,
          username: normalizedUsername,
          role: UserRole.administrator,
          isActive: true,
        ),
      );
    } on _AdminAlreadyExists {
      return const Left(
        DuplicateRecordFailure('Ya existe un administrador configurado.'),
      );
    } on DatabaseException catch (error) {
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    _sessionUserId = null;
    try {
      final db = await _database.database;
      await db.delete('auth_session', where: 'id = ?', whereArgs: [1]);
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo cerrar la sesión guardada.'),
      );
    }
    return const Right(unit);
  }

  Future<void> _saveSession(int userId, DatabaseExecutor db) async {
    await db.insert(
      'auth_session',
      {
        'id': 1,
        'user_id': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Either<Failure, Unit>> createViewer({
    required String username,
    required String initialPassword,
  }) async {
    final usernameError = _validateUsername(username);
    if (usernameError != null) return Left(usernameError);
    final passwordError = _validatePassword(initialPassword);
    if (passwordError != null) return Left(passwordError);

    try {
      final db = await _database.database;
      if (!await _hasAdministratorSession(db)) {
        return const Left(AuthorizationFailure('Se requiere una sesión de administrador.'));
      }
      final passwordHash = await _passwordHasher.hash(initialPassword);
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('users', {
        'username': username.trim(),
        'password_hash': passwordHash,
        'role': UserRole.viewer.databaseValue,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      return const Right(unit);
    } on DatabaseException catch (error) {
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> setViewerActive({
    required int userId,
    required bool isActive,
  }) async {
    try {
      final db = await _database.database;
      if (!await _hasAdministratorSession(db)) {
        return const Left(AuthorizationFailure('Se requiere una sesión de administrador.'));
      }
      final changed = await db.update(
        'users',
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND role = ?',
        whereArgs: [userId, UserRole.viewer.databaseValue],
      );
      if (changed == 0) {
        return const Left(NotFoundFailure('No se encontró el usuario de consulta.'));
      }
      return const Right(unit);
    } on DatabaseException catch (error) {
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> resetViewerPassword({
    required int userId,
    required String newPassword,
  }) async {
    final passwordError = _validatePassword(newPassword);
    if (passwordError != null) return Left(passwordError);

    try {
      final db = await _database.database;
      if (!await _hasAdministratorSession(db)) {
        return const Left(AuthorizationFailure('Se requiere una sesión de administrador.'));
      }
      final passwordHash = await _passwordHasher.hash(newPassword);
      final changed = await db.update(
        'users',
        {
          'password_hash': passwordHash,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND role = ?',
        whereArgs: [userId, UserRole.viewer.databaseValue],
      );
      if (changed == 0) {
        return const Left(NotFoundFailure('No se encontró el usuario de consulta.'));
      }
      return const Right(unit);
    } on DatabaseException catch (error) {
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<AppUser>>> listUsers() async {
    try {
      final db = await _database.database;
      if (!await _hasAdministratorSession(db)) {
        return const Left(AuthorizationFailure('Se requiere una sesión de administrador.'));
      }
      final rows = await db.query(
        'users',
        columns: ['id', 'username', 'role', 'is_active'],
        orderBy: 'username COLLATE NOCASE',
      );
      return Right(rows.map(_mapUser).toList(growable: false));
    } on DatabaseException {
      return const Left(DatabaseFailure('No se pudo consultar la base de datos.'));
    }
  }

  Future<bool> _hasAdministratorSession(DatabaseExecutor db) async {
    final userId = _sessionUserId;
    if (userId == null) return false;

    final rows = await db.query(
      'users',
      columns: ['id'],
      where: 'id = ? AND role = ? AND is_active = 1',
      whereArgs: [userId, UserRole.administrator.databaseValue],
      limit: 1,
    );
    if (rows.isEmpty) _sessionUserId = null;
    return rows.isNotEmpty;
  }

  Future<String> _dummyHash() => _dummyPasswordHash ??= _createDummyHash();

  Future<String> _createDummyHash() {
    final random = Random.secure();
    final randomPassword = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    return _passwordHasher.hash(randomPassword);
  }

  static AppUser _mapUser(Map<String, Object?> row) {
    final role = switch (row['role']) {
      'admin' => UserRole.administrator,
      'viewer' => UserRole.viewer,
      _ => throw const FormatException('Unknown user role'),
    };
    return AppUser(
      id: row['id']! as int,
      username: row['username']! as String,
      role: role,
      isActive: row['is_active']! as int == 1,
    );
  }

  static Failure? _validateUsername(String username) {
    if (!RegExp(_usernamePattern).hasMatch(username.trim())) {
      return const ValidationFailure(
        'El usuario debe tener entre 3 y 32 caracteres: letras, números, punto, guion o guion bajo.',
      );
    }
    return null;
  }

  static Failure? _validatePassword(String password) {
    final byteLength = utf8.encode(password).length;
    if (byteLength < 12 || byteLength > 72) {
      return const ValidationFailure(
        'La contraseña debe tener al menos 12 caracteres y no superar 72 bytes UTF-8.',
      );
    }
    return null;
  }

  static Failure _databaseFailure(DatabaseException error) {
    if (error.isUniqueConstraintError()) {
      return const DuplicateRecordFailure('El nombre de usuario ya está en uso.');
    }
    return const DatabaseFailure('No se pudo completar la operación en la base de datos.');
  }
}

final class _AdminAlreadyExists implements Exception {
  const _AdminAlreadyExists();
}
