// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pod.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

POD _$PODFromJson(Map<String, dynamic> json) {
  return _POD.fromJson(json);
}

/// @nodoc
mixin _$POD {
  String get id => throw _privateConstructorUsedError;
  String get loadId => throw _privateConstructorUsedError;
  String get loadNumber => throw _privateConstructorUsedError;
  String get deliveryDate => throw _privateConstructorUsedError;
  String get deliveryTime => throw _privateConstructorUsedError;
  String get recipientName => throw _privateConstructorUsedError;
  String? get recipientTitle => throw _privateConstructorUsedError;
  String get signature => throw _privateConstructorUsedError;
  List<Photo> get photos => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  PODLocation get location => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;
  String get driverId => throw _privateConstructorUsedError;
  String get driverName => throw _privateConstructorUsedError;

  /// Serializes this POD to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of POD
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PODCopyWith<POD> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PODCopyWith<$Res> {
  factory $PODCopyWith(POD value, $Res Function(POD) then) =
      _$PODCopyWithImpl<$Res, POD>;
  @useResult
  $Res call({
    String id,
    String loadId,
    String loadNumber,
    String deliveryDate,
    String deliveryTime,
    String recipientName,
    String? recipientTitle,
    String signature,
    List<Photo> photos,
    String? notes,
    PODLocation location,
    String createdAt,
    String driverId,
    String driverName,
  });

  $PODLocationCopyWith<$Res> get location;
}

/// @nodoc
class _$PODCopyWithImpl<$Res, $Val extends POD> implements $PODCopyWith<$Res> {
  _$PODCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of POD
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? loadId = null,
    Object? loadNumber = null,
    Object? deliveryDate = null,
    Object? deliveryTime = null,
    Object? recipientName = null,
    Object? recipientTitle = freezed,
    Object? signature = null,
    Object? photos = null,
    Object? notes = freezed,
    Object? location = null,
    Object? createdAt = null,
    Object? driverId = null,
    Object? driverName = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            loadId: null == loadId
                ? _value.loadId
                : loadId // ignore: cast_nullable_to_non_nullable
                      as String,
            loadNumber: null == loadNumber
                ? _value.loadNumber
                : loadNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveryDate: null == deliveryDate
                ? _value.deliveryDate
                : deliveryDate // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveryTime: null == deliveryTime
                ? _value.deliveryTime
                : deliveryTime // ignore: cast_nullable_to_non_nullable
                      as String,
            recipientName: null == recipientName
                ? _value.recipientName
                : recipientName // ignore: cast_nullable_to_non_nullable
                      as String,
            recipientTitle: freezed == recipientTitle
                ? _value.recipientTitle
                : recipientTitle // ignore: cast_nullable_to_non_nullable
                      as String?,
            signature: null == signature
                ? _value.signature
                : signature // ignore: cast_nullable_to_non_nullable
                      as String,
            photos: null == photos
                ? _value.photos
                : photos // ignore: cast_nullable_to_non_nullable
                      as List<Photo>,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            location: null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as PODLocation,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            driverId: null == driverId
                ? _value.driverId
                : driverId // ignore: cast_nullable_to_non_nullable
                      as String,
            driverName: null == driverName
                ? _value.driverName
                : driverName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of POD
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PODLocationCopyWith<$Res> get location {
    return $PODLocationCopyWith<$Res>(_value.location, (value) {
      return _then(_value.copyWith(location: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PODImplCopyWith<$Res> implements $PODCopyWith<$Res> {
  factory _$$PODImplCopyWith(_$PODImpl value, $Res Function(_$PODImpl) then) =
      __$$PODImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String loadId,
    String loadNumber,
    String deliveryDate,
    String deliveryTime,
    String recipientName,
    String? recipientTitle,
    String signature,
    List<Photo> photos,
    String? notes,
    PODLocation location,
    String createdAt,
    String driverId,
    String driverName,
  });

  @override
  $PODLocationCopyWith<$Res> get location;
}

/// @nodoc
class __$$PODImplCopyWithImpl<$Res> extends _$PODCopyWithImpl<$Res, _$PODImpl>
    implements _$$PODImplCopyWith<$Res> {
  __$$PODImplCopyWithImpl(_$PODImpl _value, $Res Function(_$PODImpl) _then)
    : super(_value, _then);

  /// Create a copy of POD
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? loadId = null,
    Object? loadNumber = null,
    Object? deliveryDate = null,
    Object? deliveryTime = null,
    Object? recipientName = null,
    Object? recipientTitle = freezed,
    Object? signature = null,
    Object? photos = null,
    Object? notes = freezed,
    Object? location = null,
    Object? createdAt = null,
    Object? driverId = null,
    Object? driverName = null,
  }) {
    return _then(
      _$PODImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        loadId: null == loadId
            ? _value.loadId
            : loadId // ignore: cast_nullable_to_non_nullable
                  as String,
        loadNumber: null == loadNumber
            ? _value.loadNumber
            : loadNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveryDate: null == deliveryDate
            ? _value.deliveryDate
            : deliveryDate // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveryTime: null == deliveryTime
            ? _value.deliveryTime
            : deliveryTime // ignore: cast_nullable_to_non_nullable
                  as String,
        recipientName: null == recipientName
            ? _value.recipientName
            : recipientName // ignore: cast_nullable_to_non_nullable
                  as String,
        recipientTitle: freezed == recipientTitle
            ? _value.recipientTitle
            : recipientTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        signature: null == signature
            ? _value.signature
            : signature // ignore: cast_nullable_to_non_nullable
                  as String,
        photos: null == photos
            ? _value._photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<Photo>,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        location: null == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as PODLocation,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        driverId: null == driverId
            ? _value.driverId
            : driverId // ignore: cast_nullable_to_non_nullable
                  as String,
        driverName: null == driverName
            ? _value.driverName
            : driverName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PODImpl implements _POD {
  const _$PODImpl({
    required this.id,
    required this.loadId,
    required this.loadNumber,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.recipientName,
    this.recipientTitle,
    required this.signature,
    required final List<Photo> photos,
    this.notes,
    required this.location,
    required this.createdAt,
    required this.driverId,
    required this.driverName,
  }) : _photos = photos;

  factory _$PODImpl.fromJson(Map<String, dynamic> json) =>
      _$$PODImplFromJson(json);

  @override
  final String id;
  @override
  final String loadId;
  @override
  final String loadNumber;
  @override
  final String deliveryDate;
  @override
  final String deliveryTime;
  @override
  final String recipientName;
  @override
  final String? recipientTitle;
  @override
  final String signature;
  final List<Photo> _photos;
  @override
  List<Photo> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  @override
  final String? notes;
  @override
  final PODLocation location;
  @override
  final String createdAt;
  @override
  final String driverId;
  @override
  final String driverName;

  @override
  String toString() {
    return 'POD(id: $id, loadId: $loadId, loadNumber: $loadNumber, deliveryDate: $deliveryDate, deliveryTime: $deliveryTime, recipientName: $recipientName, recipientTitle: $recipientTitle, signature: $signature, photos: $photos, notes: $notes, location: $location, createdAt: $createdAt, driverId: $driverId, driverName: $driverName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PODImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.loadId, loadId) || other.loadId == loadId) &&
            (identical(other.loadNumber, loadNumber) ||
                other.loadNumber == loadNumber) &&
            (identical(other.deliveryDate, deliveryDate) ||
                other.deliveryDate == deliveryDate) &&
            (identical(other.deliveryTime, deliveryTime) ||
                other.deliveryTime == deliveryTime) &&
            (identical(other.recipientName, recipientName) ||
                other.recipientName == recipientName) &&
            (identical(other.recipientTitle, recipientTitle) ||
                other.recipientTitle == recipientTitle) &&
            (identical(other.signature, signature) ||
                other.signature == signature) &&
            const DeepCollectionEquality().equals(other._photos, _photos) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.driverName, driverName) ||
                other.driverName == driverName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    loadId,
    loadNumber,
    deliveryDate,
    deliveryTime,
    recipientName,
    recipientTitle,
    signature,
    const DeepCollectionEquality().hash(_photos),
    notes,
    location,
    createdAt,
    driverId,
    driverName,
  );

  /// Create a copy of POD
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PODImplCopyWith<_$PODImpl> get copyWith =>
      __$$PODImplCopyWithImpl<_$PODImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PODImplToJson(this);
  }
}

abstract class _POD implements POD {
  const factory _POD({
    required final String id,
    required final String loadId,
    required final String loadNumber,
    required final String deliveryDate,
    required final String deliveryTime,
    required final String recipientName,
    final String? recipientTitle,
    required final String signature,
    required final List<Photo> photos,
    final String? notes,
    required final PODLocation location,
    required final String createdAt,
    required final String driverId,
    required final String driverName,
  }) = _$PODImpl;

  factory _POD.fromJson(Map<String, dynamic> json) = _$PODImpl.fromJson;

  @override
  String get id;
  @override
  String get loadId;
  @override
  String get loadNumber;
  @override
  String get deliveryDate;
  @override
  String get deliveryTime;
  @override
  String get recipientName;
  @override
  String? get recipientTitle;
  @override
  String get signature;
  @override
  List<Photo> get photos;
  @override
  String? get notes;
  @override
  PODLocation get location;
  @override
  String get createdAt;
  @override
  String get driverId;
  @override
  String get driverName;

  /// Create a copy of POD
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PODImplCopyWith<_$PODImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Photo _$PhotoFromJson(Map<String, dynamic> json) {
  return _Photo.fromJson(json);
}

/// @nodoc
mixin _$Photo {
  String get id => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  String? get caption => throw _privateConstructorUsedError;
  String get timestamp => throw _privateConstructorUsedError;

  /// Serializes this Photo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Photo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PhotoCopyWith<Photo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoCopyWith<$Res> {
  factory $PhotoCopyWith(Photo value, $Res Function(Photo) then) =
      _$PhotoCopyWithImpl<$Res, Photo>;
  @useResult
  $Res call({String id, String url, String? caption, String timestamp});
}

/// @nodoc
class _$PhotoCopyWithImpl<$Res, $Val extends Photo>
    implements $PhotoCopyWith<$Res> {
  _$PhotoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Photo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? caption = freezed,
    Object? timestamp = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            caption: freezed == caption
                ? _value.caption
                : caption // ignore: cast_nullable_to_non_nullable
                      as String?,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PhotoImplCopyWith<$Res> implements $PhotoCopyWith<$Res> {
  factory _$$PhotoImplCopyWith(
    _$PhotoImpl value,
    $Res Function(_$PhotoImpl) then,
  ) = __$$PhotoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String url, String? caption, String timestamp});
}

/// @nodoc
class __$$PhotoImplCopyWithImpl<$Res>
    extends _$PhotoCopyWithImpl<$Res, _$PhotoImpl>
    implements _$$PhotoImplCopyWith<$Res> {
  __$$PhotoImplCopyWithImpl(
    _$PhotoImpl _value,
    $Res Function(_$PhotoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Photo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? url = null,
    Object? caption = freezed,
    Object? timestamp = null,
  }) {
    return _then(
      _$PhotoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        caption: freezed == caption
            ? _value.caption
            : caption // ignore: cast_nullable_to_non_nullable
                  as String?,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PhotoImpl implements _Photo {
  const _$PhotoImpl({
    required this.id,
    required this.url,
    this.caption,
    required this.timestamp,
  });

  factory _$PhotoImpl.fromJson(Map<String, dynamic> json) =>
      _$$PhotoImplFromJson(json);

  @override
  final String id;
  @override
  final String url;
  @override
  final String? caption;
  @override
  final String timestamp;

  @override
  String toString() {
    return 'Photo(id: $id, url: $url, caption: $caption, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, url, caption, timestamp);

  /// Create a copy of Photo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoImplCopyWith<_$PhotoImpl> get copyWith =>
      __$$PhotoImplCopyWithImpl<_$PhotoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PhotoImplToJson(this);
  }
}

abstract class _Photo implements Photo {
  const factory _Photo({
    required final String id,
    required final String url,
    final String? caption,
    required final String timestamp,
  }) = _$PhotoImpl;

  factory _Photo.fromJson(Map<String, dynamic> json) = _$PhotoImpl.fromJson;

  @override
  String get id;
  @override
  String get url;
  @override
  String? get caption;
  @override
  String get timestamp;

  /// Create a copy of Photo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhotoImplCopyWith<_$PhotoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PODLocation _$PODLocationFromJson(Map<String, dynamic> json) {
  return _PODLocation.fromJson(json);
}

/// @nodoc
mixin _$PODLocation {
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;

  /// Serializes this PODLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PODLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PODLocationCopyWith<PODLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PODLocationCopyWith<$Res> {
  factory $PODLocationCopyWith(
    PODLocation value,
    $Res Function(PODLocation) then,
  ) = _$PODLocationCopyWithImpl<$Res, PODLocation>;
  @useResult
  $Res call({double lat, double lng, String address});
}

/// @nodoc
class _$PODLocationCopyWithImpl<$Res, $Val extends PODLocation>
    implements $PODLocationCopyWith<$Res> {
  _$PODLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PODLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? lat = null, Object? lng = null, Object? address = null}) {
    return _then(
      _value.copyWith(
            lat: null == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double,
            lng: null == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double,
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PODLocationImplCopyWith<$Res>
    implements $PODLocationCopyWith<$Res> {
  factory _$$PODLocationImplCopyWith(
    _$PODLocationImpl value,
    $Res Function(_$PODLocationImpl) then,
  ) = __$$PODLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double lat, double lng, String address});
}

/// @nodoc
class __$$PODLocationImplCopyWithImpl<$Res>
    extends _$PODLocationCopyWithImpl<$Res, _$PODLocationImpl>
    implements _$$PODLocationImplCopyWith<$Res> {
  __$$PODLocationImplCopyWithImpl(
    _$PODLocationImpl _value,
    $Res Function(_$PODLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PODLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? lat = null, Object? lng = null, Object? address = null}) {
    return _then(
      _$PODLocationImpl(
        lat: null == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double,
        lng: null == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PODLocationImpl implements _PODLocation {
  const _$PODLocationImpl({
    required this.lat,
    required this.lng,
    required this.address,
  });

  factory _$PODLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$PODLocationImplFromJson(json);

  @override
  final double lat;
  @override
  final double lng;
  @override
  final String address;

  @override
  String toString() {
    return 'PODLocation(lat: $lat, lng: $lng, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PODLocationImpl &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.address, address) || other.address == address));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, lat, lng, address);

  /// Create a copy of PODLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PODLocationImplCopyWith<_$PODLocationImpl> get copyWith =>
      __$$PODLocationImplCopyWithImpl<_$PODLocationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PODLocationImplToJson(this);
  }
}

abstract class _PODLocation implements PODLocation {
  const factory _PODLocation({
    required final double lat,
    required final double lng,
    required final String address,
  }) = _$PODLocationImpl;

  factory _PODLocation.fromJson(Map<String, dynamic> json) =
      _$PODLocationImpl.fromJson;

  @override
  double get lat;
  @override
  double get lng;
  @override
  String get address;

  /// Create a copy of PODLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PODLocationImplCopyWith<_$PODLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
