import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String operatorId,
    required String operatorName,
    required String date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    required PaymentMethod paymentMethod,
    required String location,
    int? odometer,
    required List<Receipt> receipts,
    String? loadNumber,
    required ExpenseStatus status,
    required String submittedAt,
    String? reviewedAt,
    String? reviewedBy,
    String? notes,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}

@freezed
class Receipt with _$Receipt {
  const factory Receipt({
    required String id,
    required String fileName,
    required int fileSize,
    required String fileType,
    required String url,
    required String uploadedAt,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);
}

enum ExpenseCategory {
  @JsonValue('fuel')
  fuel,
  @JsonValue('maintenance')
  maintenance,
  @JsonValue('tolls')
  tolls,
  @JsonValue('permits')
  permits,
  @JsonValue('insurance')
  insurance,
  @JsonValue('supplies')
  supplies,
  @JsonValue('other')
  other,
}

enum PaymentMethod {
  @JsonValue('cash')
  cash,
  @JsonValue('credit')
  credit,
  @JsonValue('debit')
  debit,
  @JsonValue('company-card')
  companyCard,
}

enum ExpenseStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}
