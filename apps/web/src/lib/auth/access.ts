export type AppRole =
  | 'driver'
  | 'owner_operator'
  | 'fleet_manager'
  | 'freight_broker'
  | 'admin';

export type AccessProfile = {
  role: AppRole | null;
  is_premium?: boolean | null;
  app_is_premium?: boolean | null;
  full_name?: string | null;
  plan_code?: string | null;
  subscription_status?: string | null;
};

export function isPremium(profile: AccessProfile | null | undefined): boolean {
  return !!(profile?.app_is_premium || profile?.is_premium);
}

export function hasRole(
  profile: AccessProfile | null | undefined,
  allowedRoles: AppRole[]
): boolean {
  if (!profile?.role) return false;
  if (profile.role === 'admin') return true;
  return allowedRoles.includes(profile.role);
}

export function hasPremiumRoleAccess(
  profile: AccessProfile | null | undefined,
  allowedRoles: AppRole[]
): boolean {
  return hasRole(profile, allowedRoles) && isPremium(profile);
}
