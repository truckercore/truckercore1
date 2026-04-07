// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Expense _$ExpenseFromJson(Map<String, dynamic> json) {
  return _Expense.fromJson(json);
}

/// @nodoc
mixin _$Expense {
  String get id => throw _privateConstructorUsedError;
  String get operatorId => throw _privateConstructorUsedError;
  String get operatorName => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  ExpenseCategory get category => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  PaymentMethod get paymentMethod => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  int? get odometer => throw _privateConstructorUsedError;
  List<Receipt> get receipts => throw _privateConstructorUsedError;
  String? get loadNumber => throw _privateConstructorUsedError;
  ExpenseStatus get status => throw _privateConstructorUsedError;
  String get submittedAt => throw _privateConstructorUsedError;
  String? get reviewedAt => throw _privateConstructorUsedError;
  String? get reviewedBy => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this Expense to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Expense
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExpenseCopyWith<Expense> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExpenseCopyWith<$Res> {
  factory $ExpenseCopyWith(Expense value, $Res Function(Expense) then) =
      _$ExpenseCopyWithImpl<$Res, Expense>;
  @useResult
  $Res call({
    String id,
    String operatorId,
    String operatorName,
    String date,
    ExpenseCategory category,
    double amount,
    String description,
    PaymentMethod paymentMethod,
    String location,
    int? odometer,
    List<Receipt> receipts,
    String? loadNumber,
    ExpenseStatus status,
    String submittedAt,
    String? reviewedAt,
    String? reviewedBy,
    String? notes,
  });
}

/// @nodoc
class _$ExpenseCopyWithImpl<$Res, $Val extends Expense>
    implements $ExpenseCopyWith<$Res> {
  _$ExpenseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Expense
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? operatorId = null,
    Object? operatorName = null,
    Object? date = null,
    Object? category = null,
    Object? amount = null,
    Object? description = null,
    Object? paymentMethod = null,
    Object? location = null,
    Object? odometer = freezed,
    Object? receipts = null,
    Object? loadNumber = freezed,
    Object? status = null,
    Object? submittedAt = null,
    Object? reviewedAt = freezed,
    Object? reviewedBy = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            operatorId: null == operatorId
                ? _value.operatorId
                : operatorId // ignore: cast_nullable_to_non_nullable
                      as String,
            operatorName: null == operatorName
                ? _value.operatorName
                : operatorName // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as ExpenseCategory,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            paymentMethod: null == paymentMethod
                ? _value.paymentMethod
                : paymentMethod // ignore: cast_nullable_to_non_nullable
                      as PaymentMethod,
            location: null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String,
            odometer: freezed == odometer
                ? _value.odometer
                : odometer // ignore: cast_nullable_to_non_nullable
                      as int?,
            receipts: null == receipts
                ? _value.receipts
                : receipts // ignore: cast_nullable_to_non_nullable
                      as List<Receipt>,
            loadNumber: freezed == loadNumber
                ? _value.loadNumber
                : loadNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ExpenseStatus,
            submittedAt: null == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as String,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedBy: freezed == reviewedBy
                ? _value.reviewedBy
                : reviewedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExpenseImplCopyWith<$Res> implements $ExpenseCopyWith<$Res> {
  factory _$$ExpenseImplCopyWith(
    _$ExpenseImpl value,
    $Res Function(_$ExpenseImpl) then,
  ) = __$$ExpenseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String operatorId,
    String operatorName,
    String date,
    ExpenseCategory category,
    double amount,
    String description,
    PaymentMethod paymentMethod,
    String location,
    int? odometer,
    List<Receipt> receipts,
    String? loadNumber,
    ExpenseStatus status,
    String submittedAt,
    String? reviewedAt,
    String? reviewedBy,
    String? notes,
  });
}

