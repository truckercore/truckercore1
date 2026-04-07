import 'package:sentry_flutter/sentry_flutter.dart';

/// Simple stopwatch-based trace helper. Emits a Sentry message "metric:`<name>` ms=`<value>`".
Future<T> trace<T>(String name, Future<T> Function() f) async {
  final sw = Stopwatch()..start();
  try {
    return await f();
  } finally {
    sw.stop();
    try {
      // Sentry.captureMessage in recent SDKs expects a template+params list.
      // To keep it simple and compatible, we inline the value into the message.
      await Sentry.captureMessage('metric:$name ms=${sw.elapsedMilliseconds}');
    } catch (_) {
      // ignore Sentry errors
    }
  }
}
