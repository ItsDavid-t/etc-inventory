import 'package:equatable/equatable.dart';

class Location extends Equatable {
  const Location({
    required this.code,
    required this.name,
    this.deviceCount = 0,
  });

  final String code;
  final String name;
  final int deviceCount;

  @override
  List<Object?> get props => [code, name, deviceCount];
}
