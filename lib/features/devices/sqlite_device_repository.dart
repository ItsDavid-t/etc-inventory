import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/failure.dart';
import 'domain/device.dart';
import 'domain/device_repository.dart';

class SqliteDeviceRepository implements DeviceRepository {
  const SqliteDeviceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Either<Failure, List<String>>> findClassifications() async {
    try {
      final db = await _database.database;
      final rows = await db.rawQuery(
        '''
        SELECT DISTINCT classification
        FROM devices
        WHERE length(trim(classification)) > 0
        ORDER BY classification COLLATE NOCASE
        ''',
      );
      return Right(
        rows
            .map((row) => row['classification']! as String)
            .toList(growable: false),
      );
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudieron consultar las clasificaciones.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Device>>> findDevices({
    String? search,
    String? classification,
    String? locationCode,
    required int limit,
    required int offset,
  }) async {
    final query = _buildQuery(
      search: search,
      classification: classification,
      locationCode: locationCode,
    );

    try {
      final db = await _database.database;
      final rows = await db.rawQuery(query.sql, [...query.args, limit, offset]);
      return Right(rows.map(_mapDevice).toList(growable: false));
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo consultar la base de datos.'),
      );
    }
  }

  @override
  Future<Either<Failure, Device?>> findByInventoryNumber(
    String inventoryNumber,
  ) async {
    final normalized = _normalizeInventoryNumber(inventoryNumber);
    if (normalized == null) {
      return const Left(
        ValidationFailure('El número de inventario es obligatorio.'),
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
        LEFT JOIN locations l ON l.code = d.location_code
        WHERE d.inventory_number = ?
        ''',
        [normalized],
      );
      return Right(rows.isEmpty ? null : _mapDevice(rows.single));
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo consultar la base de datos.'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> create(Device device) async {
    final validation = _validateDevice(device);
    if (validation != null) return Left(validation);

    final locationExists = await _locationExists(device.locationCode);
    if (locationExists == false) {
      return const Left(
        NotFoundFailure('La ubicación indicada no existe en la base de datos.'),
      );
    }

    try {
      final db = await _database.database;
      await db.insert('devices', {
        'inventory_number': device.inventoryNumber.trim(),
        'name': device.name.trim(),
        'classification': device.classification.trim(),
        'location_code': device.locationCode.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.fail);
      return const Right(unit);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return const Left(
          DuplicateRecordFailure(
            'Ya existe un equipo con ese número de inventario.',
          ),
        );
      }
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> update(Device device) async {
    final validation = _validateDevice(device);
    if (validation != null) return Left(validation);

    final locationExists = await _locationExists(device.locationCode);
    if (locationExists == false) {
      return const Left(
        NotFoundFailure('La ubicación indicada no existe en la base de datos.'),
      );
    }

    try {
      final db = await _database.database;
      final changed = await db.update(
        'devices',
        {
          'name': device.name.trim(),
          'classification': device.classification.trim(),
          'location_code': device.locationCode.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'inventory_number = ?',
        whereArgs: [device.inventoryNumber.trim()],
      );
      if (changed == 0) {
        return const Left(
          NotFoundFailure('No se encontró el equipo seleccionado.'),
        );
      }
      return const Right(unit);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return const Left(
          DuplicateRecordFailure(
            'Ya existe un equipo con ese número de inventario.',
          ),
        );
      }
      return Left(_databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String inventoryNumber) async {
    final normalized = _normalizeInventoryNumber(inventoryNumber);
    if (normalized == null) {
      return const Left(
        ValidationFailure('El número de inventario es obligatorio.'),
      );
    }

    try {
      final db = await _database.database;
      final deleted = await db.delete(
        'devices',
        where: 'inventory_number = ?',
        whereArgs: [normalized],
      );
      if (deleted == 0) {
        return const Left(
          NotFoundFailure('No se encontró el equipo seleccionado.'),
        );
      }
      return const Right(unit);
    } on DatabaseException catch (_) {
      return const Left(
        DatabaseFailure(
          'No se pudo completar la operación en la base de datos.',
        ),
      );
    }
  }

  Future<bool> _locationExists(String locationCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'locations',
      columns: ['code'],
      where: 'code = ?',
      whereArgs: [locationCode.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  _DeviceQuery _buildQuery({
    String? search,
    String? classification,
    String? locationCode,
  }) {
    final clauses = <String>[];
    final args = <Object>[];

    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      clauses.add(
        '(d.name LIKE ? OR d.inventory_number LIKE ? OR d.classification LIKE ?)',
      );
      args.add(term);
      args.add(term);
      args.add(term);
    }
    if (classification != null && classification.trim().isNotEmpty) {
      clauses.add('d.classification = ?');
      args.add(classification.trim());
    }
    if (locationCode != null && locationCode.trim().isNotEmpty) {
      clauses.add('d.location_code = ?');
      args.add(locationCode.trim());
    }

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final sql =
        '''
      SELECT d.inventory_number,
             d.name,
             d.classification,
             d.location_code,
             l.name AS location_name
      FROM devices d
      LEFT JOIN locations l ON l.code = d.location_code
      $where
      ORDER BY d.name COLLATE NOCASE
      LIMIT ? OFFSET ?
    ''';

    return _DeviceQuery(sql: sql, args: args);
  }

  static Failure? _validateDevice(Device device) {
    final inventoryNumber = device.inventoryNumber.trim();
    final name = device.name.trim();
    final classification = device.classification.trim();
    final locationCode = device.locationCode.trim();
    if (inventoryNumber.isEmpty) {
      return const ValidationFailure('El número de inventario es obligatorio.');
    }
    if (name.isEmpty) {
      return const ValidationFailure('El nombre del equipo es obligatorio.');
    }
    if (classification.isEmpty) {
      return const ValidationFailure(
        'La clasificación del equipo es obligatoria.',
      );
    }
    if (locationCode.isEmpty) {
      return const ValidationFailure('La ubicación del equipo es obligatoria.');
    }
    return null;
  }

  static String? _normalizeInventoryNumber(String inventoryNumber) {
    final normalized = inventoryNumber.trim();
    if (normalized.isEmpty) return null;
    return normalized;
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

class _DeviceQuery {
  const _DeviceQuery({required this.sql, required this.args});

  final String sql;
  final List<Object> args;
}
