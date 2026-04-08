export type AppRole =
  | 'driver'
  | 'owner_operator'
  | 'fleet_manager'
  | 'freight_broker'
  | 'admin';

export type EntitlementDecision = {
  premium: boolean;
  isGrace: boolean;
  graceUntil: Date | null;
  role: AppRole | null;
  planCode: string | null;
};

const PLAN_ROLE_MAP: Record<string, AppRole> = {
  driver_pro: 'driver',
  owner_operator_pro: 'owner_operator',
  fleet_basic: 'fleet_manager',
  fleet_pro: 'fleet_manager',
  broker_pro: 'freight_broker',
};

// Grace period: 3 days after past_due before revoking
const GRACE_PERIOD_DAYS = 3;

export function normalizePlanCode(raw: string | null | undefined): string | null {
  if (!raw) return null;
  return raw.trim().toLowerCase();
}

export function roleFromPlanCode(planCode: string | null | undefined): AppRole | null {
  const normalized = normalizePlanCode(planCode);
  if (!normalized) return null;
  return PLAN_ROLE_MAP[normalized] ?? null;
}

export function isPremiumStatus(status: string | null | undefined): boolean {
  return status === 'active' || status === 'trialing';
}

export function isPastDue(status: string | null | undefined): boolean {
  return status === 'past_due';
}

export function shouldRevokePremium(status: string | null | undefined): boolean {
  return (
    status === 'canceled' ||
    status === 'unpaid' ||
    status === 'incomplete_expired' ||
    status === 'paused'
  );
}

export function resolveEntitlements(input: {
  status?: string | null;
  planCode?: string | null;
  currentRole?: AppRole | null;
  existingGraceUntil?: Date | null;
}): EntitlementDecision {
  const planCode = normalizePlanCode(input.planCode);
  const reconciledRole = roleFromPlanCode(planCode) ?? input.currentRole ?? null;

  // Active or trialing — full premium
  if (isPremiumStatus(input.status)) {
    return {
      premium: true,
      isGrace: false,
      graceUntil: null,
      role: reconciledRole,
      planCode,
    };
  }

  // Past due — grant grace period
  if (isPastDue(input.status)) {
    const now = new Date();
    // If already in grace period, preserve existing end date
    const graceUntil = input.existingGraceUntil && input.existingGraceUntil > now
      ? input.existingGraceUntil
      : new Date(now.getTime() + GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000);

    const stillInGrace = graceUntil > now;

    return {
      premium: stillInGrace,
      isGrace: true,
      graceUntil,
      role: reconciledRole,
      planCode,
    };
  }

  // Canceled / unpaid / paused / incomplete_expired — revoke
  return {
    premium: false,
    isGrace: false,
    graceUntil: null,
    role: reconciledRole,
    planCode: shouldRevokePremium(input.status) ? null : planCode,
  };
}
