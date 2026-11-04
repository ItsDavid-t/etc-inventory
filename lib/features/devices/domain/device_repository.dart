import 'package:fpdart/fpdart.dart';

import '../../../core/errors/failure.dart';
import 'device.dart';

abstract interface class DeviceRepository {
  Future<Either<Failure, List<Device>>> findDevices({
    String? search,
    String? classification,
    String? locationCode,
    required int limit,
    required int offset,
  });

  Future<Either<Failure, List<String>>> findClassifications();

  Future<Either<Failure, Device?>> findByInventoryNumber(String inventoryNumber);

  Future<Either<Failure, Unit>> create(Device device);

  Future<Either<Failure, Unit>> update(Device device);

  Future<Either<Failure, Unit>> delete(String inventoryNumber);
}
