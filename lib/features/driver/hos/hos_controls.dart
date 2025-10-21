import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/utils/retry.dart';
import 'hos_service.dart';

class HosControls extends StatefulWidget {
  const HosControls({super.key});
  @override
  State<HosControls> createState() => _HosControlsState();
}

class _HosControlsState extends State<HosControls> {
  String _current = 'off';
  bool _busy = false;

  HosService get _svc => HosService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await _svc.ensureTodayInitialized(user.id);
      final cur = await _svc.currentStatusToday(user.id);
      if (mounted) setState(() => _current = cur ?? 'off');
    } catch (_) {}
  }

  Future<void> _set(String s) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Sign in required');
      await retry(() => _svc.changeDutyStatus(driverId: user.id, newStatus: s));
      if (!mounted) return;
      setState(() => _current = s);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duty: $s')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('HOS update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorSel = Theme.of(context).colorScheme.primary;
    final styleSel = TextStyle(color: colorSel, fontWeight: FontWeight.bold);
    final style = const TextStyle();

    Widget btn(String key, String label, IconData icon) {
      final selected = _current == key;
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _set(key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              color: selected ? colorSel.withValues(alpha: 0.08) : null,
              border: Border.all(
                color: selected ? colorSel : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: selected ? colorSel : null),
                  const SizedBox(width: 6),
                  Text(label, style: selected ? styleSel : style),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: _busy ? 0.7 : 1,
      child: Row(
        children: [
          btn('off', 'Off Duty', Icons.self_improvement_outlined),
          const SizedBox(width: 6),
          btn('sleeper', 'Sleeper', Icons.bedtime_outlined),
          const SizedBox(width: 6),
          btn('on', 'On Duty', Icons.work_outline),
          const SizedBox(width: 6),
          btn('driving', 'Driving', Icons.drive_eta_outlined),
        ],
      ),
    );
  }
}
