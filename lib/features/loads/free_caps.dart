import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/services/loads_service.dart';
import '../../common/state/session_provider.dart';

/// Free tier caps for Loads
class FreeLoadCaps {
  /// Maximum number of active loads for Free plan
  static const int maxActiveFree = 20;

  /// Returns true if a Free user can create another active load given the current active count.
  /// Premium users are always allowed.
  static bool canCreateNew({required int activeCount, required bool isPremium}) {
    if (isPremium) return true;
    return activeCount < maxActiveFree;
  }

  /// User-facing message when the cap has been reached.
  static String reachedMessage() =>
      'Free limit reached: You can have up to $maxActiveFree active loads. Upgrade to Pro for higher limits.';
}

/// Computes the number of active loads (not delivered/canceled) using LoadsService.
Future<int> computeActiveCount(WidgetRef ref) async {
  final svc = ref.read(loadsServiceProvider);
  final list = await svc.listLoads();
  int active = 0;
  for (final l in list) {
    final st = l.status.toLowerCase();
    if (st != 'delivered' && st != 'canceled' && st != 'cancelled') {
      active += 1;
    }
  }
  return active;
}

/// Convenience helper to check cap using providers in scope.
Future<bool> canCreateAnotherLoad(WidgetRef ref) async {
  final isPremium = ref.read(sessionProvider).isPremium;
  final active = await computeActiveCount(ref);
  return FreeLoadCaps.canCreateNew(activeCount: active, isPremium: isPremium);
}
