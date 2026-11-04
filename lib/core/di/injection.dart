import 'package:get_it/get_it.dart';

import '../../features/auth/data/bcrypt_password_hasher.dart';
import '../../features/auth/data/local_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/auth_use_cases.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/devices/domain/device_repository.dart';
import '../../features/devices/sqlite_device_repository.dart';
import '../../features/inventory_excel_service.dart';
import '../../features/inventory_import_repository.dart';
import '../../features/inventory_dashboard_stats_service.dart';
import '../../features/locations/domain/location_repository.dart';
import '../../features/locations/sqlite_location_repository.dart';
import '../database/app_database.dart';

final GetIt getIt = GetIt.instance;

void configureDependencies() {
  if (getIt.isRegistered<AuthRepository>()) return;

  getIt.registerLazySingleton<AppDatabase>(AppDatabase.new);
  getIt.registerLazySingleton<BcryptPasswordHasher>(BcryptPasswordHasher.new);
  getIt.registerLazySingleton<AuthRepository>(
    () => LocalAuthRepository(
      getIt<AppDatabase>(),
      getIt<BcryptPasswordHasher>(),
    ),
  );
  getIt.registerLazySingleton<LocationRepository>(
    () => SqliteLocationRepository(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<DeviceRepository>(
    () => SqliteDeviceRepository(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<InventoryImportRepository>(
    () => InventoryImportRepository(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<InventoryDashboardStatsService>(
    () => InventoryDashboardStatsService(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<InventoryExcelService>(
    () => InventoryExcelService(
      locationRepository: getIt<LocationRepository>(),
      deviceRepository: getIt<DeviceRepository>(),
      importRepository: getIt<InventoryImportRepository>(),
    ),
  );
  getIt.registerLazySingleton<AuthUseCases>(
    () => AuthUseCases(getIt<AuthRepository>()),
  );
  getIt.registerFactory<AuthCubit>(() => AuthCubit(getIt<AuthUseCases>()));
}
