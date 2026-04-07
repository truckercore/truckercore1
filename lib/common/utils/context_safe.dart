import 'package:flutter/material.dart';

/// BuildContext helpers that are safe and concise.
extension ContextSafeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;

  /// Returns false if the context no longer mounted. Useful in async flows.
  bool get isMounted {
    // If this context belongs to a State object, use mounted if possible.
    // Otherwise assume true as BuildContext itself has no mounted.
    try {
      final element = this as Element;
      return element.mounted;
    } catch (_) {
      return true;
    }
  }

  /// Safely call setState-like callbacks only if still mounted.
  void ifMounted(void Function() fn) {
    if (isMounted) fn();
  }
}
