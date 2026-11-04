import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/errors/failure.dart';
import 'devices/domain/device.dart';
import 'inventory_import_summary.dart';
import 'locations/domain/location.dart';

class InventoryImportRepository {
  const InventoryImportRepository(this._database);

  final AppDatabase _database;

  Future<Either<Failure, InventoryImportSummary>> importRecords({
    required List<Location> locations,
    required List<Device> devices,
  }) async {
    try {
      final db = await _database.database;
      return Right(
        await db.transaction((transaction) async {
          var createdLocations = 0;
          var updatedLocations = 0;
          var createdDevices = 0;
          var updatedDevices = 0;

          for (var index = 0; index < locations.length; index += 1) {
            if (index % 50 == 0) {
              await Future<void>.delayed(Duration.zero);
            }
            final location = locations[index];
            final code = location.code.trim();
            final existing = await transaction.query(
              'locations',
              columns: ['code'],
              where: 'code = ?',
              whereArgs: [code],
              limit: 1,
            );
            await transaction.insert(
              'locations',
              {
                'code': code,
                'name': location.name.trim(),
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            if (existing.isEmpty) {
              createdLocations += 1;
            } else {
              await transaction.update(
                'locations',
                {
                  'name': location.name.trim(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                },
                where: 'code = ?',
                whereArgs: [code],
              );
              updatedLocations += 1;
            }
          }

          for (var index = 0; index < devices.length; index += 1) {
            if (index % 50 == 0) {
              await Future<void>.delayed(Duration.zero);
            }
            final device = devices[index];
            final number = device.inventoryNumber.trim();
            final existing = await transaction.query(
              'devices',
              columns: ['inventory_number'],
              where: 'inventory_number = ?',
              whereArgs: [number],
              limit: 1,
            );
            if (existing.isEmpty) {
              await transaction.insert('devices', {
                'inventory_number': number,
                'name': device.name.trim(),
                'classification': device.classification.trim(),
                'location_code': device.locationCode.trim(),
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              });
              createdDevices += 1;
            } else {
              await transaction.update(
                'devices',
                {
                  'name': device.name.trim(),
                  'classification': device.classification.trim(),
                  'location_code': device.locationCode.trim(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                },
                where: 'inventory_number = ?',
                whereArgs: [number],
              );
              updatedDevices += 1;
            }
          }

          return InventoryImportSummary(
            createdLocations: createdLocations,
            updatedLocations: updatedLocations,
            createdDevices: createdDevices,
            updatedDevices: updatedDevices,
            skippedRows: 0,
          );
        }),
      );
    } on DatabaseException {
      return const Left(
        ImportFailure(
          'No se importaron los datos: hay referencias o valores inválidos. '
          'No se realizaron cambios.',
        ),
      );
    }
  }
}
