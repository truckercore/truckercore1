// lib/features/loads/dto/bulk_action_result.dart
import 'package:meta/meta.dart';

@immutable
class BulkSkippedItem {
  final String id;
  final String reason; // 'cap' | 'invalid' | 'conflict'
  const BulkSkippedItem({required this.id, required this.reason});

  Map<String, dynamic> toJson() => {'id': id, 'reason': reason};
  static BulkSkippedItem fromJson(Map<String, dynamic> json) =>
      BulkSkippedItem(id: json['id'] as String, reason: json['reason'] as String);
}

@immutable
class BulkFailedItem {
  final String id;
  final String error;
  const BulkFailedItem({required this.id, required this.error});
  Map<String, dynamic> toJson() => {'id': id, 'error': error};
  static BulkFailedItem fromJson(Map<String, dynamic> json) =>
      BulkFailedItem(id: json['id'] as String, error: json['error'] as String);
}

@immutable
class BulkActionResult {
  final List<String> succeeded;
  final List<BulkSkippedItem> skipped;
  final List<BulkFailedItem> failed;

  const BulkActionResult({
    this.succeeded = const [],
    this.skipped = const [],
    this.failed = const [],
  });

  Map<String, dynamic> toJson() => {
        'succeeded': succeeded,
        'skipped': skipped.map((e) => e.toJson()).toList(),
        'failed': failed.map((e) => e.toJson()).toList(),
      };

  static BulkActionResult fromJson(Map<String, dynamic> json) => BulkActionResult(
        succeeded: (json['succeeded'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        skipped: (json['skipped'] as List? ?? const [])
            .map((e) => BulkSkippedItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        failed: (json['failed'] as List? ?? const [])
            .map((e) => BulkFailedItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );
}
