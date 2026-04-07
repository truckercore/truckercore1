import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_role.dart';
import '../state/session_provider.dart';

class RoleBadge extends ConsumerWidget {
  const RoleBadge({super.key});

  String _label(AppRole role) {
    switch (role) {
      case AppRole.driver:
        return 'Driver';
      case AppRole.fleetManager:
        return 'Fleet Manager';
      case AppRole.ownerOperator:
        return 'Owner Operator';
      case AppRole.broker:
        return 'Broker';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final text = _label(session.role) + (session.isPremium ? ' • Premium' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
