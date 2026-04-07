import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uni_links3/uni_links.dart';

class InviteDeepLinkHandler with ChangeNotifier {
  StreamSubscription? _sub;
  String? _pendingToken;

  String? get pendingToken => _pendingToken;

  void start(BuildContext context) {
    _sub ??= uriLinkStream.listen((uri) {
      if (uri == null) return;
      if (uri.scheme.startsWith('app') && uri.host == 'accept-invite') {
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          _pendingToken = token;
          notifyListeners();
          if (!context.mounted) return;
          context.push('/accept-invite?token=$token');
        }
      }
    }, onError: (_) {});
  }

  void disposeSub() {
    _sub?.cancel();
    _sub = null;
  }
}
