import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/app_role.dart';
import '../state/roles_from_jwt.dart';
import '../state/session_provider.dart';

class SwitchRoleMenu extends ConsumerWidget {
  const SwitchRoleMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(comboAvailableRolesProvider);
    if (roles.length <= 1) return const SizedBox.shrink();
    final current = ref.watch(currentRoleProvider);
    return DropdownButtonHideUnderline(
      child: DropdownButton<AppRole>(
        value: current,
        items: [
          for (final r in roles)
            DropdownMenuItem(
              value: r,
              child: Text(
                r == AppRole.fleetManager ? 'Carrier Mode' : 'Broker Mode',
              ),
            ),
        ],
        onChanged: (r) {
          if (r != null) {
            // 1) Set authoritative role in session, mark as user-chosen
            ref.read(currentRoleProvider.notifier).set(r, userChosen: true);
            // 2) Log and navigate immediately to target dashboard
            // ignore: avoid_print
            print(
              '[role] switched to $r; session.role=${ref.read(sessionProvider).role}',
            );
            switch (r) {
              case AppRole.fleetManager:
                if (context.mounted) {
                  context.go('/dashboard/dispatch');
                }
                break;
              case AppRole.ownerOperator:
                if (context.mounted) {
                  context.go('/dashboard/owner');
                }
                break;
              case AppRole.broker:
                if (context.mounted) {
                  context.go('/dashboard/broker');
                }
                break;
              case AppRole.driver:
                if (context.mounted) {
                  context.go('/dashboard/driver');
                }
                break;
            }
          }
        },
        icon: const Icon(Icons.swap_horiz),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
