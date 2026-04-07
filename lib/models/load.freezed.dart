// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'load.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Load _$LoadFromJson(Map<String, dynamic> json) {
  return _Load.fromJson(json);
}

/// @nodoc
mixin _$Load {
  String get id => throw _privateConstructorUsedError;
  String get loadNumber => throw _privateConstructorUsedError;
  LoadStatus get status => throw _privateConstructorUsedError;
  Location get origin => throw _privateConstructorUsedError;
  Location get destination => throw _privateConstructorUsedError;
  String get pickupDate => throw _privateConstructorUsedError;
  String get deliveryDate => throw _privateConstructorUsedError;
  Cargo get cargo => throw _privateConstructorUsedError;
  double get rate => throw _privateConstructorUsedError;
  double get distance => throw _privateConstructorUsedError;
  List<String>? get requirements => throw _privateConstructorUsedError;
  String? get assignedDriver => throw _privateConstructorUsedError;
  String? get assignedTruck => throw _privateConstructorUsedError;
  String get createdBy => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Load to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LoadCopyWith<Load> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LoadCopyWith<$Res> {
  factory $LoadCopyWith(Load value, $Res Function(Load) then) =
      _$LoadCopyWithImpl<$Res, Load>;
  @useResult
  $Res call({
    String id,
    String loadNumber,
    LoadStatus status,
    Location origin,
    Location destination,
    String pickupDate,
    String deliveryDate,
    Cargo cargo,
    double rate,
    double distance,
    List<String>? requirements,
    String? assignedDriver,
    String? assignedTruck,
    String createdBy,
    String createdAt,
  });

  $LocationCopyWith<$Res> get origin;
  $LocationCopyWith<$Res> get destination;
  $CargoCopyWith<$Res> get cargo;
}

/// @nodoc
class _$LoadCopyWithImpl<$Res, $Val extends Load>
    implements $LoadCopyWith<$Res> {
  _$LoadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? loadNumber = null,
    Object? status = null,
    Object? origin = null,
    Object? destination = null,
    Object? pickupDate = null,
    Object? deliveryDate = null,
    Object? cargo = null,
    Object? rate = null,
    Object? distance = null,
    Object? requirements = freezed,
    Object? assignedDriver = freezed,
    Object? assignedTruck = freezed,
    Object? createdBy = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            loadNumber: null == loadNumber
                ? _value.loadNumber
                : loadNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as LoadStatus,
            origin: null == origin
                ? _value.origin
                : origin // ignore: cast_nullable_to_non_nullable
                      as Location,
            destination: null == destination
                ? _value.destination
                : destination // ignore: cast_nullable_to_non_nullable
                      as Location,
            pickupDate: null == pickupDate
                ? _value.pickupDate
                : pickupDate // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveryDate: null == deliveryDate
                ? _value.deliveryDate
                : deliveryDate // ignore: cast_nullable_to_non_nullable
                      as String,
            cargo: null == cargo
                ? _value.cargo
                : cargo // ignore: cast_nullable_to_non_nullable
                      as Cargo,
            rate: null == rate
                ? _value.rate
                : rate // ignore: cast_nullable_to_non_nullable
                      as double,
            distance: null == distance
                ? _value.distance
                : distance // ignore: cast_nullable_to_non_nullable
                      as double,
            requirements: freezed == requirements
                ? _value.requirements
                : requirements // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            assignedDriver: freezed == assignedDriver
                ? _value.assignedDriver
                : assignedDriver // ignore: cast_nullable_to_non_nullable
                      as String?,
            assignedTruck: freezed == assignedTruck
                ? _value.assignedTruck
                : assignedTruck // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdBy: null == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationCopyWith<$Res> get origin {
    return $LocationCopyWith<$Res>(_value.origin, (value) {
      return _then(_value.copyWith(origin: value) as $Val);
    });
  }

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationCopyWith<$Res> get destination {
    return $LocationCopyWith<$Res>(_value.destination, (value) {
      return _then(_value.copyWith(destination: value) as $Val);
    });
  }

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CargoCopyWith<$Res> get cargo {
    return $CargoCopyWith<$Res>(_value.cargo, (value) {
      return _then(_value.copyWith(cargo: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LoadImplCopyWith<$Res> implements $LoadCopyWith<$Res> {
  factory _$$LoadImplCopyWith(
    _$LoadImpl value,
    $Res Function(_$LoadImpl) then,
  ) = __$$LoadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String loadNumber,
    LoadStatus status,
    Location origin,
    Location destination,
    String pickupDate,
    String deliveryDate,
    Cargo cargo,
    double rate,
    double distance,
    List<String>? requirements,
    String? assignedDriver,
    String? assignedTruck,
    String createdBy,
    String createdAt,
  });

  @override
  $LocationCopyWith<$Res> get origin;
  @override
  $LocationCopyWith<$Res> get destination;
  @override
  $CargoCopyWith<$Res> get cargo;
}

/// @nodoc
class __$$LoadImplCopyWithImpl<$Res>
    extends _$LoadCopyWithImpl<$Res, _$LoadImpl>
    implements _$$LoadImplCopyWith<$Res> {
  __$$LoadImplCopyWithImpl(_$LoadImpl _value, $Res Function(_$LoadImpl) _then)
    : super(_value, _then);

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? loadNumber = null,
    Object? status = null,
    Object? origin = null,
    Object? destination = null,
    Object? pickupDate = null,
    Object? deliveryDate = null,
    Object? cargo = null,
    Object? rate = null,
    Object? distance = null,
    Object? requirements = freezed,
    Object? assignedDriver = freezed,
    Object? assignedTruck = freezed,
    Object? createdBy = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$LoadImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        loadNumber: null == loadNumber
            ? _value.loadNumber
            : loadNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as LoadStatus,
        origin: null == origin
            ? _value.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as Location,
        destination: null == destination
            ? _value.destination
            : destination // ignore: cast_nullable_to_non_nullable
                  as Location,
        pickupDate: null == pickupDate
            ? _value.pickupDate
            : pickupDate // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveryDate: null == deliveryDate
            ? _value.deliveryDate
            : deliveryDate // ignore: cast_nullable_to_non_nullable
                  as String,
        cargo: null == cargo
            ? _value.cargo
            : cargo // ignore: cast_nullable_to_non_nullable
                  as Cargo,
        rate: null == rate
            ? _value.rate
            : rate // ignore: cast_nullable_to_non_nullable
                  as double,
        distance: null == distance
            ? _value.distance
            : distance // ignore: cast_nullable_to_non_nullable
                  as double,
        requirements: freezed == requirements
            ? _value._requirements
            : requirements // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        assignedDriver: freezed == assignedDriver
            ? _value.assignedDriver
            : assignedDriver // ignore: cast_nullable_to_non_nullable
                  as String?,
        assignedTruck: freezed == assignedTruck
            ? _value.assignedTruck
            : assignedTruck // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdBy: null == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LoadImpl implements _Load {
  const _$LoadImpl({
    required this.id,
    required this.loadNumber,
    required this.status,
    required this.origin,
    required this.destination,
    required this.pickupDate,
    required this.deliveryDate,
    required this.cargo,
    required this.rate,
    required this.distance,
    final List<String>? requirements,
    this.assignedDriver,
    this.assignedTruck,
    required this.createdBy,
    required this.createdAt,
  }) : _requirements = requirements;

  factory _$LoadImpl.fromJson(Map<String, dynamic> json) =>
      _$$LoadImplFromJson(json);

  @override
  final String id;
  @override
  final String loadNumber;
  @override
  final LoadStatus status;
  @override
  final Location origin;
  @override
  final Location destination;
  @override
  final String pickupDate;
  @override
  final String deliveryDate;
  @override
  final Cargo cargo;
  @override
  final double rate;
  @override
  final double distance;
  final List<String>? _requirements;
  @override
  List<String>? get requirements {
    final value = _requirements;
    if (value == null) return null;
    if (_requirements is EqualUnmodifiableListView) return _requirements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? assignedDriver;
  @override
  final String? assignedTruck;
  @override
  final String createdBy;
  @override
  final String createdAt;

  @override
  String toString() {
    return 'Load(id: $id, loadNumber: $loadNumber, status: $status, origin: $origin, destination: $destination, pickupDate: $pickupDate, deliveryDate: $deliveryDate, cargo: $cargo, rate: $rate, distance: $distance, requirements: $requirements, assignedDriver: $assignedDriver, assignedTruck: $assignedTruck, createdBy: $createdBy, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoadImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.loadNumber, loadNumber) ||
                other.loadNumber == loadNumber) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.pickupDate, pickupDate) ||
                other.pickupDate == pickupDate) &&
            (identical(other.deliveryDate, deliveryDate) ||
                other.deliveryDate == deliveryDate) &&
            (identical(other.cargo, cargo) || other.cargo == cargo) &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            const DeepCollectionEquality().equals(
              other._requirements,
              _requirements,
            ) &&
            (identical(other.assignedDriver, assignedDriver) ||
                other.assignedDriver == assignedDriver) &&
            (identical(other.assignedTruck, assignedTruck) ||
                other.assignedTruck == assignedTruck) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    loadNumber,
    status,
    origin,
    destination,
    pickupDate,
    deliveryDate,
    cargo,
    rate,
    distance,
    const DeepCollectionEquality().hash(_requirements),
    assignedDriver,
    assignedTruck,
    createdBy,
    createdAt,
  );

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LoadImplCopyWith<_$LoadImpl> get copyWith =>
      __$$LoadImplCopyWithImpl<_$LoadImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LoadImplToJson(this);
  }
}

abstract class _Load implements Load {
  const factory _Load({
    required final String id,
    required final String loadNumber,
    required final LoadStatus status,
    required final Location origin,
    required final Location destination,
    required final String pickupDate,
    required final String deliveryDate,
    required final Cargo cargo,
    required final double rate,
    required final double distance,
    final List<String>? requirements,
    final String? assignedDriver,
    final String? assignedTruck,
    required final String createdBy,
    required final String createdAt,
  }) = _$LoadImpl;

  factory _Load.fromJson(Map<String, dynamic> json) = _$LoadImpl.fromJson;

  @override
  String get id;
  @override
  String get loadNumber;
  @override
  LoadStatus get status;
  @override
  Location get origin;
  @override
  Location get destination;
  @override
  String get pickupDate;
  @override
  String get deliveryDate;
  @override
  Cargo get cargo;
  @override
  double get rate;
  @override
  double get distance;
  @override
  List<String>? get requirements;
  @override
  String? get assignedDriver;
  @override
  String? get assignedTruck;
  @override
  String get createdBy;
  @override
  String get createdAt;

  /// Create a copy of Load
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LoadImplCopyWith<_$LoadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Location _$LocationFromJson(Map<String, dynamic> json) {
  return _Location.fromJson(json);
}

/// @nodoc
mixin _$Location {
  String get address => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  String get zipCode => throw _privateConstructorUsedError;
  double? get lat => throw _privateConstructorUsedError;
  double? get lng => throw _privateConstructorUsedError;
  String? get contactName => throw _privateConstructorUsedError;
  String? get contactPhone => throw _privateConstructorUsedError;
  String? get specialInstructions => throw _privateConstructorUsedError;

  /// Serializes this Location to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LocationCopyWith<Location> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationCopyWith<$Res> {
  factory $LocationCopyWith(Location value, $Res Function(Location) then) =
      _$LocationCopyWithImpl<$Res, Location>;
  @useResult
  $Res call({
    String address,
    String city,
    String state,
    String zipCode,
    double? lat,
    double? lng,
    String? contactName,
    String? contactPhone,
    String? specialInstructions,
  });
}

/// @nodoc
class _$LocationCopyWithImpl<$Res, $Val extends Location>
    implements $LocationCopyWith<$Res> {
  _$LocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? city = null,
    Object? state = null,
    Object? zipCode = null,
    Object? lat = freezed,
    Object? lng = freezed,
    Object? contactName = freezed,
    Object? contactPhone = freezed,
    Object? specialInstructions = freezed,
  }) {
    return _then(
      _value.copyWith(
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as String,
            zipCode: null == zipCode
                ? _value.zipCode
                : zipCode // ignore: cast_nullable_to_non_nullable
                      as String,
            lat: freezed == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double?,
            lng: freezed == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double?,
            contactName: freezed == contactName
                ? _value.contactName
                : contactName // ignore: cast_nullable_to_non_nullable
                      as String?,
            contactPhone: freezed == contactPhone
                ? _value.contactPhone
                : contactPhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            specialInstructions: freezed == specialInstructions
                ? _value.specialInstructions
                : specialInstructions // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LocationImplCopyWith<$Res>
    implements $LocationCopyWith<$Res> {
  factory _$$LocationImplCopyWith(
    _$LocationImpl value,
    $Res Function(_$LocationImpl) then,
  ) = __$$LocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String address,
    String city,
    String state,
    String zipCode,
    double? lat,
    double? lng,
    String? contactName,
    String? contactPhone,
    String? specialInstructions,
  });
}

/// @nodoc
class __$$LocationImplCopyWithImpl<$Res>
    extends _$LocationCopyWithImpl<$Res, _$LocationImpl>
    implements _$$LocationImplCopyWith<$Res> {
  __$$LocationImplCopyWithImpl(
    _$LocationImpl _value,
    $Res Function(_$LocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? city = null,
    Object? state = null,
    Object? zipCode = null,
    Object? lat = freezed,
    Object? lng = freezed,
    Object? contactName = freezed,
    Object? contactPhone = freezed,
    Object? specialInstructions = freezed,
  }) {
    return _then(
      _$LocationImpl(
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as String,
        zipCode: null == zipCode
            ? _value.zipCode
            : zipCode // ignore: cast_nullable_to_non_nullable
                  as String,
        lat: freezed == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double?,
        lng: freezed == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double?,
        contactName: freezed == contactName
            ? _value.contactName
            : contactName // ignore: cast_nullable_to_non_nullable
                  as String?,
        contactPhone: freezed == contactPhone
            ? _value.contactPhone
            : contactPhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        specialInstructions: freezed == specialInstructions
            ? _value.specialInstructions
            : specialInstructions // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LocationImpl implements _Location {
  const _$LocationImpl({
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    this.lat,
    this.lng,
    this.contactName,
    this.contactPhone,
    this.specialInstructions,
  });

  factory _$LocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$LocationImplFromJson(json);

  @override
  final String address;
  @override
  final String city;
  @override
  final String state;
  @override
  final String zipCode;
  @override
  final double? lat;
  @override
  final double? lng;
  @override
  final String? contactName;
  @override
  final String? contactPhone;
  @override
  final String? specialInstructions;

  @override
  String toString() {
    return 'Location(address: $address, city: $city, state: $state, zipCode: $zipCode, lat: $lat, lng: $lng, contactName: $contactName, contactPhone: $contactPhone, specialInstructions: $specialInstructions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationImpl &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.zipCode, zipCode) || other.zipCode == zipCode) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.contactName, contactName) ||
                other.contactName == contactName) &&
            (identical(other.contactPhone, contactPhone) ||
                other.contactPhone == contactPhone) &&
            (identical(other.specialInstructions, specialInstructions) ||
                other.specialInstructions == specialInstructions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    address,
    city,
    state,
    zipCode,
    lat,
    lng,
    contactName,
    contactPhone,
    specialInstructions,
  );

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationImplCopyWith<_$LocationImpl> get copyWith =>
      __$$LocationImplCopyWithImpl<_$LocationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LocationImplToJson(this);
  }
}

abstract class _Location implements Location {
  const factory _Location({
    required final String address,
    required final String city,
    required final String state,
    required final String zipCode,
    final double? lat,
    final double? lng,
    final String? contactName,
    final String? contactPhone,
    final String? specialInstructions,
  }) = _$LocationImpl;

  factory _Location.fromJson(Map<String, dynamic> json) =
      _$LocationImpl.fromJson;

  @override
  String get address;
  @override
  String get city;
  @override
  String get state;
  @override
  String get zipCode;
  @override
  double? get lat;
  @override
  double? get lng;
  @override
  String? get contactName;
  @override
  String? get contactPhone;
  @override
  String? get specialInstructions;

  /// Create a copy of Location
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LocationImplCopyWith<_$LocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Cargo _$CargoFromJson(Map<String, dynamic> json) {
  return _Cargo.fromJson(json);
}

/// @nodoc
mixin _$Cargo {
  String get description => throw _privateConstructorUsedError;
  double get weight => throw _privateConstructorUsedError;
  int get pieces => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;

  /// Serializes this Cargo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Cargo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CargoCopyWith<Cargo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CargoCopyWith<$Res> {
  factory $CargoCopyWith(Cargo value, $Res Function(Cargo) then) =
      _$CargoCopyWithImpl<$Res, Cargo>;
  @useResult
  $Res call({String description, double weight, int pieces, String type});
}

/// @nodoc
class _$CargoCopyWithImpl<$Res, $Val extends Cargo>
    implements $CargoCopyWith<$Res> {
  _$CargoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Cargo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? description = null,
    Object? weight = null,
    Object? pieces = null,
    Object? type = null,
  }) {
    return _then(
      _value.copyWith(
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            weight: null == weight
                ? _value.weight
                : weight // ignore: cast_nullable_to_non_nullable
                      as double,
            pieces: null == pieces
                ? _value.pieces
                : pieces // ignore: cast_nullable_to_non_nullable
                      as int,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CargoImplCopyWith<$Res> implements $CargoCopyWith<$Res> {
  factory _$$CargoImplCopyWith(
    _$CargoImpl value,
    $Res Function(_$CargoImpl) then,
  ) = __$$CargoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String description, double weight, int pieces, String type});
}

/// @nodoc
class __$$CargoImplCopyWithImpl<$Res>
    extends _$CargoCopyWithImpl<$Res, _$CargoImpl>
    implements _$$CargoImplCopyWith<$Res> {
  __$$CargoImplCopyWithImpl(
    _$CargoImpl _value,
    $Res Function(_$CargoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Cargo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? description = null,
    Object? weight = null,
    Object? pieces = null,
    Object? type = null,
  }) {
    return _then(
      _$CargoImpl(
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        weight: null == weight
            ? _value.weight
            : weight // ignore: cast_nullable_to_non_nullable
                  as double,
        pieces: null == pieces
            ? _value.pieces
            : pieces // ignore: cast_nullable_to_non_nullable
                  as int,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CargoImpl implements _Cargo {
  const _$CargoImpl({
    required this.description,
    required this.weight,
    required this.pieces,
    required this.type,
  });

  factory _$CargoImpl.fromJson(Map<String, dynamic> json) =>
      _$$CargoImplFromJson(json);

  @override
  final String description;
  @override
  final double weight;
  @override
  final int pieces;
  @override
  final String type;

  @override
  String toString() {
    return 'Cargo(description: $description, weight: $weight, pieces: $pieces, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CargoImpl &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.pieces, pieces) || other.pieces == pieces) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, description, weight, pieces, type);

  /// Create a copy of Cargo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CargoImplCopyWith<_$CargoImpl> get copyWith =>
      __$$CargoImplCopyWithImpl<_$CargoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CargoImplToJson(this);
  }
}

abstract class _Cargo implements Cargo {
  const factory _Cargo({
    required final String description,
    required final double weight,
    required final int pieces,
    required final String type,
  }) = _$CargoImpl;

  factory _Cargo.fromJson(Map<String, dynamic> json) = _$CargoImpl.fromJson;

  @override
  String get description;
  @override
  double get weight;
  @override
  int get pieces;
  @override
  String get type;

  /// Create a copy of Cargo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CargoImplCopyWith<_$CargoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