/// @nodoc
class __$$ExpenseImplCopyWithImpl<$Res>
    extends _$ExpenseCopyWithImpl<$Res, _$ExpenseImpl>
    implements _$$ExpenseImplCopyWith<$Res> {
  __$$ExpenseImplCopyWithImpl(
    _$ExpenseImpl _value,
    $Res Function(_$ExpenseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Expense
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? operatorId = null,
    Object? operatorName = null,
    Object? date = null,
    Object? category = null,
    Object? amount = null,
    Object? description = null,
    Object? paymentMethod = null,
    Object? location = null,
    Object? odometer = freezed,
    Object? receipts = null,
    Object? loadNumber = freezed,
    Object? status = null,
    Object? submittedAt = null,
    Object? reviewedAt = freezed,
    Object? reviewedBy = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$ExpenseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        operatorId: null == operatorId
            ? _value.operatorId
            : operatorId // ignore: cast_nullable_to_non_nullable
                  as String,
        operatorName: null == operatorName
            ? _value.operatorName
            : operatorName // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as ExpenseCategory,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        paymentMethod: null == paymentMethod
            ? _value.paymentMethod
            : paymentMethod // ignore: cast_nullable_to_non_nullable
                  as PaymentMethod,
        location: null == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String,
        odometer: freezed == odometer
            ? _value.odometer
            : odometer // ignore: cast_nullable_to_non_nullable
                  as int?,
        receipts: null == receipts
            ? _value._receipts
            : receipts // ignore: cast_nullable_to_non_nullable
                  as List<Receipt>,
        loadNumber: freezed == loadNumber
            ? _value.loadNumber
            : loadNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ExpenseStatus,
        submittedAt: null == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as String,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedBy: freezed == reviewedBy
            ? _value.reviewedBy
            : reviewedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExpenseImpl implements _Expense {
  const _$ExpenseImpl({
    required this.id,
    required this.operatorId,
    required this.operatorName,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    required this.paymentMethod,
    required this.location,
    this.odometer,
    required final List<Receipt> receipts,
    this.loadNumber,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.notes,
  }) : _receipts = receipts;

  factory _$ExpenseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExpenseImplFromJson(json);

  @override
  final String id;
  @override
  final String operatorId;
  @override
  final String operatorName;
  @override
  final String date;
  @override
  final ExpenseCategory category;
  @override
  final double amount;
  @override
  final String description;
  @override
  final PaymentMethod paymentMethod;
  @override
  final String location;
  @override
  final int? odometer;
  final List<Receipt> _receipts;
  @override
  List<Receipt> get receipts {
    if (_receipts is EqualUnmodifiableListView) return _receipts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_receipts);
  }

  @override
  final String? loadNumber;
  @override
  final ExpenseStatus status;
  @override
  final String submittedAt;
  @override
  final String? reviewedAt;
  @override
  final String? reviewedBy;
  @override
  final String? notes;

  @override
  String toString() {
    return 'Expense(id: $id, operatorId: $operatorId, operatorName: $operatorName, date: $date, category: $category, amount: $amount, description: $description, paymentMethod: $paymentMethod, location: $location, odometer: $odometer, receipts: $receipts, loadNumber: $loadNumber, status: $status, submittedAt: $submittedAt, reviewedAt: $reviewedAt, reviewedBy: $reviewedBy, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExpenseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.operatorId, operatorId) ||
                other.operatorId == operatorId) &&
            (identical(other.operatorName, operatorName) ||
                other.operatorName == operatorName) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.odometer, odometer) ||
                other.odometer == odometer) &&
            const DeepCollectionEquality().equals(other._receipts, _receipts) &&
            (identical(other.loadNumber, loadNumber) ||
                other.loadNumber == loadNumber) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    operatorId,
    operatorName,
    date,
    category,
    amount,
    description,
    paymentMethod,
    location,
    odometer,
    const DeepCollectionEquality().hash(_receipts),
    loadNumber,
    status,
    submittedAt,
    reviewedAt,
    reviewedBy,
    notes,
  );

  /// Create a copy of Expense
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExpenseImplCopyWith<_$ExpenseImpl> get copyWith =>
      __$$ExpenseImplCopyWithImpl<_$ExpenseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExpenseImplToJson(this);
  }
}

abstract class _Expense implements Expense {
  const factory _Expense({
    required final String id,
    required final String operatorId,
    required final String operatorName,
    required final String date,
    required final ExpenseCategory category,
    required final double amount,
    required final String description,
    required final PaymentMethod paymentMethod,
    required final String location,
    final int? odometer,
    required final List<Receipt> receipts,
    final String? loadNumber,
    required final ExpenseStatus status,
    required final String submittedAt,
    final String? reviewedAt,
    final String? reviewedBy,
    final String? notes,
  }) = _$ExpenseImpl;

  factory _Expense.fromJson(Map<String, dynamic> json) = _$ExpenseImpl.fromJson;

