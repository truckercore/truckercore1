import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/loads/dto/bulk_action_result.dart';

void main() {
  test('BulkActionResult JSON roundtrip', () {
    final result = const BulkActionResult(
      succeeded: ['a', 'b'],
      skipped: [
        BulkSkippedItem(id: 'c', reason: 'cap'),
        BulkSkippedItem(id: 'd', reason: 'invalid'),
      ],
      failed: [
        BulkFailedItem(id: 'e', error: 'network'),
      ],
    );
    final json = result.toJson();
    final back = BulkActionResult.fromJson(json);
    expect(back.succeeded, ['a', 'b']);
    expect(back.skipped.length, 2);
    expect(back.skipped.first.reason, 'cap');
    expect(back.failed.length, 1);
    expect(back.failed.first.error, 'network');
  });
}
