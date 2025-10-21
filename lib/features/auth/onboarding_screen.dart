import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/models/app_role.dart';
import '../../common/services/user_profile_service.dart';
import '../../common/state/session_provider.dart';
import '../../common/widgets/app_background.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0; // 0 role, 1 plan, 2 auth
  AppRole role = AppRole.driver;
  String plan = 'free'; // free | pro | enterprise

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_shipping),
            SizedBox(width: 8),
            Text('TruckerCore'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/auth/login'),
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
      body: AppBackground(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (step == 0)
                  _RoleStep(
                    role: role,
                    onChanged: (r) => setState(() => role = r),
                    onSelectRole: (r) => setState(() {
                      role = r;
                      step = 1;
                    }),
                  ),
                if (step == 1)
                  _PlanStep(
                    role: role,
                    plan: plan,
                    onChanged: (p) => setState(() => plan = p),
                  ),
                if (step == 2)
                  _AuthStep(
                    emailCtrl: emailCtrl,
                    passCtrl: passCtrl,
                    onContinue: _handleAuth,
                    busy: busy,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (step > 0)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() => step -= 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Back'),
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: busy ? null : _next,
                      icon: Icon(step < 2 ? Icons.chevron_right : Icons.check),
                      label: Text(step < 2 ? 'Next' : 'Finish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _next() {
    if (step < 2) {
      setState(() => step += 1);
    } else {
      _handleAuth();
    }
  }

  Future<void> _handleAuth() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Persist chosen role + plan as session; premium=true for pro/enterprise
      final isPremium = plan != 'free';
      // We do not handle Stripe here; in production, start checkout if isPremium.
      // For MVP, assume success and set profile/session accordingly.
      final profiles = ref.read(userProfileServiceProvider);
      // It's okay if not logged in yet; we will finish after login/sign up.
      // If the user is authenticated, persist their profile immediately.
      try {
        await profiles.upsertMyProfile(role: role, isPremium: isPremium);
      } catch (_) {}
      ref
          .read(sessionProvider.notifier)
          .setAll(role: role, isPremium: isPremium);

      // Route to appropriate dashboard path by role
      if (!mounted) return;
      switch (role) {
        case AppRole.driver:
          context.go('/dashboard/driver');
          break;
        case AppRole.fleetManager:
          context.go('/dashboard/dispatch');
          break;
        case AppRole.ownerOperator:
          context.go('/dashboard/owner');
          break;
        case AppRole.broker:
          context.go('/dashboard/broker');
          break;
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _RoleStep extends StatelessWidget {
  final AppRole role;
  final ValueChanged<AppRole> onChanged;
  final ValueChanged<AppRole> onSelectRole;
  const _RoleStep({
    required this.role,
    required this.onChanged,
    required this.onSelectRole,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick how you’ll use TruckerCore.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _RoleCard(
              selected: role == AppRole.driver,
              icon: Icons.local_shipping,
              title: 'Driver',
              bullets: const [
                'Truck-safe GPS',
                'Inspections & docs',
                'Upgrades: weigh alerts, AI route, parking',
              ],
              onTap: () => showRoleDetailsSheet(
                context,
                'Driver',
                AppRole.driver,
                onChanged,
                onSelectRole,
              ),
            ),
            _RoleCard(
              selected: role == AppRole.fleetManager,
              icon: Icons.view_kanban_outlined,
              title: 'Fleet/Dispatcher',
              bullets: const [
                'Assign loads, live map',
                'Upgrades: realtime fleet, AI matching, ELD/HOS',
              ],
              onTap: () => showRoleDetailsSheet(
                context,
                'Fleet/Dispatcher',
                AppRole.fleetManager,
                onChanged,
                onSelectRole,
              ),
            ),
            _RoleCard(
              selected: role == AppRole.ownerOperator,
              icon: Icons.badge_outlined,
              title: 'Owner-Op',
              bullets: const [
                'Driver features + profit',
                'Upgrades: fuel/toll optimize, IFTA exports',
              ],
              onTap: () => showRoleDetailsSheet(
                context,
                'Owner-Operator',
                AppRole.ownerOperator,
                onChanged,
                onSelectRole,
              ),
            ),
            _RoleCard(
              selected: role == AppRole.broker,
              icon: Icons.handshake_outlined,
              title: 'Broker',
              bullets: const [
                'Post loads, find drivers',
                'Upgrades: AI matching, automation, analytics',
              ],
              onTap: () => showRoleDetailsSheet(
                context,
                'Broker',
                AppRole.broker,
                onChanged,
                onSelectRole,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final List<String> bullets;
  final VoidCallback onTap;
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.bullets,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade700,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: selected ? Colors.blue : null),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Tap for details',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  final AppRole role;
  final String plan; // free | pro | enterprise
  final ValueChanged<String> onChanged;
  const _PlanStep({
    required this.role,
    required this.plan,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final roleTitle = () {
      switch (role) {
        case AppRole.driver:
          return 'Driver';
        case AppRole.fleetManager:
          return 'Fleet/Dispatcher';
        case AppRole.ownerOperator:
          return 'Owner-Operator';
        case AppRole.broker:
          return 'Broker';
      }
    }();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your plan — $roleTitle',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlanColumn(
              name: 'Free',
              price: ' ',
              lines: const [
                'Core navigation & basics',
                'Docs & inspections',
                'Ads shown (Driver/Dispatcher only)',
              ],
              selected: plan == 'free',
              onTap: () => onChanged('free'),
            ),
            const SizedBox(width: 12),
            _PlanColumn(
              name: 'Pro',
              price: 'Varies',
              lines: const [
                'Ad-free',
                'AI/Optimization features',
                'Advanced routing/alerts',
              ],
              selected: plan == 'pro',
              onTap: () => onChanged('pro'),
            ),
            const SizedBox(width: 12),
            _PlanColumn(
              name: 'Enterprise',
              price: 'Varies',
              lines: const [
                'Ad-free',
                'Seats/limits included',
                'Fleet/Broker tools',
              ],
              selected: plan == 'enterprise',
              onTap: () => onChanged('enterprise'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanColumn extends StatelessWidget {
  final String name;
  final String price; // display only
  final List<String> lines;
  final bool selected;
  final VoidCallback onTap;
  const _PlanColumn({
    required this.name,
    required this.price,
    required this.lines,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthStep extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final VoidCallback onContinue;
  final bool busy;
  const _AuthStep({
    required this.emailCtrl,
    required this.passCtrl,
    required this.onContinue,
    required this.busy,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create account / Log in',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text('Email'),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        const Text('Password'),
        TextField(controller: passCtrl, obscureText: true),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: busy ? null : onContinue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}

void showRoleDetailsSheet(
  BuildContext context,
  String title,
  AppRole role,
  ValueChanged<AppRole> onChanged,
  ValueChanged<AppRole> onSelectRole,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) {
      final copy = _roleCopy(role);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Text(
                    '$title — Plans & Features',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(copy['freeTitle']!),
              const SizedBox(height: 6),
              ...copy['free']!.map<Widget>((t) => _detailLine(t)),
              const SizedBox(height: 12),
              Text(copy['proTitle']!),
              const SizedBox(height: 6),
              ...copy['pro']!.map<Widget>((t) => _detailLine(t)),
              const SizedBox(height: 12),
              if (copy['entTitle'] != null) ...[
                Text(copy['entTitle']!),
                const SizedBox(height: 6),
                ...copy['ent']!.map<Widget>((t) => _detailLine(t)),
              ],
              const SizedBox(height: 12),
              if (copy['ads'] != null) Text('Ads: ${copy['ads']}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Select'),
                    onPressed: () {
                      onChanged(role);
                      onSelectRole(role);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Map<String, dynamic> _roleCopy(AppRole role) {
  switch (role) {
    case AppRole.driver:
      return {
        'freeTitle': 'Driver — Free (\$0/month):',
        'free': [
          'Truck-safe GPS, assigned deliveries, inspections, docs, route history.',
        ],
        'proTitle': 'Driver — Pro (\$9.99/month):',
        'pro': [
          'Weigh/inspection alerts, parking telemetry, fuel/toll-optimized routing,',
          'expense tracker, AI route assistant, ad-free.',
        ],
        'entTitle': 'Driver — Enterprise (via Fleet):',
        'ent': ['ELD/HOS, dispatcher chat, auto check-ins, scorecards.'],
        'ads': 'Truck stop ads only on Free.',
      };
    case AppRole.fleetManager:
      return {
        'freeTitle': 'Dispatcher — Free (\$0/month):',
        'free': [
          'Manual load assign, basic live map, CSV import, simple status.',
        ],
        'proTitle': 'Dispatcher — Pro (\$99/month up to 5 trucks):',
        'pro': [
          'Real-time fleet tracking, AI driver matching, analytics, exceptions,',
          'CSV export, offline support.',
        ],
        'entTitle': 'Dispatcher — Enterprise (\$249/month up to 20 trucks):',
        'ent': [
          'Advanced analytics, AI auto-dispatch, ELD/HOS, fleet billing, white-label, API.',
        ],
        'ads': 'Truck stop ads only on Free.',
      };
    case AppRole.ownerOperator:
      return {
        'freeTitle': 'Owner-Operator — Free (\$0/month):',
        'free': ['Driver features + profit snapshot (PPM, deadhead).'],
        'proTitle': 'Owner-Operator — Pro (\$9.99/month):',
        'pro': [
          'Fuel/toll optimization, expense tracking, CPA-ready exports, IFTA bundles, AI profit tips.',
        ],
        'entTitle': 'Owner-Operator — Enterprise (\$149/month 2–5 trucks):',
        'ent': ['Light fleet features, ELD integration, fleet-wide analytics.'],
        'ads': 'None.',
      };
    case AppRole.broker:
      return {
        'freeTitle': 'Broker — Free (\$0/month):',
        'free': [
          'Add loads, public job listings, manual driver search, limited messages.',
        ],
        'proTitle': 'Broker — Pro (\$149/month):',
        'pro': [
          'AI driver matching, load automation, broker–driver chat + docs, analytics, ad-free.',
        ],
        'entTitle': 'Broker — Enterprise (\$499/month, 5 seats):',
        'ent': [
          'Multi-seat, company analytics, API, white-label, dedicated support.',
        ],
        'ads': 'None.',
      };
  }
}

Widget _detailLine(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.check_circle, size: 16, color: Colors.green),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
