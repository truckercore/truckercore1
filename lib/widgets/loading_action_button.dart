import 'package:flutter/material.dart';

/// A button that shows a small spinner while the async [onPressed] runs,
/// and disables itself to prevent double-taps. Optionally stays disabled
/// after the first successful press when [lockAfter] is true (for one-shot actions).
class LoadingActionButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final bool initiallyEnabled;
  final ButtonStyle? style;
  final bool lockAfter; // keep disabled after first success (e.g., one-shot actions)

  const LoadingActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.initiallyEnabled = true,
    this.style,
    this.lockAfter = false,
  });

  @override
  State<LoadingActionButton> createState() => _LoadingActionButtonState();
}

class _LoadingActionButtonState extends State<LoadingActionButton> {
  bool _loading = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initiallyEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: widget.style,
      onPressed: (!_enabled || _loading)
          ? null
          : () async {
              setState(() {
                _loading = true;
                _enabled = false;
              });
              try {
                await widget.onPressed();
              } finally {
                if (mounted) {
                  setState(() {
                    _loading = false;
                    // Re-enable unless explicitly locked-after success
                    if (!widget.lockAfter) _enabled = true;
                  });
                }
              }
            },
      child: _loading
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : widget.child,
    );
  }
}
