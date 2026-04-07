// lib/features/loads/bulk_actions.dart
import '../../common/services/loads_service.dart';

class BulkPublishPlan {
  final List<String> toPublishIds; // subset allowed by caps
  final List<String> skippedDueToCapIds;
  final List<String> alreadyPublishedIds;
  const BulkPublishPlan({
    required this.toPublishIds,
    required this.skippedDueToCapIds,
    required this.alreadyPublishedIds,
  });
}

/// Compute allowed subset for bulk publish respecting Free cap of 20 active loads.
/// activeCount: current active loads (not delivered/canceled)
/// isPremium: premium users are uncapped
/// selected: selected load items (mix of statuses)
BulkPublishPlan planBulkPublish({
  required int activeCount,
  required bool isPremium,
  required List<LoadItem> selected,
  int freeCap = 20,
}) {
  final drafts = <LoadItem>[];
  final already = <String>[];
  for (final l in selected) {
    final st = l.status.toLowerCase();
    if (st == 'published') {
      already.add(l.id);
    } else if (st == 'draft') {
      drafts.add(l);
    }
  }
  if (isPremium) {
    return BulkPublishPlan(
      toPublishIds: drafts.map((e) => e.id).toList(),
      skippedDueToCapIds: const [],
      alreadyPublishedIds: already,
    );
  }
  final remaining = (freeCap - activeCount).clamp(0, freeCap);
  final allowed = drafts.take(remaining).map((e) => e.id).toList();
  final skipped = drafts.skip(allowed.length).map((e) => e.id).toList();
  return BulkPublishPlan(
    toPublishIds: allowed,
    skippedDueToCapIds: skipped,
    alreadyPublishedIds: already,
  );
}
