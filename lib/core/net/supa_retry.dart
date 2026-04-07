import 'dart:async';

Future<T> withRetry<T>(Future<T> Function() fn, {int maxAttempts = 3, Duration baseDelay = const Duration(milliseconds: 300)}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn();
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      final delay = baseDelay * attempt;
      await Future.delayed(delay);
    }
  }
}
