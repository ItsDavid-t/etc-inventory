import 'package:fpdart/fpdart.dart';

import '../../../core/errors/failure.dart';
import 'app_user.dart';
import 'auth_repository.dart';

class AuthUseCases {
  const AuthUseCases(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, bool>> isInitialSetupRequired() =>
      _repository.isInitialSetupRequired();

  Future<Either<Failure, AppUser>> signIn({
    required String username,
    required String password,
  }) => _repository.signIn(username: username, password: password);

  Future<Either<Failure, AppUser?>> restoreSession() =>
      _repository.restoreSession();

  Future<Either<Failure, AppUser>> createInitialAdministrator({
    required String username,
    required String password,
  }) => _repository.createInitialAdministrator(
    username: username,
    password: password,
  );

  Future<Either<Failure, Unit>> signOut() => _repository.signOut();

  Future<Either<Failure, Unit>> createViewer({
    required String username,
    required String initialPassword,
  }) => _repository.createViewer(
    username: username,
    initialPassword: initialPassword,
  );

  Future<Either<Failure, Unit>> setViewerActive({
    required int userId,
    required bool isActive,
  }) => _repository.setViewerActive(userId: userId, isActive: isActive);

  Future<Either<Failure, Unit>> resetViewerPassword({
    required int userId,
    required String newPassword,
  }) => _repository.resetViewerPassword(
    userId: userId,
    newPassword: newPassword,
  );

  Future<Either<Failure, List<AppUser>>> listUsers() =>
      _repository.listUsers();
}
