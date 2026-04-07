// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DriverImpl _$$DriverImplFromJson(Map<String, dynamic> json) => _$DriverImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  licenseNumber: json['licenseNumber'] as String,
  phone: json['phone'] as String,
  email: json['email'] as String,
  status: $enumDecode(_$DriverStatusEnumMap, json['status']),
  currentLocation: json['currentLocation'] == null
      ? null
      : DriverLocation.fromJson(
          json['currentLocation'] as Map<String, dynamic>,
        ),
  hoursRemaining: (json['hoursRemaining'] as num).toDouble(),
  truckId: json['truckId'] as String?,
);

Map<String, dynamic> _$$DriverImplToJson(_$DriverImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'licenseNumber': instance.licenseNumber,
      'phone': instance.phone,
      'email': instance.email,
      'status': _$DriverStatusEnumMap[instance.status]!,
      'currentLocation': instance.currentLocation,
      'hoursRemaining': instance.hoursRemaining,
      'truckId': instance.truckId,
    };

const _$DriverStatusEnumMap = {
  DriverStatus.available: 'available',
  DriverStatus.assigned: 'assigned',
  DriverStatus.onRoute: 'on-route',
  DriverStatus.offDuty: 'off-duty',
};

_$DriverLocationImpl _$$DriverLocationImplFromJson(Map<String, dynamic> json) =>
    _$DriverLocationImpl(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      city: json['city'] as String,
      state: json['state'] as String,
    );

Map<String, dynamic> _$$DriverLocationImplToJson(
  _$DriverLocationImpl instance,
) => <String, dynamic>{
  'lat': instance.lat,
  'lng': instance.lng,
  'city': instance.city,
  'state': instance.state,
};
