// Dart
import 'package:go_router/go_router.dart';
import 'onboarding/accept_invite_screen.dart';
import 'onboarding/invite_wizard.dart';

final router = GoRouter(
  routes: [
    // ... existing routes
    GoRoute(
      path: '/accept-invite',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return AcceptInviteScreen(token: token);
      },
    ),
    GoRoute(
      path: '/invite-wizard',
      builder: (context, state) {
        final orgId = state.uri.queryParameters['org_id'] ?? '';
        return InviteWizard(orgId: orgId);
      },
    ),
  ],
);
