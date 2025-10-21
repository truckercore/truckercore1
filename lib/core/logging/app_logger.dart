import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class AppLogger {
  static void trace(String message) {
    if (kDebugMode) dev.log('[TRACE] $message');
  }

  static void debug(String message) {
    if (kDebugMode) dev.log('[DEBUG] $message');
  }

  static void info(String message) {
    dev.log('[INFO] $message');
  }

  static void warn(String message, [Object? err, StackTrace? st]) {
    dev.log('[WARN] $message ${err != null ? ' err=$err' : ''}', stackTrace: st);
  }

  static void error(String message, [Object? err, StackTrace? st]) {
    dev.log('[ERROR] $message ${err != null ? ' err=$err' : ''}', stackTrace: st);
  }
}
