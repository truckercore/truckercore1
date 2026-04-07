// lib/core/logging/logger.dart
import 'package:flutter/foundation.dart';

class Log {
  static void d(String msg) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DEBUG] $msg');
    }
  }

  static void i(String msg) {
    // ignore: avoid_print
    print('[INFO] $msg');
  }

  static void w(String msg) {
    // ignore: avoid_print
    print('[WARN] $msg');
  }

  static void e(String msg, [Object? err]) {
    // ignore: avoid_print
    print('[ERROR] $msg${err != null ? ' :: $err' : ''}');
  }
}
