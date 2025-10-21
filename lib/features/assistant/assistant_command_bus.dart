// lib/features/assistant/assistant_command_bus.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Public command tuple type.
typedef AssistantCommand = ({String type, Map<String, dynamic> payload});

/// Simple in-memory rate limiter to avoid spamming commands.
class _RateLimiter {
  final Duration _window;
  final int _max;
  final _events = <DateTime>[];
  _RateLimiter({Duration window = const Duration(seconds: 3), int max = 3})
      : _window = window,
        _max = max;
  bool allow() {
    final now = DateTime.now().toUtc();
    _events.removeWhere((t) => now.difference(t) > _window);
    if (_events.length >= _max) return false;
    _events.add(now);
    return true;
  }
}

final assistantCommandBusProvider = Provider<AssistantCommandBus>((ref) {
  return AssistantCommandBus(ref);
});

class AssistantCommandBus {
  AssistantCommandBus(this.ref);
  final Ref ref;
  final _rateLimiter = _RateLimiter();

  Future<void> dispatch(AssistantCommand cmd, {BuildContext? context}) async {
    if (!_rateLimiter.allow()) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'assistant_cmd_rate_limited',
        category: 'assistant',
        data: {'type': cmd.type},
        level: SentryLevel.warning,
      ));
      return;
    }

    switch (cmd.type) {
      case 'focus_driver':
        final id = cmd.payload['driver_id'] as String?;
        if (id == null || id.isEmpty) {
          throw ArgumentError('focus_driver: driver_id required');
        }
        // Optional confirmation for high-impact actions
        if (context != null) {
          final ok = await _confirm(context, title: 'Focus driver', body: 'Focus map on driver $id?');
          if (!ok) return;
        }
        // TODO: integrate with a MapController provider when available.
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'assistant_cmd',
          category: 'assistant',
          data: {'type': cmd.type, 'driver_id': id},
        ));
        break;
      case 'navigate_to_load':
        final lat = (cmd.payload['lat'] as num?)?.toDouble();
        final lon = (cmd.payload['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) {
          throw ArgumentError('navigate_to_load: lat/lon required');
        }
        if (context != null) {
          final ok = await _confirm(context, title: 'Start navigation', body: 'Open navigation to ($lat, $lon)?');
          if (!ok) return;
        }
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'assistant_cmd',
          category: 'assistant',
          data: {'type': cmd.type},
        ));
        break;
      default:
        throw UnsupportedError('Unknown assistant command: ${cmd.type}');
    }
  }

  Future<bool> _confirm(BuildContext context, {required String title, required String body}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Abortable assistant streaming client interface.
abstract class IAssistantClient {
  Stream<String> sendMessage(String text, {void Function()? onOpen});
  void abort();
}

/// A simple abort controller wrapper for any Stream subscription.
class AssistantStreamAborter {
  StreamSubscription<String>? _sub;
  void attach(StreamSubscription<String> sub) {
    _sub?.cancel();
    _sub = sub;
  }

  Future<void> abort() async {
    await _sub?.cancel();
    _sub = null;
  }
}
