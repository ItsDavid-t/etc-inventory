import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/failure.dart';
import '../devices/domain/device.dart';
import 'domain/location.dart';
import 'domain/location_repository.dart';

class SqliteLocationRepository implements LocationRepository {
  const SqliteLocationRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Either<Failure, List<Location>>> findLocations({
    String? search,
    required int limit,
    required int offset,
  }) async {
    final query = _buildLocationQuery(search);
    try {
      final db = await _database.database;
      final rows = await db.rawQuery(query.sql, query.args);
      final items = rows
          .map(_mapLocation)
          .skip(offset)
          .take(limit)
          .toList(growable: false);
      return Right(items);
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo consultar la base de datos.'),
      );
    }
  }

  @override
  Future<Either<Failure, Location?>> findByCode(String code) async {
    final normalized = _normalizeCode(code);
    if (normalized == null) {
      return const Left(
        ValidationFailure('El código de ubicación es obligatorio.'),
      );
    }

    try {
      final db = await _database.database;
      final rows = await db.rawQuery(
        '''
        SELECT l.code,
               l.name,
               COUNT(d.inventory_number) AS device_count
        FROM locations l
        LEFT JOIN devices d ON d.location_code = l.code
        WHERE l.code = ?
        GROUP BY l.code, l.name
        ''',
        [normalized],
      );
      return Right(rows.isEmpty ? null : _mapLocation(rows.single));
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo consultar la base de datos.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Device>>> findDevicesAtLocation({
    required String code,
    required int limit,
    required int offset,
  }) async {
    final normalized = _normalizeCode(code);
    if (normalized == null) {
      return const Left(
        ValidationFailure('El código de ubicación es obligatorio.'),
      );
    }

    try {
      final db = await _database.database;
      final rows = await db.rawQuery(
        '''
        SELECT d.inventory_number,
               d.name,
               d.classification,
               d.location_code,
               l.name AS location_name
        FROM devices d
        INNER JOIN locations l ON l.code = d.location_code
        WHERE d.location_code = ?
        ORDER BY d.name COLLATE NOCASE
        LIMIT ? OFFSET ?
        ''',
        [normalized, limit, offset],
      );
      return Right(rows.map(_mapDevice).toList(growable: false));
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo consultar la base de datos.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> create(Location location) async {
    final validation = _validateLocation(location);
    if (validation != null) return Left(validation);

    try {
      final db = await _database.database;
      await db.insert('locations', {
        'code': location.code.trim(),
        'name': location.name.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.fail);
      return const Right(unit);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return const Left(
          DuplicateRecordFailure('Ya existe una ubicación con ese código.'),
        );
      }
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> update(Location location) async {
    final validation = _validateLocation(location);
    if (validation != null) return Left(validation);

    try {
      final db = await _database.database;
      final changed = await db.update(
        'locations',
        {
          'code': location.code.trim(),
          'name': location.name.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'code = ?',
        whereArgs: [location.code.trim()],
      );
      if (changed == 0) {
        return const Left(
          NotFoundFailure('No se encontró la ubicación seleccionada.'),
        );
      }
      return const Right(unit);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return const Left(
          DuplicateRecordFailure('Ya existe una ubicación con ese código.'),
        );
      }
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String code) async {
    final normalized = _normalizeCode(code);
    if (normalized == null) {
      return const Left(
        ValidationFailure('El código de ubicación es obligatorio.'),
      );
    }

    try {
      final db = await _database.database;
      final changed = await db.delete(
        'locations',
        where: 'code = ?',
        whereArgs: [normalized],
      );
      if (changed == 0) {
        return const Left(
          NotFoundFailure('No se encontró la ubicación seleccionada.'),
        );
      }
      return const Right(unit);
    } on DatabaseException catch (_) {
      return const Left(
        ValidationFailure(
          'No se puede eliminar la ubicación porque tiene equipos asociados.',
        ),
      );
    }
  }

  _LocationQuery _buildLocationQuery(String? search) {
    final whereClauses = <String>[];
    final args = <Object>[];

    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      whereClauses.add('(l.code LIKE ? OR l.name LIKE ?)');
      args.add(term);
      args.add(term);
    }

    final where = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final sql =
        '''
      SELECT l.code,
             l.name,
             COUNT(d.inventory_number) AS device_count
      FROM locations l
      LEFT JOIN devices d ON d.location_code = l.code
      $where
      GROUP BY l.code, l.name
      ORDER BY l.name COLLATE NOCASE
    ''';

    return _LocationQuery(sql: sql, args: args);
  }

  static Failure? _validateLocation(Location location) {
    final code = location.code.trim();
    final name = location.name.trim();
    if (code.isEmpty) {
      return const ValidationFailure('El código de ubicación es obligatorio.');
    }
    if (name.isEmpty) {
      return const ValidationFailure(
        'El nombre de la ubicación es obligatorio.',
      );
    }
    return null;
  }

  static String? _normalizeCode(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static Location _mapLocation(Map<String, Object?> row) {
    return Location(
      code: row['code']! as String,
      name: row['name']! as String,
      deviceCount: row['device_count'] as int? ?? 0,
    );
  }

  static Device _mapDevice(Map<String, Object?> row) {
    return Device(
      inventoryNumber: row['inventory_number']! as String,
      name: row['name']! as String,
      classification: row['classification']! as String,
      locationCode: row['location_code']! as String,
      locationName: row['location_name'] as String?,
    );
  }

  static Failure _databaseFailure(DatabaseException error) {
    return const DatabaseFailure(
      'No se pudo completar la operación en la base de datos.',
    );
  }
}

class _LocationQuery {
  const _LocationQuery({required this.sql, required this.args});

  final String sql;
  final List<Object> args;
}
