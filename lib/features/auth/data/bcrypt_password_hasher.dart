import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

class BcryptPasswordHasher {
  static const int workFactor = 12;

  Future<String> hash(String password) => Isolate.run(() {
    final salt = BCrypt.gensalt(logRounds: workFactor);
    return BCrypt.hashpw(password, salt);
  });

  Future<bool> verify(String password, String passwordHash) =>
      Isolate.run(() => BCrypt.checkpw(password, passwordHash));
}
