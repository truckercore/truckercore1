/**
 * ALERT HARDENING UTILITIES (Deno/Edge Compatible)
 */

export type AlertSeverity = 'low' | 'medium' | 'high' | 'critical';
export type AlertStatus = 'open' | 'acknowledged' | 'resolved' | 'dismissed' | 'snoozed';
export type UserRole = 'driver' | 'dispatcher' | 'fleet_admin' | 'broker' | 'owner_operator';

export const SEVERITY_RANK: Record<AlertSeverity, number> = {
  low: 1,
  medium: 2,
  high: 3,
  critical: 4,
};

export const ESCALATION_LADDER: { afterMinutes: number; role: UserRole; label: string }[] = [
  { afterMinutes: 0, role: 'dispatcher', label: 'Dispatcher' },
  { afterMinutes: 5, role: 'fleet_admin', label: 'Fleet Admin' },
  { afterMinutes: 10, role: 'owner_operator', label: 'Owner Operator' },
];

export const PRIORITY_WEIGHTS = {
  severity: 0.35,
  eta_risk: 0.25,
  hos: 0.20,
  load_value: 0.20,
};

export function floorTo5Min(ts: Date | number | string): number {
  const BUCKET_MS = 5 * 60 * 1000;
  return Math.floor(new Date(ts).getTime() / BUCKET_MS) * BUCKET_MS;
}

export function calculatePriorityScore(params: {
  severity: AlertSeverity;
  minutesLate?: number;
  hosViolationRisk?: number;
  loadRevenue?: number;
  maxRevenue?: number;
}): number {
  const {
    severity,
    minutesLate = 0,
    hosViolationRisk = 0,
    loadRevenue = 0,
    maxRevenue = 10000,
  } = params;

  const severityScore = (SEVERITY_RANK[severity] / 4) * 100;
  const etaScore = Math.min(minutesLate / 120, 1) * 100;
  const hosScore = Math.min(hosViolationRisk, 1) * 100;
  const revenueScore = Math.min(loadRevenue / maxRevenue, 1) * 100;

  const raw =
    PRIORITY_WEIGHTS.severity * severityScore +
    PRIORITY_WEIGHTS.eta_risk * etaScore +
    PRIORITY_WEIGHTS.hos * hosScore +
    PRIORITY_WEIGHTS.load_value * revenueScore;

  return Math.round(Math.min(raw, 100));
}

export async function generateFingerprint(params: {
  org_id: string;
  alert_type: string;
  driver_id?: string | null;
  load_id?: string | null;
  now?: number;
}): Promise<string> {
  const { org_id, alert_type, driver_id = null, load_id = null, now = Date.now() } = params;
  
  const payload = JSON.stringify({
    org_id,
    alert_type,
    driver_id,
    load_id,
    time_bucket: floorTo5Min(now),
  });

  const msgUint8 = new TextEncoder().encode(payload);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('').slice(0, 16);
}
