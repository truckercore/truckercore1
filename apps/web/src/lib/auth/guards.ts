import { redirect } from 'next/navigation';
import { getAuthenticatedUser } from './getAuthenticatedUser';
import { hasRole, hasPremiumRoleAccess, type AppRole } from './access';

export async function requireUser(redirectTo: string) {
  return getAuthenticatedUser(redirectTo);
}

export async function requireRole(
  redirectTo: string,
  allowedRoles: AppRole[]
) {
  const auth = await getAuthenticatedUser(redirectTo);

  if (!hasRole(auth.profile, allowedRoles)) {
    redirect('/unauthorized');
  }

  return auth;
}

export async function requirePremium(
  redirectTo: string,
  allowedRoles?: AppRole[]
) {
  const auth = await getAuthenticatedUser(redirectTo);

  if (allowedRoles?.length) {
    if (!hasPremiumRoleAccess(auth.profile, allowedRoles)) {
      redirect(`/upgrade?from=${encodeURIComponent(redirectTo)}`);
    }
    return auth;
  }

  if (!auth.isPremium) {
    redirect(`/upgrade?from=${encodeURIComponent(redirectTo)}`);
  }

  return auth;
}
