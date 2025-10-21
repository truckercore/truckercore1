// lib/core/analytics/user_analytics.dart
// Lightweight user analytics helper built on top of Sentry breadcrumbs.
// This avoids adding new dependencies while still providing actionable insights
// into user behavior across screens and key interactions.

import 'package:sentry_flutter/sentry_flutter.dart';

class UserAnalytics {
  const UserAnalytics._();

  static Future<void> appOpen({String? source}) async {
    try {
      await Sentry.addBreadcrumb(Breadcrumb(
        message: 'app_open',
        category: 'analytics',
        level: SentryLevel.info,
        data: {
          if (source != null) 'source': source,
        },
      ));
    } catch (_) {}
  }

  static void screenView(String name, {Map<String, dynamic>? extra}) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'screen_view',
        category: 'analytics',
        level: SentryLevel.info,
        data: {
          'screen': name,
          if (extra != null) ...extra,
        },
      ));
    } catch (_) {}
  }

  static void tap(String target, {String? screen, Map<String, dynamic>? extra}) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'tap',
        category: 'analytics',
        level: SentryLevel.info,
        data: {
          'target': target,
          if (screen != null) 'screen': screen,
          if (extra != null) ...extra,
        },
      ));
    } catch (_) {}
  }
}
