import 'package:freezed_annotation/freezed_annotation.dart';

part 'pod.freezed.dart';
part 'pod.g.dart';

@freezed
class POD with _$POD {
  const factory POD({
    required String id,
    required String loadId,
    required String loadNumber,
    required String deliveryDate,
    required String deliveryTime,
    required String recipientName,
    String? recipientTitle,
    required String signature,
    required List<Photo> photos,
    String? notes,
    required PODLocation location,
    required String createdAt,
    required String driverId,
    required String driverName,
  }) = _POD;

  factory POD.fromJson(Map<String, dynamic> json) => _$PODFromJson(json);
}

@freezed
class Photo with _$Photo {
  const factory Photo({
    required String id,
    required String url,
    String? caption,
    required String timestamp,
  }) = _Photo;

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);
}

@freezed
class PODLocation with _$PODLocation {
  const factory PODLocation({
    required double lat,
    required double lng,
    required String address,
  }) = _PODLocation;

  factory PODLocation.fromJson(Map<String, dynamic> json) =>
      _$PODLocationFromJson(json);
}
