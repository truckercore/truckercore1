// lib/core/net/error_taxonomy.dart
// Normalize diverse exceptions into user-friendly messages and retry hints.

import 'dart:async';
import 'dart:io';

class FriendlyError {
  final String kind; // network|auth|rateLimit|validation|timeout|unknown
  final String message; // user-facing copy
  final bool retryable;
  final Object? raw; // raw exception for debug builds (do not display in release)
  const FriendlyError({
    required this.kind,
    required this.message,
    required this.retryable,
    this.raw,
  });
}

class ErrorTaxonomy {
  static FriendlyError map(Object error) {
    // Socket/HTTP connectivity
    if (error is SocketException) {
      return FriendlyError(
        kind: 'network',
        message: 'Network unavailable. Check your connection and try again.',
        retryable: true,
        raw: error,
      );
    }

    // Timeouts
    if (error is TimeoutException) {
      return FriendlyError(
        kind: 'timeout',
        message: 'Request timed out. You can retry in a moment.',
        retryable: true,
        raw: error,
      );
    }

    // Supabase Postgrest error shape (defensive, without importing the package here)
    final errStr = error.toString().toLowerCase();

    // Auth-related
    if (errStr.contains('auth') || errStr.contains('invalid token') || errStr.contains('jwt')) {
      return FriendlyError(
        kind: 'auth',
        message: 'Your session has expired. Please sign in again.',
        retryable: false,
        raw: error,
      );
    }

    // Rate limiting
    if (errStr.contains('rate') && errStr.contains('limit') || errStr.contains('429')) {
      return FriendlyError(
        kind: 'rateLimit',
        message: 'Too many requests. Please wait a few seconds and retry.',
        retryable: true,
        raw: error,
      );
    }

    // Validation-like hints
    if (errStr.contains('invalid') || errStr.contains('validation') || errStr.contains('constraint')) {
      return FriendlyError(
        kind: 'validation',
        message: 'Something looks off with your input. Please review and try again.',
        retryable: false,
        raw: error,
      );
    }

    return FriendlyError(
      kind: 'unknown',
      message: 'Something went wrong. Please try again.',
      retryable: true,
      raw: error,
    );
  }
}
