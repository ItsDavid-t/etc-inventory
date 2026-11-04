import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:fpdart/fpdart.dart';

import '../core/errors/failure.dart';
import 'devices/domain/device.dart';
import 'devices/domain/device_repository.dart';
import 'inventory_import_repository.dart';
import 'inventory_import_summary.dart';
import 'locations/domain/location.dart';
import 'locations/domain/location_repository.dart';

class InventoryExcelService {
  const InventoryExcelService({
    required this._locationRepository,
    required this._deviceRepository,
    required this._importRepository,
  });

  final LocationRepository _locationRepository;
  final DeviceRepository _deviceRepository;
  final InventoryImportRepository _importRepository;

  Future<Either<Failure, List<Location>>> _loadLocations() async {
    const pageSize = 500;
    final allLocations = <Location>[];
    for (var offset = 0; ; offset += pageSize) {
      final result = await _locationRepository.findLocations(
        limit: pageSize,
        offset: offset,
      );
      final failure = result.match((value) => value, (_) => null);
      if (failure != null) return Left(failure);
      final page = result.match((_) => <Location>[], (value) => value);
      allLocations.addAll(page);
      if (page.length < pageSize) return Right(allLocations);
    }
  }

  Future<Either<Failure, List<Device>>> _loadDevices() async {
    const pageSize = 500;
    final allDevices = <Device>[];
    for (var offset = 0; ; offset += pageSize) {
      final result = await _deviceRepository.findDevices(
        limit: pageSize,
        offset: offset,
      );
      final failure = result.match((value) => value, (_) => null);
      if (failure != null) return Left(failure);
      final page = result.match((_) => <Device>[], (value) => value);
      allDevices.addAll(page);
      if (page.length < pageSize) return Right(allDevices);
    }
  }

