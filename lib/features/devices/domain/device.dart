import 'package:equatable/equatable.dart';

class Device extends Equatable {
  const Device({
    required this.inventoryNumber,
    required this.name,
    required this.classification,
    required this.locationCode,
    this.locationName,
  });

  final String inventoryNumber;
  final String name;
  final String classification;
  final String locationCode;
  final String? locationName;

  @override
  List<Object?> get props => [
    inventoryNumber,
    name,
    classification,
    locationCode,
    locationName,
  ];
}
