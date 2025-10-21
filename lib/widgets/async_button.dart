import 'package:flutter/material.dart';

class AsyncButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool lockAfter;        // keep disabled after success
  final bool showSuccessTick;  // briefly show a ✓ after success
  final Duration successDur;

  const AsyncButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.lockAfter = false,
    this.showSuccessTick = false,
    this.successDur = const Duration(milliseconds: 800),
  });

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _loading = false;
  bool _enabled = true;
  bool _showTick = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled && !_loading,
      child: ElevatedButton(
        style: widget.style,
        onPressed: (!_enabled || _loading)
            ? null
            : () async {
                setState(() {
                  _loading = true;
                  _enabled = false;
                  _showTick = false;
                });
                try {
                  await widget.onPressed();
                  if (widget.showSuccessTick) {
                    if (!mounted) return;
                    setState(() => _showTick = true);
                    await Future.delayed(widget.successDur);
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _loading = false;
                      if (!widget.lockAfter) _enabled = true;
                      _showTick = false;
                    });
                  }
                }
              },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : (_showTick
                  ? const Icon(Icons.check, key: ValueKey('tick'))
                  : DefaultTextStyle.merge(
                      key: const ValueKey('child'),
                      child: widget.child,
                    )),
        ),
      ),
    );
  }
}