  Future<Either<Failure, String>> exportInventory() async {
    try {
      final locationsResult = await _loadLocations();
      final locationsFailure = locationsResult.match(
        (failure) => failure,
        (_) => null,
      );
      if (locationsFailure != null) return Left(locationsFailure);

      final devicesResult = await _loadDevices();
      final devicesFailure = devicesResult.match(
        (failure) => failure,
        (_) => null,
      );
      if (devicesFailure != null) return Left(devicesFailure);

      final locations = locationsResult.match(
        (_) => const <Location>[],
        (items) => items,
      );
      final devices = devicesResult.match(
        (_) => const <Device>[],
        (items) => items,
      );

      final workbook = excel_pkg.Excel.createExcel();
      final sheet = workbook[workbook.tables.keys.first];
      sheet.appendRow([
        _textCell('location_code'),
        _textCell('location_name'),
        _textCell('inventory_number'),
        _textCell('device_name'),
        _textCell('classification'),
      ]);

      for (final location in locations) {
        sheet.appendRow([
          _textCell(location.code),
          _textCell(location.name),
          _textCell(''),
          _textCell(''),
          _textCell(''),
        ]);
      }

      for (final device in devices) {
        sheet.appendRow([
          _textCell(device.locationCode),
          _textCell(device.locationName ?? ''),
          _textCell(device.inventoryNumber),
          _textCell(device.name),
          _textCell(device.classification),
        ]);
      }

      final encoded = workbook.encode();
      if (encoded == null) {
        return const Left(
          ExportFailure('No se pudo generar el archivo Excel.'),
        );
      }

      final fileName = 'inventario_ete_$_timestamp.xlsx';
      final savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(encoded),
      );

      if (savedPath == null || savedPath.isEmpty) {
        return const Left(ExportFailure('Se canceló la exportación.'));
      }

      return Right(savedPath);
    } on Exception {
      return const Left(
        ExportFailure('No se pudo exportar el inventario a Excel.'),
      );
    }
  }

  Future<Either<Failure, InventoryImportSummary>> importInventory() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return const Left(ImportFailure('No se seleccionó ningún archivo.'));
      }

      final file = picked.files.first;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        return const Left(
          ImportFailure('No se pudo leer el archivo seleccionado.'),
        );
      }

      if (_isLegacyXls(bytes)) {
        return const Left(
          ImportFailure(
            'El archivo seleccionado es .xls antiguo y no se puede leer '
            'directamente. Ábrelo en Excel y usa "Guardar como" formato '
            '.xlsx; luego importa ese archivo.',
          ),
        );
      }
      return await importBytes(bytes);
    } on Exception catch (error) {
      return Left(ImportFailure('No se pudo leer el archivo Excel: $error'));
    }
  }

  Future<Either<Failure, InventoryImportSummary>?> _importKnownInventorySheets(
    excel_pkg.Excel workbook,
  ) async {
    final sheets = <String, excel_pkg.Sheet>{};
    for (final entry in workbook.tables.entries) {
      sheets[_normalizeHeader(entry.key)] = entry.value;
    }

    final assetsSheet = _findSheet(sheets, 'activos');
    final costCentersSheet = _findSheet(sheets, 'centro_costo') ??
        _findSheet(sheets, 'centro_de_costo');
    if (assetsSheet == null || costCentersSheet == null) return null;

    final locations = <Location>[];
    final devices = <Device>[];
    final locationCodes = <String>{};
    final inventoryNumbers = <String>{};

    for (final row in costCentersSheet.rows.skip(1)) {
      final code = _cellTextAt(row, 0).trim();
      final name = _cellTextAt(row, 1).trim();
      if (code.isEmpty || name.isEmpty) {
        continue;
      }
      final normalizedCode = code.toUpperCase();
      if (locationCodes.add(normalizedCode)) {
        locations.add(Location(code: normalizedCode, name: name));
      }
    }

    for (final row in assetsSheet.rows.skip(1)) {
      final inventoryNumber = _cellTextAt(row, 0).trim();
      final deviceName = _cellTextAt(row, 1).trim();
      final classification = _cellTextAt(row, 2).trim();
      final locationCode = _cellTextAt(row, 3).trim();
      if (inventoryNumber.isEmpty ||
          locationCode.isEmpty) {
        continue;
      }

      final normalizedNumber = inventoryNumber.toUpperCase();
      final normalizedLocation = locationCode.toUpperCase();
      if (!inventoryNumbers.add(normalizedNumber)) {
        return Left(
          ImportFailure(
            'Número de inventario duplicado en la hoja activos: '
            '$inventoryNumber.',
          ),
        );
      }
      devices.add(
        Device(
          inventoryNumber: normalizedNumber,
          name: deviceName.isEmpty ? normalizedNumber : deviceName,
          classification: classification.isEmpty
              ? 'Sin clasificación'
              : classification,
          locationCode: normalizedLocation,
        ),
      );
    }

    if (locations.isEmpty && devices.isEmpty) {
      return const Left(
        ImportFailure(
          'Las hojas activos y centro_costo no contienen registros válidos.',
        ),
      );
    }

    return await _importRepository.importRecords(
      locations: locations,
      devices: devices,
    );
  }

  Future<Either<Failure, InventoryImportSummary>> importBytes(
    List<int> bytes,
  ) async {
    try {
      await Future<void>.delayed(Duration.zero);
      final workbook = excel_pkg.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        return const Left(
          ImportFailure('El archivo no contiene una hoja de cálculo válida.'),
        );
      }

      final pairedSheetsResult = await _importKnownInventorySheets(workbook);
      if (pairedSheetsResult != null) return pairedSheetsResult;

      final sheetsWithRows = workbook.tables.values
          .where((sheet) => sheet.rows.isNotEmpty)
          .toList(growable: false);
      if (sheetsWithRows.isEmpty) {
        return const Left(
          ImportFailure('El archivo no contiene una hoja de cálculo válida.'),
        );
      }

      final sheet = sheetsWithRows.firstWhere(
        (candidate) => _findHeaderRow(candidate.rows) != -1,
        orElse: () => sheetsWithRows.first,
      );
      final rows = sheet.rows;
      final headerRowIndex = _findHeaderRow(rows);
      if (headerRowIndex == -1 || rows.length <= headerRowIndex + 1) {
        return const Left(
          ImportFailure(
            'No se encontró una fila de encabezados válida en el archivo.',
          ),
        );
      }

      final headers = rows[headerRowIndex]
          .map((value) => _normalizeHeader(_cellText(value)))
          .toList(growable: false);

      final locationCodeIndex = _headerIndex(headers, [
        'location_code',
        'codigo_ubicacion',
        'code',
        'codigo',
        'centro_costo',
        'centro_de_costo',
        'centro',
        'ubicacion',
        'ubicacion_codigo',
      ]);
      final locationNameIndex = _headerIndex(headers, [
        'location_name',
        'nombre_ubicacion',
        'location',
        'nombre',
        'descripcion_ubicacion',
        'nombre_del_centro',
      ]);
      final inventoryNumberIndex = _headerIndex(headers, [
        'inventory_number',
        'numero_inventario',
        'inventory',
        'numero',
        'activo',
        'codigo_activo',
        'numero_activo',
        'nro_activo',
        'no_activo',
        'no',
        'activo_fijo',
        'codigo_activo_fijo',
        'no_activo_fijo',
        'numero_de_activo',
      ]);
      final deviceNameIndex = _headerIndex(headers, [
        'device_name',
        'nombre_equipo',
        'device',
        'equipo',
        'descripcion',
        'descripcion_activo',
        'nombre_activo',
        'descripcion_del_activo',
      ]);
      final classificationIndex = _headerIndex(headers, [
        'classification',
        'clasificacion',
        'tipo',
        'grupo_activo',
        'categoria',
      ]);

      if (locationCodeIndex == -1 && inventoryNumberIndex == -1) {
        return const Left(
          ImportFailure(
            'El archivo debe incluir columnas de ubicación y/o equipos válidas.',
          ),
        );
      }

      final locations = <Location>[];
      final devices = <Device>[];
      final locationNamesByCode = <String, String>{};
      final inventoryNumbers = <String>{};
      var invalidRows = 0;

      for (var index = headerRowIndex + 1; index < rows.length; index += 1) {
        if (index % 50 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final row = rows[index];
        final locationCode = _cellTextAt(row, locationCodeIndex).trim();
        final locationName = _cellTextAt(row, locationNameIndex).trim();
        final inventoryNumber = _cellTextAt(row, inventoryNumberIndex).trim();
        final deviceName = _cellTextAt(row, deviceNameIndex).trim();
        final classification = _cellTextAt(row, classificationIndex).trim();
        if (locationCode.isEmpty &&
            locationName.isEmpty &&
            inventoryNumber.isEmpty &&
            deviceName.isEmpty &&
            classification.isEmpty) {
          continue;
        }

        if (locationCode.isNotEmpty &&
            locationName.isEmpty &&
            inventoryNumber.isEmpty) {
          invalidRows += 1;
          continue;
        }

        if (locationCode.isNotEmpty && locationName.isNotEmpty) {
          final normalizedCode = locationCode.toUpperCase();
          final existingName = locationNamesByCode[normalizedCode];
          if (existingName != null && existingName != locationName) {
            return Left(
              ImportFailure(
                'El código de ubicación $locationCode tiene nombres distintos '
                'en la fila ${index + 1}.',
              ),
            );
          }
          if (existingName == null) {
            locationNamesByCode[normalizedCode] = locationName;
            locations.add(Location(code: normalizedCode, name: locationName));
          }
        }

        if (inventoryNumber.isNotEmpty) {
          if (locationCode.isEmpty || deviceName.isEmpty) {
            invalidRows += 1;
            continue;
          }

          final normalizedNumber = inventoryNumber.toUpperCase();
          if (!inventoryNumbers.add(normalizedNumber)) {
            return Left(
              ImportFailure(
                'Número de inventario duplicado en la fila ${index + 1}: '
                '$inventoryNumber.',
              ),
            );
          }
          devices.add(
            Device(
              inventoryNumber: normalizedNumber,
              name: deviceName.isEmpty ? normalizedNumber : deviceName,
              classification: classification.isEmpty
                  ? 'Sin clasificación'
                  : classification,
              locationCode: locationCode.toUpperCase(),
            ),
          );
          if (!locationNamesByCode.containsKey(locationCode.toUpperCase())) {
            invalidRows += 1;
          }
        }
      }

      if (invalidRows > 0) {
        return Left(
          ImportFailure(
            '$invalidRows fila(s) de equipo tienen campos obligatorios vacíos. '
            'No se importó ningún dato.',
          ),
        );
      }
      if (locations.isEmpty && devices.isEmpty) {
        return const Left(
          ImportFailure('No se encontraron registros válidos para importar.'),
        );
      }

      return await _importRepository.importRecords(
        locations: locations,
        devices: devices,
      );
    } on Exception {
      return const Left(
        ImportFailure(
          'No se pudo procesar el archivo Excel. No se realizaron cambios.',
        ),
      );
    }
  }

  static String _cellTextAt(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return _cellText(row[index]);
  }

  static String _cellText(Object? value) {
    if (value == null) return '';
    if (value is excel_pkg.Data) {
      return _cellText(value.value);
    }
    if (value is excel_pkg.TextCellValue) {
      return _textSpanText(value.value).trim();
    }
    if (value is excel_pkg.IntCellValue) return value.value.toString();
    if (value is excel_pkg.DoubleCellValue) return value.value.toString();
    if (value is excel_pkg.BoolCellValue) return value.value.toString();
    if (value is excel_pkg.DateCellValue) return value.asDateTimeLocal().toIso8601String();
    if (value is excel_pkg.DateTimeCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }
    return value.toString().trim();
  }

  static String _textSpanText(excel_pkg.TextSpan span) {
    final text = span.text;
    if (text != null) return text;
    return span.children?.map(_textSpanText).join() ?? '';
  }

  static int _headerIndex(List<String?> headers, List<String> acceptedNames) {
    for (final acceptedName in acceptedNames) {
      final normalizedAcceptedName = _normalizeHeader(acceptedName);
      final index = headers.indexWhere(
        (header) =>
            header != null &&
            (header == normalizedAcceptedName ||
                header.contains(normalizedAcceptedName) ||
                normalizedAcceptedName.contains(header)),
      );
      if (index != -1) return index;
    }
    return -1;
  }

  static int _findHeaderRow(List<List<dynamic>> rows) {
    final limit = rows.length < 100 ? rows.length : 100;
    for (var rowIndex = 0; rowIndex < limit; rowIndex += 1) {
      final headers = rows[rowIndex]
          .map((value) => _normalizeHeader(_cellText(value)))
          .toList(growable: false);
      final hasLocation = _headerIndex(headers, [
          'location_code',
          'codigo_ubicacion',
          'code',
          'codigo',
          'centro_costo',
          'centro_de_costo',
          'centro',
          'ubicacion',
          'ubicacion_codigo',
          'centro_costo_contable',
          'centro_de_costos',
        ]) !=
        -1;
      final hasDevice = _headerIndex(headers, [
          'inventory_number',
          'numero_inventario',
          'inventory',
          'numero',
          'activo',
          'codigo_activo',
          'numero_activo',
          'nro_activo',
          'no_activo',
          'no',
          'activo_fijo',
          'codigo_activo_fijo',
          'no_activo_fijo',
          'numero_de_activo',
          'no_de_activo',
          'no_activo_fijo',
          'id_activo',
          'codigo_de_activo',
        ]) !=
        -1;
      if (hasLocation || hasDevice) return rowIndex;
    }
    return -1;
  }

  static String _normalizeHeader(String value) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    var normalized = value.trim().toLowerCase();
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static excel_pkg.Sheet? _findSheet(
    Map<String, excel_pkg.Sheet> sheets,
    String expectedName,
  ) {
    final normalizedExpected = _normalizeHeader(expectedName);
    for (final entry in sheets.entries) {
      final name = _normalizeHeader(entry.key);
      if (name == normalizedExpected || name.contains(normalizedExpected)) {
        return entry.value;
      }
    }
    return null;
  }

  static excel_pkg.TextCellValue _textCell(String value) =>
      excel_pkg.TextCellValue(value);

  static String get _timestamp =>
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');

  static bool _isLegacyXls(List<int> bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0 &&
      bytes[4] == 0xA1 &&
      bytes[5] == 0xB1 &&
      bytes[6] == 0x1A &&
      bytes[7] == 0xE1;
}
