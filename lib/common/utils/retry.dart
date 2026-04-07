typedef Task<T> = Future<T> Function();

class RetryOptions {
  final int maxAttempts;
  final Duration initialBackoff;
  final double multiplier;
  const RetryOptions({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 300),
    this.multiplier = 2.0,
  });
}

Future<T> retry<T>(
  Task<T> task, {
  RetryOptions options = const RetryOptions(),
  bool Function(Object error)? shouldRetry,
}) async {
  var attempt = 0;
  var delay = options.initialBackoff;
  late Object lastError;
  while (attempt < options.maxAttempts) {
    try {
      return await task();
    } catch (e) {
      lastError = e;
      attempt++;
      final canRetry =
          attempt < options.maxAttempts &&
          (shouldRetry == null || shouldRetry(e));
      if (!canRetry) rethrow;
      await Future<void>.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * options.multiplier).toInt(),
      );
    }
  }
  // Shouldn't reach here
  // ignore: only_throw_errors
  throw lastError;
}
