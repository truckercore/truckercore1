import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver.freezed.dart';
part 'driver.g.dart';

@freezed
class Driver with _$Driver {
  const factory Driver({
    required String id,
    required String name,
    required String licenseNumber,
    required String phone,
    required String email,
    required DriverStatus status,
    DriverLocation? currentLocation,
    required double hoursRemaining,
    String? truckId,
  }) = _Driver;

  factory Driver.fromJson(Map<String, dynamic> json) => _$DriverFromJson(json);
}

@freezed
class DriverLocation with _$DriverLocation {
  const factory DriverLocation({
    required double lat,
    required double lng,
    required String city,
    required String state,
  }) = _DriverLocation;

  factory DriverLocation.fromJson(Map<String, dynamic> json) =>
      _$DriverLocationFromJson(json);
}

enum DriverStatus {
  @JsonValue('available')
  available,
  @JsonValue('assigned')
  assigned,
  @JsonValue('on-route')
  onRoute,
  @JsonValue('off-duty')
  offDuty,
}
