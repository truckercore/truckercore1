import 'package:flutter/material.dart';

/// Backward/forward compatible accessors for ColorScheme fields that changed
/// across Material versions. Prefer these instead of deprecated fields.
extension ColorSchemeCompat on ColorScheme {
  // background/onBackground were deprecated in favor of surface/onSurface.
  Color get backgroundCompat => surface;
  Color get onBackgroundCompat => onSurface;

  // surfaceVariant replaced by surfaceContainer* tokens in M3. Choose the
  // highest container by default which is most similar to previous intent.
  Color get surfaceVariantCompat => _firstNonNull<Color>([
    // Prefer surfaceContainerHighest when available in theme usage.
    // In Dart SDK, this field exists on ColorScheme.
    // Keep mapping to avoid direct deprecated usage.
    // ignore: deprecated_member_use_from_same_package
    // ignore: deprecated_member_use
    // We still return a safe fallback if not ideal.
    surfaceContainerHighest,
    surface,
  ]);

  Color get outlineCompat => outline;
}

T _firstNonNull<T>(List<T?> values) {
  for (final v in values) {
    if (v != null) return v;
  }
  throw StateError('No non-null value provided');
}
