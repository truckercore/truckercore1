// lib/core/util/debouncer.dart
// Simple debouncer to coalesce rapid calls (e.g., search typing)

import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;
  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
