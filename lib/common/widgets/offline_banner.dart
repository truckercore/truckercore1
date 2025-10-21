import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool backendReady;
  final bool isOnline;
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.backendReady,
    required this.isOnline,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final showBanner = !isOnline || !backendReady;
    if (!showBanner) return child;

    final text = !isOnline
        ? 'Offline — some data may be stale'
        : 'Read-only — backend not connected';

    return Column(
      children: [
        Material(
          color: Colors.amber[800],
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 18, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
