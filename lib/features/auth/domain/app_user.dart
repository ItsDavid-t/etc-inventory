import 'package:equatable/equatable.dart';

enum UserRole {
  administrator,
  viewer;

  String get databaseValue => switch (this) {
    UserRole.administrator => 'admin',
    UserRole.viewer => 'viewer',
  };
}

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String username;
  final UserRole role;
  final bool isActive;

  bool get canManageInventory => role == UserRole.administrator;

  @override
  List<Object?> get props => [id, username, role, isActive];
}
