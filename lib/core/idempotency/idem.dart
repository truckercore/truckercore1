// lib/core/idempotency/idem.dart
import 'dart:math';

String generateIdempotencyKey({String prefix = 'idem'}) {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '$prefix-$hex';
}
