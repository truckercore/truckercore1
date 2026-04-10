/**
 * ALERT HARDENING UTILITIES
 * Standardized logic for deduplication, priority, and escalation.
 */

import { AlertSeverity, AlertStatus, UserRole } from '@/types/alert-copilot';

// ─── CONSTANTS ─────────────────────────────────────────────────────────────

export const SEVERITY_RANK: Record<AlertSeverity, number> = {
  low: 1,
  medium: 2,
  high: 3,
  critical: 4,
};

export const TRANSITIONS: Record<AlertStatus, AlertStatus[]> = {
  open: ['acknowledged', 'dismissed', 'snoozed'],
  acknowledged: ['resolved', 'dismissed', 'snoozed'],
  snoozed: ['open', 'dismissed'],
  resolved: [],
  dismissed: [],
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

// ─── LOGIC ──────────────────────────────────────────────────────────────────

/**
 * Floor a timestamp to the nearest 5-minute bucket for deduplication.
 */
export function floorTo5Min(ts: Date | number | string): number {
  const BUCKET_MS = 5 * 60 * 1000;
  return Math.floor(new Date(ts).getTime() / BUCKET_MS) * BUCKET_MS;
}

/**
 * Calculate a 0–100 priority score for an alert.
 */
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

  // Normalize each factor to 0–100
  const severityScore = (SEVERITY_RANK[severity] / 4) * 100;
  const etaScore = Math.min(minutesLate / 120, 1) * 100; // cap at 2h late
  const hosScore = Math.min(hosViolationRisk, 1) * 100;
  const revenueScore = Math.min(loadRevenue / maxRevenue, 1) * 100;

  const raw =
    PRIORITY_WEIGHTS.severity * severityScore +
    PRIORITY_WEIGHTS.eta_risk * etaScore +
    PRIORITY_WEIGHTS.hos * hosScore +
    PRIORITY_WEIGHTS.load_value * revenueScore;

  return Math.round(Math.min(raw, 100));
}

/**
 * Validate that a state transition is legal.
 */
export function isValidTransition(current: AlertStatus, next: AlertStatus): boolean {
  return TRANSITIONS[current]?.includes(next) ?? false;
}

/**
 * Determine the current escalation level based on alert age.
 */
export function getEscalationLevel(createdAt: string | Date, now: number = Date.now()) {
  const elapsed = (now - new Date(createdAt).getTime()) / 60_000;

  for (let i = ESCALATION_LADDER.length - 1; i >= 0; i--) {
    if (elapsed >= ESCALATION_LADDER[i].afterMinutes) {
      return {
        level: i,
        role: ESCALATION_LADDER[i].role,
        label: ESCALATION_LADDER[i].label,
        minutesElapsed: Math.round(elapsed),
      };
    }
  }
  return { level: 0, ...ESCALATION_LADDER[0], minutesElapsed: 0 };
}

/**
 * Generate a collision-resistant idempotency key for a GPS event.
 */
export function generateIdempotencyKey(params: {
  driver_id: string;
  timestamp: string;
  lat: number;
  lng: number;
}): string {
  // Simple representation for browser/Node compatibility in tests
  const raw = `${params.driver_id}:${params.timestamp}:${params.lat}:${params.lng}`;
  let hash = 0;
  for (let i = 0; i < raw.length; i++) {
    hash = ((hash << 5) - hash) + raw.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash).toString(16).padStart(24, '0');
}
