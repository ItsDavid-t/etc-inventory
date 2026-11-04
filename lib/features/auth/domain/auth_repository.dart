import 'package:fpdart/fpdart.dart';

import '../../../core/errors/failure.dart';
import 'app_user.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, bool>> isInitialSetupRequired();

  Future<Either<Failure, AppUser>> signIn({
    required String username,
    required String password,
  });

  Future<Either<Failure, AppUser?>> restoreSession();

  Future<Either<Failure, AppUser>> createInitialAdministrator({
    required String username,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();

  Future<Either<Failure, Unit>> createViewer({
    required String username,
    required String initialPassword,
  });

  Future<Either<Failure, Unit>> setViewerActive({
    required int userId,
    required bool isActive,
  });

  Future<Either<Failure, Unit>> resetViewerPassword({
    required int userId,
    required String newPassword,
  });

  Future<Either<Failure, List<AppUser>>> listUsers();
}
