// lib/shared/widgets/why_and_safesend.dart
// WhyChip, UndoQueue, and SafeSend widgets for change-management UX.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:truckercore1/services/safe_send_service.dart';

class WhyChip extends StatelessWidget {
  final String label; // e.g., 'Why this suggestion?'
  final List<String> lines; // bullet list explanation
  const WhyChip({super.key, required this.label, required this.lines});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.info_outline, size: 18),
      onPressed: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...lines.map((l) => ListTile(leading: const Icon(Icons.check, size: 18), title: Text(l))),
            ],
          ),
        ),
      ),
    );
  }
}

class UndoQueue {
  final Duration window;
  Timer? _t;
  VoidCallback? _finalize;
  VoidCallback? _onUndo;

  UndoQueue({this.window = const Duration(seconds: 5)});

  void schedule({required VoidCallback finalize, required VoidCallback onUndo}) {
    cancel();
    _finalize = finalize;
    _onUndo = onUndo;
    _t = Timer(window, () {
      _finalize?.call();
      _finalize = null;
      _onUndo = null;
    });
  }

  void undo() {
    _t?.cancel();
    _t = null;
    _onUndo?.call();
    _finalize = null;
    _onUndo = null;
  }

  void cancel() {
    _t?.cancel();
    _t = null;
    _finalize = null;
    _onUndo = null;
  }
}

class SafeSend extends StatefulWidget {
  final String actionLabel; // e.g., 'Send Offer'
  final Future<void> Function()? doAction; // server call to commit (legacy path)
  final Future<void> Function(String token)? doConfirmWithToken; // preferred when using staging
  final String? actionId; // if provided, will call stage_safe_send/undo_action
  final int ttlMinutes; // stage TTL minutes (default 10)
  final String confirmText; // 'Are you sure?'
  final Duration undoWindow;
  final ButtonStyle? style;
  const SafeSend({
    super.key,
    required this.actionLabel,
    this.doAction,
    this.doConfirmWithToken,
    this.actionId,
    this.ttlMinutes = 10,
    this.confirmText = 'Are you sure?',
    this.undoWindow = const Duration(seconds: 5),
    this.style,
  });

  @override
  State<SafeSend> createState() => _SafeSendState();
}

class _SafeSendState extends State<SafeSend> {
  late final UndoQueue _undo;
  String? _stagedToken;
  DateTime? _stagedExpiresAt;

  @override
  void initState() {
    super.initState();
    _undo = UndoQueue(window: widget.undoWindow);
  }

  Future<void> _onPressed() async {
    final messenger = ScaffoldMessenger.of(context);
    // If actionId provided, stage first
    if (widget.actionId != null) {
      try {
        // Stage via service (handles mixed shapes)
        final service = SafeSendService();
        final staged = await service.stageSafeSend(
          actionId: widget.actionId!,
          ttlMinutes: widget.ttlMinutes,
        );
        _stagedToken = staged.token;
        _stagedExpiresAt = staged.expiresAt;
      } catch (e) {
        final msg = e.toString().toUpperCase();
        final friendly = msg.contains('IN_QUIET_HOURS')
            ? 'Quiet hours in effect. Try again later.'
            : 'Could not stage send.';
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(friendly)));
        }
        return;
      }
    }

    final expiryHint = _stagedExpiresAt != null ? '\nExpires: ${_stagedExpiresAt!.toLocal()}' : '';

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.actionLabel),
        content: Text(widget.confirmText + expiryHint),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(widget.actionLabel)),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;

    // Schedule finalize after undo window; show snackbar with Undo
    messenger.hideCurrentSnackBar();
    final snack = SnackBar(
      content: Text('${widget.actionLabel} scheduled — undo within ${widget.undoWindow.inSeconds}s'),
      action: SnackBarAction(label: 'Undo', onPressed: () async {
        _undo.undo();
        if (widget.actionId != null) {
          try {
            final service = SafeSendService();
            await service.undoAction(actionId: widget.actionId!);
            // If we get here, succeeded
            if (mounted) {
              messenger.showSnackBar(const SnackBar(content: Text('Change reverted.')));
              }
          } catch (e) {
            final msg = e.toString().toUpperCase();
            final friendly = msg.contains('UNDO_WINDOW_ELAPSED') ? 'Undo window elapsed.' : 'Undo failed.';
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text(friendly)));
            }
          }
        }
      }),
      duration: widget.undoWindow,
    );
    messenger.showSnackBar(snack);

    _undo.schedule(
      finalize: () async {
        try {
          if (_stagedToken != null && widget.doConfirmWithToken != null) {
            await widget.doConfirmWithToken!(_stagedToken!);
          } else if (widget.doAction != null) {
            await widget.doAction!.call();
          }
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text('${widget.actionLabel} sent')));
        } catch (e) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      },
      onUndo: () {
        // Nothing persisted yet; user backed out (we also try RPC above if actionId provided)
        if (widget.actionId == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Undone')));
        }
      },
    );
  }

  @override
  void dispose() {
    _undo.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: widget.style,
      onPressed: _onPressed,
      child: Text(widget.actionLabel),
    );
  }
}
