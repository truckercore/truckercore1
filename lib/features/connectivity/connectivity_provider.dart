import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _init();
  }

  StreamSubscription<ConnectivityResult>? _sub;

  Future<void> _init() async {
    // Seed with current connectivity
    final current = await Connectivity().checkConnectivity();
    state = current != ConnectivityResult.none;
    _sub = Connectivity().onConnectivityChanged.listen((result) {
      state = result != ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provides a boolean online/offline status based on connectivity_plus.
/// true = online (has some connectivity), false = offline
final connectivityStatusProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});
