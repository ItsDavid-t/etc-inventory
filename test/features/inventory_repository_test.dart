import 'package:etc_inventory/core/database/app_database.dart';
import 'package:etc_inventory/core/errors/failure.dart';
import 'package:etc_inventory/features/devices/domain/device.dart';
import 'package:etc_inventory/features/devices/sqlite_device_repository.dart';
import 'package:etc_inventory/features/inventory_excel_service.dart';
import 'package:etc_inventory/features/inventory_import_repository.dart';
import 'package:etc_inventory/features/inventory_import_summary.dart';
import 'package:etc_inventory/features/locations/domain/location.dart';
import 'package:etc_inventory/features/locations/sqlite_location_repository.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late SqliteLocationRepository locationRepository;
  late SqliteDeviceRepository deviceRepository;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      resolvePath: () async => inMemoryDatabasePath,
    );
    locationRepository = SqliteLocationRepository(database);
    deviceRepository = SqliteDeviceRepository(database);
  });

  tearDown(() => database.close());

  test('creates locations, searches them and tracks device counts', () async {
    final firstCreate = await locationRepository.create(
      const Location(code: 'ALM-01', name: 'Almacén principal'),
    );
    expect(firstCreate, isA<Right<Failure, Unit>>());

    final secondCreate = await locationRepository.create(
      const Location(code: 'ALM-02', name: 'Almacén norte'),
    );
    expect(secondCreate, isA<Right<Failure, Unit>>());

    final list = await locationRepository.findLocations(limit: 20, offset: 0);
    expect(
      list.match((_) => <Location>[], (locations) => locations),
      hasLength(2),
    );

    final lookup = await locationRepository.findByCode('alm-01');
    expect(
      lookup.match((_) => null, (location) => location?.name),
      'Almacén principal',
    );

    final search = await locationRepository.findLocations(
      search: 'norte',
      limit: 20,
      offset: 0,
    );
    expect(
      search.match((_) => <Location>[], (locations) => locations.single.name),
      'Almacén norte',
    );
  });

  test(
    'stores devices with location metadata and supports filtering',
    () async {
      await locationRepository.create(
        const Location(code: 'ALM-01', name: 'Almacén principal'),
      );

      final created = await deviceRepository.create(
        const Device(
          inventoryNumber: 'INV-1001',
          name: 'Router central',
          classification: 'Redes',
          locationCode: 'ALM-01',
        ),
      );
      expect(created, isA<Right<Failure, Unit>>());

      final byNumber = await deviceRepository.findByInventoryNumber('inv-1001');
      expect(
        byNumber.match((_) => null, (device) => device?.locationName),
        'Almacén principal',
      );

      final filtered = await deviceRepository.findDevices(
        classification: 'Redes',
        locationCode: 'ALM-01',
        limit: 20,
        offset: 0,
      );
      expect(
        filtered.match((_) => <Device>[], (devices) => devices),
        hasLength(1),
      );

      final updated = await deviceRepository.update(
        const Device(
          inventoryNumber: 'INV-1001',
          name: 'Router central actualizado',
          classification: 'Seguridad',
          locationCode: 'ALM-01',
        ),
      );
      expect(updated, isA<Right<Failure, Unit>>());

      final afterUpdate = await deviceRepository.findByInventoryNumber(
        'INV-1001',
      );
      expect(
        afterUpdate.match((_) => null, (device) => device?.classification),
        'Seguridad',
      );
    },
  );

  test('blocks deleting a location that still has assigned devices', () async {
    await locationRepository.create(
      const Location(code: 'ALM-01', name: 'Almacén principal'),
    );
    await deviceRepository.create(
      const Device(
        inventoryNumber: 'INV-2001',
        name: 'Servidor',
        classification: 'Servidor',
        locationCode: 'ALM-01',
      ),
    );

    final blocked = await locationRepository.delete('ALM-01');
    expect(blocked, isA<Left<Failure, Unit>>());

    final deviceRemoved = await deviceRepository.delete('INV-2001');
    expect(deviceRemoved, isA<Right<Failure, Unit>>());

    final allowed = await locationRepository.delete('ALM-01');
    expect(allowed, isA<Right<Failure, Unit>>());
  });

  test(
    'imports locations and devices and updates existing rows on reimport',
    () async {
      final service = InventoryExcelService(
        locationRepository: locationRepository,
        deviceRepository: deviceRepository,
        importRepository: InventoryImportRepository(database),
      );
      final bytes = _workbook([
        [
          'location_code',
          'location_name',
          'inventory_number',
          'device_name',
          'classification',
        ],
        ['ALM-01', 'Almacén principal', 'INV-01', 'Router', 'Redes'],
      ]);

      final firstImport = await service.importBytes(bytes);
      expect(firstImport, isA<Right<Failure, InventoryImportSummary>>());
      expect(
        firstImport.match((_) => -1, (summary) => summary.createdLocations),
        1,
      );
      expect(
        firstImport.match((_) => -1, (summary) => summary.createdDevices),
        1,
      );

      final secondImport = await service.importBytes(bytes);
      expect(
        secondImport.match((_) => -1, (summary) => summary.updatedLocations),
        1,
      );
      expect(
        secondImport.match((_) => -1, (summary) => summary.updatedDevices),
        1,
      );
    },
  );

  test(
    'rolls back all rows if an imported device references an unknown location',
    () async {
      final service = InventoryExcelService(
        locationRepository: locationRepository,
        deviceRepository: deviceRepository,
        importRepository: InventoryImportRepository(database),
      );
      final bytes = _workbook([
        [
          'location_code',
          'location_name',
          'inventory_number',
          'device_name',
          'classification',
        ],
        ['ALM-01', 'Almacén principal', '', '', ''],
        ['INEXISTENTE', '', 'INV-01', 'Router', 'Redes'],
      ]);

      final result = await service.importBytes(bytes);

      expect(result, isA<Left<Failure, InventoryImportSummary>>());
      final location = await locationRepository.findByCode('ALM-01');
      expect(location.match((_) => null, (value) => value), isNull);
    },
  );

  test('rejects invalid rows before changing the database', () async {
    final service = InventoryExcelService(
      locationRepository: locationRepository,
      deviceRepository: deviceRepository,
      importRepository: InventoryImportRepository(database),
    );
    final bytes = _workbook([
      [
        'location_code',
        'location_name',
        'inventory_number',
        'device_name',
        'classification',
      ],
      ['ALM-01', 'Almacén principal', 'INV-01', '', 'Redes'],
    ]);

    final result = await service.importBytes(bytes);

    expect(result, isA<Left<Failure, InventoryImportSummary>>());
    final location = await locationRepository.findByCode('ALM-01');
    expect(location.match((_) => null, (value) => value), isNull);
  });
}

List<int> _workbook(List<List<String>> rows) {
  final workbook = excel_pkg.Excel.createExcel();
  final sheet = workbook['Inventario'];
  for (final row in rows) {
    sheet.appendRow(row.map(excel_pkg.TextCellValue.new).toList());
  }
  return workbook.encode()!;
}