  @override
  String get id;
  @override
  String get operatorId;
  @override
  String get operatorName;
  @override
  String get date;
  @override
  ExpenseCategory get category;
  @override
  double get amount;
  @override
  String get description;
  @override
  PaymentMethod get paymentMethod;
  @override
  String get location;
  @override
  int? get odometer;
  @override
  List<Receipt> get receipts;
  @override
  String? get loadNumber;
  @override
  ExpenseStatus get status;
  @override
  String get submittedAt;
  @override
  String? get reviewedAt;
  @override
  String? get reviewedBy;
  @override
  String? get notes;

  /// Create a copy of Expense
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExpenseImplCopyWith<_$ExpenseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Receipt _$ReceiptFromJson(Map<String, dynamic> json) {
  return _Receipt.fromJson(json);
}

/// @nodoc
mixin _$Receipt {
  String get id => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  int get fileSize => throw _privateConstructorUsedError;
  String get fileType => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  String get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this Receipt to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Receipt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReceiptCopyWith<Receipt> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReceiptCopyWith<$Res> {
  factory $ReceiptCopyWith(Receipt value, $Res Function(Receipt) then) =
      _$ReceiptCopyWithImpl<$Res, Receipt>;
  @useResult
  $Res call({
    String id,
    String fileName,
    int fileSize,
    String fileType,
    String url,
    String uploadedAt,
  });
}

/// @nodoc
class _$ReceiptCopyWithImpl<$Res, $Val extends Receipt>
    implements $ReceiptCopyWith<$Res> {
  _$ReceiptCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Receipt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? fileSize = null,
    Object? fileType = null,
    Object? url = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            fileName: null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String,
            fileSize: null == fileSize
                ? _value.fileSize
                : fileSize // ignore: cast_nullable_to_non_nullable
                      as int,
            fileType: null == fileType
                ? _value.fileType
                : fileType // ignore: cast_nullable_to_non_nullable
                      as String,
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReceiptImplCopyWith<$Res> implements $ReceiptCopyWith<$Res> {
  factory _$$ReceiptImplCopyWith(
    _$ReceiptImpl value,
    $Res Function(_$ReceiptImpl) then,
  ) = __$$ReceiptImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String fileName,
    int fileSize,
    String fileType,
    String url,
    String uploadedAt,
  });
}

/// @nodoc
class __$$ReceiptImplCopyWithImpl<$Res>
    extends _$ReceiptCopyWithImpl<$Res, _$ReceiptImpl>
    implements _$$ReceiptImplCopyWith<$Res> {
  __$$ReceiptImplCopyWithImpl(
    _$ReceiptImpl _value,
    $Res Function(_$ReceiptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Receipt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? fileSize = null,
    Object? fileType = null,
    Object? url = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _$ReceiptImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        fileName: null == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String,
        fileSize: null == fileSize
            ? _value.fileSize
            : fileSize // ignore: cast_nullable_to_non_nullable
                  as int,
        fileType: null == fileType
            ? _value.fileType
            : fileType // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReceiptImpl implements _Receipt {
  const _$ReceiptImpl({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.url,
    required this.uploadedAt,
  });

  factory _$ReceiptImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReceiptImplFromJson(json);

  @override
  final String id;
  @override
  final String fileName;
  @override
  final int fileSize;
  @override
  final String fileType;
  @override
  final String url;
  @override
  final String uploadedAt;

  @override
  String toString() {
    return 'Receipt(id: $id, fileName: $fileName, fileSize: $fileSize, fileType: $fileType, url: $url, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReceiptImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileSize, fileSize) ||
                other.fileSize == fileSize) &&
            (identical(other.fileType, fileType) ||
                other.fileType == fileType) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    fileName,
    fileSize,
    fileType,
    url,
    uploadedAt,
  );

  /// Create a copy of Receipt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReceiptImplCopyWith<_$ReceiptImpl> get copyWith =>
      __$$ReceiptImplCopyWithImpl<_$ReceiptImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReceiptImplToJson(this);
  }
}

abstract class _Receipt implements Receipt {
  const factory _Receipt({
    required final String id,
    required final String fileName,
    required final int fileSize,
    required final String fileType,
    required final String url,
    required final String uploadedAt,
  }) = _$ReceiptImpl;

  factory _Receipt.fromJson(Map<String, dynamic> json) = _$ReceiptImpl.fromJson;

  @override
  String get id;
  @override
  String get fileName;
  @override
  int get fileSize;
  @override
  String get fileType;
  @override
  String get url;
  @override
  String get uploadedAt;

  /// Create a copy of Receipt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReceiptImplCopyWith<_$ReceiptImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
