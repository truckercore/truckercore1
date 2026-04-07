// lib/core/ids/idempotency.dart
// Client-generated idempotency keys for safe retries.

import 'package:uuid/uuid.dart';

class IdempotencyKeys {
  static final _uuid = const Uuid();
  static String newKey() => _uuid.v4();

  // Optional deterministic key for a specific action target
  static String forAction({required String userId, required String action, required String targetId}) {
    // A simple deterministic concatenation hashed by UUID v5 URL namespace
    final name = '$userId::$action::$targetId';
    // uuid v5 expects a string namespace in this SDK version; use the enum's value when available
    return const Uuid().v5(Namespace.url.value, name);
  }
}
