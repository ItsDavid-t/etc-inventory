import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/errors/failure.dart';

class InventoryDashboardStatsService {
  const InventoryDashboardStatsService(this._database);

  final AppDatabase _database;

  Future<Either<Failure, InventoryDashboardStats>> load() async {
    try {
      final db = await _database.database;
      final locationCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM locations'),
      ) ?? 0;
      final deviceCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM devices'),
      ) ?? 0;
      final classificationCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(DISTINCT classification) FROM devices',
        ),
      ) ?? 0;

      return Right(
        InventoryDashboardStats(
          locationCount: locationCount,
          deviceCount: deviceCount,
          classificationCount: classificationCount,
          alertCount: 0,
        ),
      );
    } on DatabaseException {
      return const Left(
        DatabaseFailure('No se pudo cargar el resumen del inventario.'),
      );
    }
  }
}

class InventoryDashboardStats {
  const InventoryDashboardStats({
    required this.locationCount,
    required this.deviceCount,
    required this.classificationCount,
    required this.alertCount,
  });

  final int locationCount;
  final int deviceCount;
  final int classificationCount;
  final int alertCount;
}
