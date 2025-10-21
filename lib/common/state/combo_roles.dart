import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_role.dart';
import 'session_provider.dart';

class AvailableRoles {
  final List<AppRole> roles;
  const AvailableRoles(this.roles);
}

final availableRolesProvider = Provider<AvailableRoles>((ref) {
  // MVP: derive from current session only; in real app, fetch from profile/JWT.
  final session = ref.watch(sessionProvider);
  // If user is broker (simulating combo), expose both Carrier (fleetManager) and Broker for switching.
  if (session.role == AppRole.broker) {
    return const AvailableRoles([AppRole.broker, AppRole.fleetManager]);
  }
  return AvailableRoles([session.role]);
});
