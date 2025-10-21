// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExpenseImpl _$$ExpenseImplFromJson(Map<String, dynamic> json) =>
    _$ExpenseImpl(
      id: json['id'] as String,
      operatorId: json['operatorId'] as String,
      operatorName: json['operatorName'] as String,
      date: json['date'] as String,
      category: $enumDecode(_$ExpenseCategoryEnumMap, json['category']),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['paymentMethod']),
      location: json['location'] as String,
      odometer: (json['odometer'] as num?)?.toInt(),
      receipts: (json['receipts'] as List<dynamic>)
          .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
          .toList(),
      loadNumber: json['loadNumber'] as String?,
      status: $enumDecode(_$ExpenseStatusEnumMap, json['status']),
      submittedAt: json['submittedAt'] as String,
      reviewedAt: json['reviewedAt'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$ExpenseImplToJson(_$ExpenseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'operatorId': instance.operatorId,
      'operatorName': instance.operatorName,
      'date': instance.date,
      'category': _$ExpenseCategoryEnumMap[instance.category]!,
      'amount': instance.amount,
      'description': instance.description,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod]!,
      'location': instance.location,
      'odometer': instance.odometer,
      'receipts': instance.receipts,
      'loadNumber': instance.loadNumber,
      'status': _$ExpenseStatusEnumMap[instance.status]!,
      'submittedAt': instance.submittedAt,
      'reviewedAt': instance.reviewedAt,
      'reviewedBy': instance.reviewedBy,
      'notes': instance.notes,
    };

const _$ExpenseCategoryEnumMap = {
  ExpenseCategory.fuel: 'fuel',
  ExpenseCategory.maintenance: 'maintenance',
  ExpenseCategory.tolls: 'tolls',
  ExpenseCategory.permits: 'permits',
  ExpenseCategory.insurance: 'insurance',
  ExpenseCategory.supplies: 'supplies',
  ExpenseCategory.other: 'other',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.credit: 'credit',
  PaymentMethod.debit: 'debit',
  PaymentMethod.companyCard: 'company-card',
};

const _$ExpenseStatusEnumMap = {
  ExpenseStatus.pending: 'pending',
  ExpenseStatus.approved: 'approved',
  ExpenseStatus.rejected: 'rejected',
};

_$ReceiptImpl _$$ReceiptImplFromJson(Map<String, dynamic> json) =>
    _$ReceiptImpl(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      fileType: json['fileType'] as String,
      url: json['url'] as String,
      uploadedAt: json['uploadedAt'] as String,
    );

Map<String, dynamic> _$$ReceiptImplToJson(_$ReceiptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'fileType': instance.fileType,
      'url': instance.url,
      'uploadedAt': instance.uploadedAt,
    };
