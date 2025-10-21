// lib/core/net/retry_backoff.dart
// Simple exponential backoff helper for resilient network calls.

import 'dart:async';
import 'dart:math';

class RetryOptions {
  final int maxAttempts; // total attempts including the first one
  final int baseMs; // base backoff in milliseconds
  final int maxMs; // cap for backoff delay
  final double jitterRatio; // 0.0..1.0 fraction of delay to add/subtract
  final Duration? perAttemptTimeout; // optional timeout per attempt

  const RetryOptions({
    this.maxAttempts = 3,
    this.baseMs = 300,
    this.maxMs = 6000,
    this.jitterRatio = 0.2,
    this.perAttemptTimeout,
  });
}

Future<T> runWithBackoff<T>(
  Future<T> Function(int attempt) task, {
  RetryOptions options = const RetryOptions(),
  bool Function(Object error)? isRetryable,
  void Function(int attempt, Object error)? onRetry,
}) async {
  final rnd = Random();
  Object? lastError;
  for (var attempt = 1; attempt <= options.maxAttempts; attempt++) {
    try {
      final fut = task(attempt);
      if (options.perAttemptTimeout != null) {
        return await fut.timeout(options.perAttemptTimeout!);
      }
      return await fut;
    } catch (e) {
      lastError = e;
      final canRetry = attempt < options.maxAttempts && (isRetryable?.call(e) ?? true);
      if (!canRetry) rethrow;
      onRetry?.call(attempt, e);
      // Exponential backoff with jitter
      final exp = pow(2, attempt - 1).toDouble();
      var delayMs = (options.baseMs * exp).toInt();
      delayMs = delayMs.clamp(options.baseMs, options.maxMs);
      if (options.jitterRatio > 0) {
        final jitter = (delayMs * options.jitterRatio).toInt();
        final delta = rnd.nextInt(jitter * 2 + 1) - jitter; // [-jitter, +jitter]
        delayMs += delta;
      }
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
  // Should not reach here; throw last error defensively
  if (lastError != null) throw lastError;
  throw StateError('runWithBackoff failed with unknown error');
}
