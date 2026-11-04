import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/app_user.dart';
import '../domain/auth_use_cases.dart';

enum AuthStatus {
  checking,
  setupRequired,
  signedOut,
  authenticated,
  failure,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.checking,
    this.user,
    this.message,
  });

  final AuthStatus status;
  final AppUser? user;
  final String? message;

  @override
  List<Object?> get props => [status, user, message];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._useCases) : super(const AuthState());

  final AuthUseCases _useCases;

  Future<void> checkInitialSetup() async {
    emit(const AuthState(status: AuthStatus.checking));
    final result = await _useCases.isInitialSetupRequired();
    await result.match(
      (failure) async => emit(
        AuthState(status: AuthStatus.failure, message: failure.message),
      ),
      (setupRequired) async {
        if (setupRequired) {
          emit(const AuthState(status: AuthStatus.setupRequired));
          return;
        }

        final session = await _useCases.restoreSession();
        session.match(
          (failure) => emit(
            AuthState(status: AuthStatus.failure, message: failure.message),
          ),
          (user) => emit(
            user == null
                ? const AuthState(status: AuthStatus.signedOut)
                : AuthState(status: AuthStatus.authenticated, user: user),
          ),
        );
      },
    );
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    emit(const AuthState(status: AuthStatus.checking));
    final result = await _useCases.signIn(
      username: username,
      password: password,
    );
    result.match(
      (failure) => emit(
        AuthState(status: AuthStatus.signedOut, message: failure.message),
      ),
      (user) => emit(
        AuthState(status: AuthStatus.authenticated, user: user),
      ),
    );
  }

  Future<void> createInitialAdministrator({
    required String username,
    required String password,
  }) async {
    emit(const AuthState(status: AuthStatus.checking));
    final result = await _useCases.createInitialAdministrator(
      username: username,
      password: password,
    );
    result.match(
      (failure) => emit(
        AuthState(status: AuthStatus.setupRequired, message: failure.message),
      ),
      (user) => emit(
        AuthState(status: AuthStatus.authenticated, user: user),
      ),
    );
  }

  Future<void> signOut() async {
    final result = await _useCases.signOut();
    result.match(
      (failure) => emit(
        AuthState(
          status: AuthStatus.authenticated,
          user: state.user,
          message: failure.message,
        ),
      ),
      (_) => emit(const AuthState(status: AuthStatus.signedOut)),
    );
  }
}
