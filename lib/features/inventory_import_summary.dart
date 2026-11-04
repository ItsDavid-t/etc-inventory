class InventoryImportSummary {
  const InventoryImportSummary({
    required this.createdLocations,
    required this.updatedLocations,
    required this.createdDevices,
    required this.updatedDevices,
    required this.skippedRows,
  });

  final int createdLocations;
  final int updatedLocations;
  final int createdDevices;
  final int updatedDevices;
  final int skippedRows;

  int get totalLocations => createdLocations + updatedLocations;
  int get totalDevices => createdDevices + updatedDevices;
}
