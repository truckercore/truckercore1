import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';

// Minimal Box interface to avoid hard dependency on hive in build
abstract class Box {
  Iterable<dynamic> get keys;
  Future<void> put(dynamic key, dynamic value);
  dynamic get(dynamic key);
  Future<void> delete(dynamic key);
}

class OfflineQueue {
  final Box box;
  final Duration baseBackoff;
  final Duration maxBackoff;
  OfflineQueue(this.box, {this.baseBackoff = const Duration(milliseconds: 500), this.maxBackoff = const Duration(minutes: 5)});

  /// Enqueue with optional idempotencyKey to deduplicate logically identical actions
  Future<String> enqueue(String kind, Map<String, dynamic> payload, {String? idempotencyKey}) async {
    // If idempotencyKey provided and exists, return its id
    if (idempotencyKey != null) {
      for (final k in box.keys) {
        final raw = box.get(k);
        if (raw is String) {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          if (j['idempotencyKey'] == idempotencyKey) {
            return k.toString();
          }
        }
      }
    }
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    await box.put(
      id,
      jsonEncode({
        'id': id,
        'kind': kind,
        'payload': payload,
        'idempotencyKey': idempotencyKey,
        'attempts': 0,
        'nextAttemptAt': now.toIso8601String(),
        'ts': now.toIso8601String(),
        'lastError': null,
      }),
    );
    return id;
  }

  /// Drain all items regardless of backoff (immediate send). Keeps failures for retry.
  Future<void> drain(
    Future<void> Function(String kind, Map<String, dynamic>) sender,
  ) async {
    final keys = box.keys.toList(growable: false);
    for (final k in keys) {
      final raw = box.get(k);
      if (raw is! String) continue;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      try {
        await sender(
          j['kind'] as String,
          Map<String, dynamic>.from(j['payload']),
        );
        await box.delete(k);
      } catch (e) {
        // keep for retry and update error/backoff
        await _recordFailure(k, j, e.toString());
      }
    }
  }

  /// Process items whose nextAttemptAt is due.
  Future<void> process(
    Future<void> Function(String kind, Map<String, dynamic>) sender,
  ) async {
    final now = DateTime.now().toUtc();
    final keys = box.keys.toList(growable: false);
    for (final k in keys) {
      final raw = box.get(k);
      if (raw is! String) continue;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final dueStr = j['nextAttemptAt'] as String?;
      final due = dueStr != null ? DateTime.tryParse(dueStr)?.toUtc() : now;
      if (due == null || due.isAfter(now)) continue; // not yet due
      try {
        await sender(j['kind'] as String, Map<String, dynamic>.from(j['payload']));
        await box.delete(k);
      } catch (e) {
        await _recordFailure(k, j, e.toString());
      }
    }
  }

  Future<void> _recordFailure(dynamic key, Map<String, dynamic> j, String error) async {
    final attempts = (j['attempts'] as int? ?? 0) + 1;
    // exponential backoff with jitter
    final baseMs = baseBackoff.inMilliseconds;
    int delayMs = baseMs * (1 << (attempts - 1));
    delayMs = delayMs.clamp(baseMs, maxBackoff.inMilliseconds);
    final jitter = max(1, (delayMs * 0.2).toInt());
    final rand = Random().nextInt(2 * jitter + 1) - jitter;
    delayMs = (delayMs + rand).clamp(baseMs, maxBackoff.inMilliseconds);
    final next = DateTime.now().toUtc().add(Duration(milliseconds: delayMs));
    final updated = Map<String, dynamic>.from(j)
      ..['attempts'] = attempts
      ..['nextAttemptAt'] = next.toIso8601String()
      ..['lastError'] = error;
    await box.put(key, jsonEncode(updated));
  }
}
