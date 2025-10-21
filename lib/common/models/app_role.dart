enum AppRole { driver, fleetManager, ownerOperator, broker }

// Keep session model with roles in the models folder so there's a single source of truth.
class UserSession {
  final AppRole role;
  final bool isPremium;
  final bool userChosenRole;
  const UserSession({
    required this.role,
    required this.isPremium,
    this.userChosenRole = false,
  });
}
