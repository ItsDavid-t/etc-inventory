import 'package:etc_inventory/core/errors/failure.dart';
import 'package:etc_inventory/features/auth/domain/app_user.dart';
import 'package:etc_inventory/features/auth/domain/auth_repository.dart';
import 'package:etc_inventory/features/auth/domain/auth_use_cases.dart';
import 'package:etc_inventory/features/auth/presentation/auth_cubit.dart';
import 'package:etc_inventory/inventory_app.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen renders the app title', (tester) async {
    final cubit = AuthCubit(AuthUseCases(_FakeAuthRepository()));
    await cubit.checkInitialSetup();
    await tester.pumpWidget(InventoryApp(authCubit: cubit));

    expect(find.text('Inventario ETECSA'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    await cubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, bool>> isInitialSetupRequired() async =>
      const Right(false);

  @override
  Future<Either<Failure, AppUser?>> restoreSession() async => const Right(null);

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String username,
    required String password,
  }) async => Right(
    AppUser(
      id: 1,
      username: username,
      role: UserRole.viewer,
      isActive: true,
    ),
  );

  @override
  Future<Either<Failure, AppUser>> createInitialAdministrator({
    required String username,
    required String password,
  }) async => Right(
    AppUser(
      id: 1,
      username: username,
      role: UserRole.administrator,
      isActive: true,
    ),
  );

  @override
  Future<Either<Failure, Unit>> signOut() async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> createViewer({
    required String username,
    required String initialPassword,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> setViewerActive({
    required int userId,
    required bool isActive,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> resetViewerPassword({
    required int userId,
    required String newPassword,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, List<AppUser>>> listUsers() async =>
      const Right([]);
}
