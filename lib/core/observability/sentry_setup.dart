import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> initSentryAndRunApp(Widget Function() appBuilder) async {
  await SentryFlutter.init(
    (o) {
      o.dsn = const String.fromEnvironment('SENTRY_DSN');
      o.tracesSampleRate = 0.2;
      o.enableAutoSessionTracking = true;
      o.attachScreenshot = false;
      o.sendDefaultPii = false;
    },
    appRunner: () => runZonedGuarded(() {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(appBuilder());
    }, (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }),
  );
}
