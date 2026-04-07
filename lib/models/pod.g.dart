// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pod.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PODImpl _$$PODImplFromJson(Map<String, dynamic> json) => _$PODImpl(
  id: json['id'] as String,
  loadId: json['loadId'] as String,
  loadNumber: json['loadNumber'] as String,
  deliveryDate: json['deliveryDate'] as String,
  deliveryTime: json['deliveryTime'] as String,
  recipientName: json['recipientName'] as String,
  recipientTitle: json['recipientTitle'] as String?,
  signature: json['signature'] as String,
  photos: (json['photos'] as List<dynamic>)
      .map((e) => Photo.fromJson(e as Map<String, dynamic>))
      .toList(),
  notes: json['notes'] as String?,
  location: PODLocation.fromJson(json['location'] as Map<String, dynamic>),
  createdAt: json['createdAt'] as String,
  driverId: json['driverId'] as String,
  driverName: json['driverName'] as String,
);

Map<String, dynamic> _$$PODImplToJson(_$PODImpl instance) => <String, dynamic>{
  'id': instance.id,
  'loadId': instance.loadId,
  'loadNumber': instance.loadNumber,
  'deliveryDate': instance.deliveryDate,
  'deliveryTime': instance.deliveryTime,
  'recipientName': instance.recipientName,
  'recipientTitle': instance.recipientTitle,
  'signature': instance.signature,
  'photos': instance.photos,
  'notes': instance.notes,
  'location': instance.location,
  'createdAt': instance.createdAt,
  'driverId': instance.driverId,
  'driverName': instance.driverName,
};

_$PhotoImpl _$$PhotoImplFromJson(Map<String, dynamic> json) => _$PhotoImpl(
  id: json['id'] as String,
  url: json['url'] as String,
  caption: json['caption'] as String?,
  timestamp: json['timestamp'] as String,
);

Map<String, dynamic> _$$PhotoImplToJson(_$PhotoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'caption': instance.caption,
      'timestamp': instance.timestamp,
    };

_$PODLocationImpl _$$PODLocationImplFromJson(Map<String, dynamic> json) =>
    _$PODLocationImpl(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String,
    );

Map<String, dynamic> _$$PODLocationImplToJson(_$PODLocationImpl instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'address': instance.address,
    };
