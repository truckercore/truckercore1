import { describe, test, expect } from 'vitest';
import {
  floorTo5Min,
  calculatePriorityScore,
  isValidTransition,
  getEscalationLevel,
  TRANSITIONS,
  ESCALATION_LADDER,
} from '../src/lib/alerts/hardening';

// Note: generateFingerprint is in Supabase _shared/hardening.ts and uses crypto.subtle (browser/deno)
// It is not currently exported from apps/web/src/lib/alerts/hardening.ts

// ─────────────────────────────────────────────
// 1. DEDUPLICATION HELPERS
// ─────────────────────────────────────────────

describe('floorTo5Min', () => {
  test('floors correctly', () => {
    const t = new Date('2024-01-01T12:07:30Z').getTime();
    const floor = new Date(floorTo5Min(t));
    expect(floor.getUTCMinutes()).toBe(5);
    expect(floor.getUTCSeconds()).toBe(0);
  });

  test('exact boundary stays in same bucket', () => {
    const t1 = new Date('2024-01-01T12:05:00Z').getTime();
    const t2 = new Date('2024-01-01T12:09:59Z').getTime();
    expect(floorTo5Min(t1)).toBe(floorTo5Min(t2));
  });
});


// ─────────────────────────────────────────────
// 2. STATE MACHINE
// ─────────────────────────────────────────────

describe('isValidTransition', () => {
  const validCases = [
    ['open',         'acknowledged'],
    ['open',         'dismissed'],
    ['open',         'snoozed'],
    ['acknowledged', 'resolved'],
    ['acknowledged', 'dismissed'],
    ['acknowledged', 'snoozed'],
    ['snoozed',      'open'],
    ['snoozed',      'dismissed'],
  ];

  test.each(validCases)('%s → %s is valid', (from, to) => {
    expect(isValidTransition(from as any, to as any)).toBe(true);
  });

  const invalidCases = [
    ['open',      'resolved'],   // must acknowledge first
    ['resolved',  'open'],       // terminal
    ['dismissed', 'open'],       // terminal
    ['resolved',  'dismissed'],  // terminal
    ['snoozed',   'resolved'],   // not allowed
  ];

  test.each(invalidCases)('%s → %s is invalid', (from, to) => {
    expect(isValidTransition(from as any, to as any)).toBe(false);
  });

  test('unknown current status returns false', () => {
    expect(isValidTransition('invalid_status' as any, 'open' as any)).toBe(false);
  });
});


// ─────────────────────────────────────────────
// 4. PRIORITY SCORING ENGINE
// ─────────────────────────────────────────────

describe('calculatePriorityScore', () => {
  test('returns 0–100 integer', () => {
    const score = calculatePriorityScore({ severity: 'low' });
    expect(score).toBeGreaterThanOrEqual(0);
    expect(score).toBeLessThanOrEqual(100);
    expect(Number.isInteger(score)).toBe(true);
  });

  test('critical > high > medium > low (all else equal)', () => {
    const params = { minutesLate: 0, hosViolationRisk: 0, loadRevenue: 0 };
    const low      = calculatePriorityScore({ ...params, severity: 'low'      });
    const medium   = calculatePriorityScore({ ...params, severity: 'medium'   });
    const high     = calculatePriorityScore({ ...params, severity: 'high'     });
    const critical = calculatePriorityScore({ ...params, severity: 'critical' });
    expect(critical).toBeGreaterThan(high);
    expect(high).toBeGreaterThan(medium);
    expect(medium).toBeGreaterThan(low);
  });

  test('more minutes late → higher score (same severity)', () => {
    const base = { severity: 'high', hosViolationRisk: 0, loadRevenue: 0 };
    const s1 = calculatePriorityScore({ ...base, minutesLate: 0   });
    const s2 = calculatePriorityScore({ ...base, minutesLate: 60  });
    const s3 = calculatePriorityScore({ ...base, minutesLate: 120 });
    expect(s3).toBeGreaterThan(s2);
    expect(s2).toBeGreaterThan(s1);
  });

  test('higher revenue → higher score (same severity)', () => {
    const base = { severity: 'medium', minutesLate: 0, hosViolationRisk: 0 };
    const s1 = calculatePriorityScore({ ...base, loadRevenue: 0      });
    const s2 = calculatePriorityScore({ ...base, loadRevenue: 5000  });
    const s3 = calculatePriorityScore({ ...base, loadRevenue: 10000 });
    expect(s3).toBeGreaterThan(s2);
    expect(s2).toBeGreaterThan(s1);
  });

  test('score is capped at 100', () => {
    const score = calculatePriorityScore({
      severity:           'critical',
      minutesLate:       999,
      hosViolationRisk: 1,
      loadRevenue:       999999,
    });
    expect(score).toBe(100);
  });

  test('all-zero inputs → non-negative score', () => {
    const score = calculatePriorityScore({ severity: 'low', minutesLate: 0,
                                           hosViolationRisk: 0, loadRevenue: 0 });
    expect(score).toBeGreaterThanOrEqual(0);
  });
});


// ─────────────────────────────────────────────
// 5. SLA ESCALATION LADDER
// ─────────────────────────────────────────────

describe('getEscalationLevel', () => {
  const minutesAgo = (min: number) => new Date(Date.now() - min * 60_000).toISOString();

  test('alert 2 min old → dispatcher (level 0)', () => {
    const result = getEscalationLevel(minutesAgo(2));
    expect(result.level).toBe(0);
    expect(result.role).toBe('dispatcher');
  });

  test('alert 6 min old → fleet_admin (level 1)', () => {
    const result = getEscalationLevel(minutesAgo(6));
    expect(result.level).toBe(1);
    expect(result.role).toBe('fleet_admin');
  });

  test('alert 12 min old → owner_operator (level 2)', () => {
    const result = getEscalationLevel(minutesAgo(12));
    expect(result.level).toBe(2);
    expect(result.role).toBe('owner_operator');
  });

  test('minutesElapsed is approximately correct', () => {
    const result = getEscalationLevel(minutesAgo(7));
    expect(result.minutesElapsed).toBeGreaterThanOrEqual(6);
    expect(result.minutesElapsed).toBeLessThanOrEqual(8);
  });

  test('escalation ladder covers 0 → 10 min boundary', () => {
    expect(ESCALATION_LADDER[0].afterMinutes).toBe(0);
    expect(ESCALATION_LADDER[ESCALATION_LADDER.length - 1].afterMinutes).toBe(10);
  });
});
