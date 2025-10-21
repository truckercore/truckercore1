import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/common/services/loads_service.dart';
import 'package:truckercore1/features/loads/bulk_actions.dart';

// Minimal LoadItem stub builder for tests
LoadItem mk({required String id, required String status}) => LoadItem(
  id: id,
  origin: 'A',
  destination: 'B',
  pickupAt: DateTime.utc(2025),
  dropoffAt: DateTime.utc(2025, 1, 2),
  status: status,
);

void main() {
  group('planBulkPublish', () {
    test('Free cap: 18 active, select 5 drafts -> allow 2, skip 3', () {
      final selected = [
        mk(id: 'L1', status: 'draft'),
        mk(id: 'L2', status: 'draft'),
        mk(id: 'L3', status: 'draft'),
        mk(id: 'L4', status: 'draft'),
        mk(id: 'L5', status: 'draft'),
      ];
      final plan = planBulkPublish(activeCount: 18, isPremium: false, selected: selected);
      expect(plan.toPublishIds.length, 2);
      expect(plan.skippedDueToCapIds.length, 3);
      expect(plan.alreadyPublishedIds, isEmpty);
    });

    test('Premium: uncapped, publishes all drafts', () {
      final selected = [mk(id: 'L1', status: 'draft'), mk(id: 'L2', status: 'draft')];
      final plan = planBulkPublish(activeCount: 20, isPremium: true, selected: selected);
      expect(plan.toPublishIds, ['L1', 'L2']);
      expect(plan.skippedDueToCapIds, isEmpty);
    });

    test('Already-published are reported and not re-published', () {
      final selected = [mk(id: 'A', status: 'published'), mk(id: 'B', status: 'draft')];
      final plan = planBulkPublish(activeCount: 0, isPremium: false, selected: selected);
      expect(plan.alreadyPublishedIds, ['A']);
      expect(plan.toPublishIds, ['B']);
    });
  });
}
