// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Driver _$DriverFromJson(Map<String, dynamic> json) {
  return _Driver.fromJson(json);
}

/// @nodoc
mixin _$Driver {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get licenseNumber => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  DriverStatus get status => throw _privateConstructorUsedError;
  DriverLocation? get currentLocation => throw _privateConstructorUsedError;
  double get hoursRemaining => throw _privateConstructorUsedError;
  String? get truckId => throw _privateConstructorUsedError;

  /// Serializes this Driver to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Driver
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DriverCopyWith<Driver> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DriverCopyWith<$Res> {
  factory $DriverCopyWith(Driver value, $Res Function(Driver) then) =
      _$DriverCopyWithImpl<$Res, Driver>;
  @useResult
  $Res call({
    String id,
    String name,
    String licenseNumber,
    String phone,
    String email,
    DriverStatus status,
    DriverLocation? currentLocation,
    double hoursRemaining,
    String? truckId,
  });

  $DriverLocationCopyWith<$Res>? get currentLocation;
}

/// @nodoc
class _$DriverCopyWithImpl<$Res, $Val extends Driver>
    implements $DriverCopyWith<$Res> {
  _$DriverCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Driver
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? licenseNumber = null,
    Object? phone = null,
    Object? email = null,
    Object? status = null,
    Object? currentLocation = freezed,
    Object? hoursRemaining = null,
    Object? truckId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            licenseNumber: null == licenseNumber
                ? _value.licenseNumber
                : licenseNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            phone: null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as DriverStatus,
            currentLocation: freezed == currentLocation
                ? _value.currentLocation
                : currentLocation // ignore: cast_nullable_to_non_nullable
                      as DriverLocation?,
            hoursRemaining: null == hoursRemaining
                ? _value.hoursRemaining
                : hoursRemaining // ignore: cast_nullable_to_non_nullable
                      as double,
            truckId: freezed == truckId
                ? _value.truckId
                : truckId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of Driver
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DriverLocationCopyWith<$Res>? get currentLocation {
    if (_value.currentLocation == null) {
      return null;
    }

    return $DriverLocationCopyWith<$Res>(_value.currentLocation!, (value) {
      return _then(_value.copyWith(currentLocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DriverImplCopyWith<$Res> implements $DriverCopyWith<$Res> {
  factory _$$DriverImplCopyWith(
    _$DriverImpl value,
    $Res Function(_$DriverImpl) then,
  ) = __$$DriverImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String licenseNumber,
    String phone,
    String email,
    DriverStatus status,
    DriverLocation? currentLocation,
    double hoursRemaining,
    String? truckId,
  });

  @override
  $DriverLocationCopyWith<$Res>? get currentLocation;
}

/// @nodoc
class __$$DriverImplCopyWithImpl<$Res>
    extends _$DriverCopyWithImpl<$Res, _$DriverImpl>
    implements _$$DriverImplCopyWith<$Res> {
  __$$DriverImplCopyWithImpl(
    _$DriverImpl _value,
    $Res Function(_$DriverImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Driver
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? licenseNumber = null,
    Object? phone = null,
    Object? email = null,
    Object? status = null,
    Object? currentLocation = freezed,
    Object? hoursRemaining = null,
    Object? truckId = freezed,
  }) {
    return _then(
      _$DriverImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        licenseNumber: null == licenseNumber
            ? _value.licenseNumber
            : licenseNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        phone: null == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as DriverStatus,
        currentLocation: freezed == currentLocation
            ? _value.currentLocation
            : currentLocation // ignore: cast_nullable_to_non_nullable
                  as DriverLocation?,
        hoursRemaining: null == hoursRemaining
            ? _value.hoursRemaining
            : hoursRemaining // ignore: cast_nullable_to_non_nullable
                  as double,
        truckId: freezed == truckId
            ? _value.truckId
            : truckId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DriverImpl implements _Driver {
  const _$DriverImpl({
    required this.id,
    required this.name,
    required this.licenseNumber,
    required this.phone,
    required this.email,
    required this.status,
    this.currentLocation,
    required this.hoursRemaining,
    this.truckId,
  });

  factory _$DriverImpl.fromJson(Map<String, dynamic> json) =>
      _$$DriverImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String licenseNumber;
  @override
  final String phone;
  @override
  final String email;
  @override
  final DriverStatus status;
  @override
  final DriverLocation? currentLocation;
  @override
  final double hoursRemaining;
  @override
  final String? truckId;

  @override
  String toString() {
    return 'Driver(id: $id, name: $name, licenseNumber: $licenseNumber, phone: $phone, email: $email, status: $status, currentLocation: $currentLocation, hoursRemaining: $hoursRemaining, truckId: $truckId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DriverImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.licenseNumber, licenseNumber) ||
                other.licenseNumber == licenseNumber) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentLocation, currentLocation) ||
                other.currentLocation == currentLocation) &&
            (identical(other.hoursRemaining, hoursRemaining) ||
                other.hoursRemaining == hoursRemaining) &&
            (identical(other.truckId, truckId) || other.truckId == truckId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    licenseNumber,
    phone,
    email,
    status,
    currentLocation,
    hoursRemaining,
    truckId,
  );

  /// Create a copy of Driver
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DriverImplCopyWith<_$DriverImpl> get copyWith =>
      __$$DriverImplCopyWithImpl<_$DriverImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DriverImplToJson(this);
  }
}

abstract class _Driver implements Driver {
  const factory _Driver({
    required final String id,
    required final String name,
    required final String licenseNumber,
    required final String phone,
    required final String email,
    required final DriverStatus status,
    final DriverLocation? currentLocation,
    required final double hoursRemaining,
    final String? truckId,
  }) = _$DriverImpl;

  factory _Driver.fromJson(Map<String, dynamic> json) = _$DriverImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get licenseNumber;
  @override
  String get phone;
  @override
  String get email;
  @override
  DriverStatus get status;
  @override
  DriverLocation? get currentLocation;
  @override
  double get hoursRemaining;
  @override
  String? get truckId;

  /// Create a copy of Driver
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DriverImplCopyWith<_$DriverImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DriverLocation _$DriverLocationFromJson(Map<String, dynamic> json) {
  return _DriverLocation.fromJson(json);
}

/// @nodoc
mixin _$DriverLocation {
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;

  /// Serializes this DriverLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DriverLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DriverLocationCopyWith<DriverLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DriverLocationCopyWith<$Res> {
  factory $DriverLocationCopyWith(
    DriverLocation value,
    $Res Function(DriverLocation) then,
  ) = _$DriverLocationCopyWithImpl<$Res, DriverLocation>;
  @useResult
  $Res call({double lat, double lng, String city, String state});
}

/// @nodoc
class _$DriverLocationCopyWithImpl<$Res, $Val extends DriverLocation>
    implements $DriverLocationCopyWith<$Res> {
  _$DriverLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DriverLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lat = null,
    Object? lng = null,
    Object? city = null,
    Object? state = null,
  }) {
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
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DriverLocationImplCopyWith<$Res>
    implements $DriverLocationCopyWith<$Res> {
  factory _$$DriverLocationImplCopyWith(
    _$DriverLocationImpl value,
    $Res Function(_$DriverLocationImpl) then,
  ) = __$$DriverLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double lat, double lng, String city, String state});
}

/// @nodoc
class __$$DriverLocationImplCopyWithImpl<$Res>
    extends _$DriverLocationCopyWithImpl<$Res, _$DriverLocationImpl>
    implements _$$DriverLocationImplCopyWith<$Res> {
  __$$DriverLocationImplCopyWithImpl(
    _$DriverLocationImpl _value,
    $Res Function(_$DriverLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DriverLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lat = null,
    Object? lng = null,
    Object? city = null,
    Object? state = null,
  }) {
    return _then(
      _$DriverLocationImpl(
        lat: null == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double,
        lng: null == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DriverLocationImpl implements _DriverLocation {
  const _$DriverLocationImpl({
    required this.lat,
    required this.lng,
    required this.city,
    required this.state,
  });

  factory _$DriverLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$DriverLocationImplFromJson(json);

  @override
  final double lat;
  @override
  final double lng;
  @override
  final String city;
  @override
  final String state;

  @override
  String toString() {
    return 'DriverLocation(lat: $lat, lng: $lng, city: $city, state: $state)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DriverLocationImpl &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, lat, lng, city, state);

  /// Create a copy of DriverLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DriverLocationImplCopyWith<_$DriverLocationImpl> get copyWith =>
      __$$DriverLocationImplCopyWithImpl<_$DriverLocationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DriverLocationImplToJson(this);
  }
}

abstract class _DriverLocation implements DriverLocation {
  const factory _DriverLocation({
    required final double lat,
    required final double lng,
    required final String city,
    required final String state,
  }) = _$DriverLocationImpl;

  factory _DriverLocation.fromJson(Map<String, dynamic> json) =
      _$DriverLocationImpl.fromJson;

  @override
  double get lat;
  @override
  double get lng;
  @override
  String get city;
  @override
  String get state;

  /// Create a copy of DriverLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DriverLocationImplCopyWith<_$DriverLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
