import 'dart:async';

import 'package:flutter/material.dart';

class StatusOverlay extends StatefulWidget {
  final Widget child;
  const StatusOverlay({super.key, required this.child});

  @override
  State<StatusOverlay> createState() => _StatusOverlayState();
}

class _StatusOverlayState extends State<StatusOverlay> {
  OverlayEntry? _entry;
  Timer? _autoHide;

  void show(String text, {bool error = false, Duration duration = const Duration(seconds: 2)}) {
    hide();
    _entry = OverlayEntry(
      builder: (_) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: error ? Colors.red.withValues(alpha: .9) : Colors.black.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(text, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _autoHide = Timer(duration, hide);
  }

  void hide() {
    _autoHide?.cancel();
    _autoHide = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
