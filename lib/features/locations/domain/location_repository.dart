import 'package:fpdart/fpdart.dart';

import '../../../core/errors/failure.dart';
import '../../devices/domain/device.dart';
import 'location.dart';

abstract interface class LocationRepository {
  Future<Either<Failure, List<Location>>> findLocations({
    String? search,
    required int limit,
    required int offset,
  });

  Future<Either<Failure, Location?>> findByCode(String code);

  Future<Either<Failure, List<Device>>> findDevicesAtLocation({
    required String code,
    required int limit,
    required int offset,
  });

  Future<Either<Failure, Unit>> create(Location location);

  Future<Either<Failure, Unit>> update(Location location);

  Future<Either<Failure, Unit>> delete(String code);
}
