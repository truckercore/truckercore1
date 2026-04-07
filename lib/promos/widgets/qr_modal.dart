// lib/promos/widgets/qr_modal.dart
import 'dart:async';
import 'package:flutter/material.dart';

class QrModal extends StatefulWidget {
  final String token;                // initial JWT
  final DateTime expiresAt;          // initial exp
  final Future<Map<String, dynamic>> Function() refreshToken; // returns {token, exp}

  const QrModal({
    super.key,
    required this.token,
    required this.expiresAt,
    required this.refreshToken,
  });

  @override
  State<QrModal> createState() => _QrModalState();
}

class _QrModalState extends State<QrModal> {
  late String _token;
  late DateTime _exp;
  Timer? _tick;

  Duration get _remaining => _exp.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _exp = widget.expiresAt;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final rem = _remaining.inSeconds;
      if (rem <= 10) {
        try {
          final r = await widget.refreshToken();
          if (!mounted) return;
          setState(() {
            _token = r['token'] as String;
            _exp = DateTime.fromMillisecondsSinceEpoch((r['exp'] as int) * 1000);
          });
        } catch (_) {}
      } else {
        setState(() {}); // update countdown
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rem = _remaining.inSeconds.clamp(0, 599);
    final mm = (rem ~/ 60).toString().padLeft(2, '0');
    final ss = (rem % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Show this QR to the cashier', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Replace with your QR widget (e.g., qr_flutter)
          Container(
            width: 200, height: 200,
            color: Colors.black12,
            alignment: Alignment.center,
            child: Text('QR for token\n${_token.substring(0, 12)}...'),
          ),
          const SizedBox(height: 8),
          Text('Expires in $mm:$ss'),
          const SizedBox(height: 8),
          const Text('Code refreshes periodically. Sharing may invalidate.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
