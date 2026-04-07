import 'package:freezed_annotation/freezed_annotation.dart';

part 'load.freezed.dart';
part 'load.g.dart';

@freezed
class Load with _$Load {
  const factory Load({
    required String id,
    required String loadNumber,
    required LoadStatus status,
    required Location origin,
    required Location destination,
    required String pickupDate,
    required String deliveryDate,
    required Cargo cargo,
    required double rate,
    required double distance,
    List<String>? requirements,
    String? assignedDriver,
    String? assignedTruck,
    required String createdBy,
    required String createdAt,
  }) = _Load;

  factory Load.fromJson(Map<String, dynamic> json) => _$LoadFromJson(json);
}

@freezed
class Location with _$Location {
  const factory Location({
    required String address,
    required String city,
    required String state,
    required String zipCode,
    double? lat,
    double? lng,
    String? contactName,
    String? contactPhone,
    String? specialInstructions,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}

@freezed
class Cargo with _$Cargo {
  const factory Cargo({
    required String description,
    required double weight,
    required int pieces,
    required String type,
  }) = _Cargo;

  factory Cargo.fromJson(Map<String, dynamic> json) => _$CargoFromJson(json);
}

enum LoadStatus {
  @JsonValue('posted')
  posted,
  @JsonValue('assigned')
  assigned,
  @JsonValue('in-transit')
  inTransit,
  @JsonValue('delivered')
  delivered,
  @JsonValue('cancelled')
  cancelled,
}
