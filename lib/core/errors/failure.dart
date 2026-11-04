import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message);
}

final class AuthorizationFailure extends Failure {
  const AuthorizationFailure(super.message);
}

final class DuplicateRecordFailure extends Failure {
  const DuplicateRecordFailure(super.message);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

final class ImportFailure extends Failure {
  const ImportFailure(super.message);
}

final class ExportFailure extends Failure {
  const ExportFailure(super.message);
}
