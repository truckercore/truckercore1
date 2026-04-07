/// Feature gate widget to blur/lock content behind plan or trial checks.
library;

// Group 1: dart imports
import 'dart:ui';

// Group 2: package imports
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeatureGate extends StatefulWidget {
  final Widget child; // premium content
  final String featureName; // e.g. "AI Dispatcher"
  final bool requireEnterprise; // if true, trial/pro won't unlock
  final int trialDays; // default trial length shown in CTA
  final VoidCallback? onUpgrade; // optional: route to billing/checkout
  final VoidCallback? onStartedTrial; // optional callback after trial starts

  const FeatureGate({
    super.key,
    required this.child,
    required this.featureName,
    this.requireEnterprise = false,
    this.trialDays = 7,
    this.onUpgrade,
    this.onStartedTrial,
  });

  @override
  State<FeatureGate> createState() => _FeatureGateState();
}

class _FeatureGateState extends State<FeatureGate> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  bool _isPremium = false;
  bool _starting = false;
  String _plan = 'free';
  DateTime? _trialEnds;

  @override
  void initState() {
    super.initState();
    _resolvePlan();
  }

  Future<void> _resolvePlan() async {
    setState(() => _loading = true);

    // 1) Fast path: use JWT app_metadata if available
    final user = _sb.auth.currentUser;
    final app = user?.appMetadata ?? {};
    final isPremiumClaim = app['app_is_premium'] == true;
    final planClaim = (app['app_plan'] as String?)?.toLowerCase();
    final trialEndsClaim = app['trial_ends_at'] as String?;

    String plan = planClaim ?? 'free';
    DateTime? trialEnds = trialEndsClaim != null ? DateTime.tryParse(trialEndsClaim) : null;
    bool premium = isPremiumClaim || (plan == 'trial' && (trialEnds == null || DateTime.now().isBefore(trialEnds)));

    // 2) Fallback to DB truth if claims look missing/stale
    if (!premium) {
      try {
        try {
          final planData = await _sb.rpc('current_plan');
          if (planData is String) {
            plan = planData.toLowerCase();
          }
        } catch (_) {/* ignore */}
        try {
          final ipData = await _sb.rpc('is_premium');
          if (ipData is bool) {
            premium = ipData;
          }
        } catch (_) {/* ignore */}
        // Pull trial_ends_at for countdown if on trial
        if (plan == 'trial' && trialEnds == null) {
          final String? uid = user?.id;
          if (uid != null) {
            final dynamic prof = await _sb
                .from('profiles')
                .select('trial_ends_at')
                .eq('user_id', uid)
                .maybeSingle();
            final ts = prof?.data?['trial_ends_at'] as String?;
            if (ts != null) trialEnds = DateTime.tryParse(ts);
            if (trialEnds != null && DateTime.now().isAfter(trialEnds)) {
              premium = false;
              plan = 'free';
            }
          }
        }
      } catch (_) {
        // ignore; keep best-effort
      }
    }

    if (!mounted) return;
    setState(() {
      _plan = plan;
      _trialEnds = trialEnds;
      _isPremium = premium;
      _loading = false;
    });
  }

  String _trialCountdown() {
    if (_plan != 'trial' || _trialEnds == null) return '';
    final remaining = _trialEnds!.difference(DateTime.now());
    final days = remaining.inDays.clamp(0, 365);
    if (days > 1) return '$days days left in trial';
    final hours = remaining.inHours.clamp(0, 48);
    if (hours > 1) return '$hours hours left in trial';
    final mins = remaining.inMinutes.clamp(0, 59);
    return '$mins minutes left in trial';
  }

  Future<void> _startTrial() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final res = await _sb.rpc('start_free_trial', params: {'days': widget.trialDays});
      if (res.error != null) {
        final msg = res.error!.message;
        final friendly = msg.contains('TRIAL_ALREADY_USED')
            ? 'Trial already used on this account.'
            : 'Could not start trial.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
        return;
      }
      await _sb.auth.refreshSession(); // pick up fresh claims when available
      await _resolvePlan();
      if (!mounted) return;
      widget.onStartedTrial?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trial started — enjoy ${widget.featureName}!')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
    }

    final requireEnt = widget.requireEnterprise;
    final isEnt = _plan == 'enterprise';
    final allow = requireEnt ? isEnt : _isPremium;

    if (allow) return widget.child;

    final isTrialActive = _plan == 'trial' && _isPremium;
    final countdown = _trialCountdown();

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
            child: Opacity(opacity: 0.55, child: widget.child),
          ),
        ),
        Positioned.fill(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.featureName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    requireEnt
                        ? 'Preview — unlock with Enterprise.'
                        : isTrialActive
                            ? 'Preview — trial active.'
                            : 'Preview — unlock full power with a ${widget.trialDays}-day trial.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (countdown.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(countdown, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 12),
                  if (!requireEnt) // trials don’t unlock Enterprise-only features
                    FilledButton(
                      onPressed: _starting ? null : _startTrial,
                      child: _starting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Start ${widget.trialDays}-day Trial'),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onUpgrade,
                    child: Text(requireEnt ? 'See Enterprise plans' : 'See Pro plans'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Usage examples:
// - Pro/Trial gate:
//   FeatureGate(featureName: 'AI Dispatcher', child: AIDispatcherPanel())
//
// - Enterprise-only:
//   FeatureGate(
//     featureName: 'Carrier Scorecards',
//     requireEnterprise: true,
//     child: Scorecards(),
//     onUpgrade: openBilling, // wire to your billing/checkout
//   );
