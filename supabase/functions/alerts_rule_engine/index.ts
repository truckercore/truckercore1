// /supabase/functions/alerts_rule_engine/index.ts
// deno run --allow-env --allow-net
import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

// Configurable windows (minutes)
const DEFAULT_GRACE_MINUTES = Number(Deno.env.get('ETA_GRACE_MINUTES') ?? 15);
const DEFAULT_STALE_MINUTES = Number(Deno.env.get('ETA_STALE_MINUTES') ?? 5);

type AlertCode = 'LATE_ETA' | 'HOS_NEAR_LIMIT' | 'INSPECTION_WEEK';

Deno.serve(async () => {
  try {
    const orgIds = await activeOrgIds();
    let created = 0;
    for (const org_id of orgIds) {
      created += await lateEtaAlerts(org_id);
      created += await hosNearLimitAlerts(org_id);
      created += await inspectionWeekAlerts(org_id);
    }
    return new Response(JSON.stringify({ created }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

async function activeOrgIds(): Promise<string[]> {
  const twentyFourAgo = new Date(Date.now() - 24 * 3600 * 1000).toISOString();

  // Use robust views that expose native org_id when present, or org_id_derived when not.
  const [loads, hos] = await Promise.all([
    sb.from('v_loads_with_org').select('*').eq('status', 'in_transit').limit(10000),
    sb.from('v_hos_logs_with_org').select('*').gte('start_time', twentyFourAgo).limit(10000),
  ]);

  const norm = (row: any) => (row?.org_id ?? row?.org_id_derived ?? null) as string | null;
  const ids = new Set<string>();
  (loads.data ?? []).forEach((r: any) => { const id = norm(r); if (id) ids.add(id); });
  (hos.data ?? []).forEach((r: any) => { const id = norm(r); if (id) ids.add(id); });

  return Array.from(ids);
}

// Exported for unit tests
export function computeIsLateUtc(
  etaUtcIso: string | null | undefined,
  apptUtcIso: string | null | undefined,
  graceMinutes = DEFAULT_GRACE_MINUTES,
): boolean {
  if (!etaUtcIso || !apptUtcIso) return false; // unknown ETA or appt, do not mark late
  const etaMs = Date.parse(etaUtcIso);
  const apptMs = Date.parse(apptUtcIso);
  if (Number.isNaN(etaMs) || Number.isNaN(apptMs)) return false;
  return etaMs - apptMs > graceMinutes * 60 * 1000;
}

async function lateEtaAlerts(org_id: string): Promise<number> {
  // Prefer UTC-normalized columns if present; also pull updated_at as staleness proxy
  const { data: rows, error } = await sb
    .from('loads')
    .select('id, status, delivery_appt_at_utc, eta_now_utc, updated_at, delivery_appt_at, eta_now')
    .eq('org_id', org_id)
    .eq('status', 'in_transit')
    .or('not.delivery_appt_at_utc.is.null,not.delivery_appt_at.is.null');
  if (error) throw error;

  let created = 0;
  const now = Date.now();
  for (const r of rows ?? []) {
    // Unknown ETA → skip
    const etaIso = (r as any).eta_now_utc ?? (r as any).eta_now ?? null;
    const apptIso = (r as any).delivery_appt_at_utc ?? (r as any).delivery_appt_at ?? null;
    if (!etaIso || !apptIso) continue;

    // Staleness: if record's updated_at is too old, treat as low confidence and skip hard alert
    const updatedAtIso = (r as any).eta_updated_at ?? (r as any).updated_at ?? null;
    if (updatedAtIso) {
      const updatedMs = Date.parse(updatedAtIso);
      if (!Number.isNaN(updatedMs)) {
        const stale = now - updatedMs > DEFAULT_STALE_MINUTES * 60 * 1000;
        if (stale) continue; // soft warn only (not implemented here)
      }
    }

    // Apply grace window
    const isLate = computeIsLateUtc(etaIso, apptIso, DEFAULT_GRACE_MINUTES);
    if (!isLate) continue;

    created += await insertAlertOnce(org_id, 'LATE_ETA', {
      load_id: (r as any).id,
      eta_utc: etaIso,
      appt_utc: apptIso,
      grace_minutes: DEFAULT_GRACE_MINUTES,
    });
  }
  return created;
}

// HOS configuration
const SNAP_GAP_MINUTES = Number(Deno.env.get('HOS_SNAP_GAP_MINUTES') ?? 5);
const HOS_THRESHOLD_HOURS = Number(Deno.env.get('HOS_THRESHOLD_HOURS') ?? 10.75);
const HOS_ALLOW_CROSS_MIDNIGHT = (Deno.env.get('HOS_ALLOW_CROSS_MIDNIGHT') ?? 'false').toLowerCase() === 'true';

type HosInterval = { start: number; end: number };

// Exported for unit tests
export function stitchDrivingMs(
  intervals: HosInterval[],
  snapGapMinutes = SNAP_GAP_MINUTES,
  allowCrossMidnight = HOS_ALLOW_CROSS_MIDNIGHT,
): number {
  if (!intervals.length) return 0;
  // Sanitize intervals: filter invalid, clamp ordering
  const sane = intervals
    .map(i => ({ start: Math.min(i.start, i.end), end: Math.max(i.start, i.end) }))
    .filter(i => i.end > i.start);
  if (!sane.length) return 0;
  // Optionally discard those crossing midnight if not allowed
  const byDay = (ms: number) => new Date(ms).toISOString().slice(0, 10);
  const filtered = sane.filter(i => allowCrossMidnight || byDay(i.start) === byDay(i.end));
  if (!filtered.length) return 0;
  // Sort by start
  filtered.sort((a, b) => a.start - b.start);
  const merged: HosInterval[] = [];
  const snapGapMs = snapGapMinutes * 60 * 1000;
  for (const cur of filtered) {
    if (!merged.length) {
      merged.push({ ...cur });
      continue;
    }
    const last = merged[merged.length - 1];
    // If overlapping or within snap gap, merge
    if (cur.start <= last.end + snapGapMs) {
      last.end = Math.max(last.end, cur.end);
    } else {
      merged.push({ ...cur });
    }
  }
  // Sum durations
  return merged.reduce((acc, i) => acc + (i.end - i.start), 0);
}

async function hosNearLimitAlerts(org_id: string): Promise<number> {
  const twentyFourAgo = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const { data: logs, error } = await sb
    .from('hos_logs')
    .select('driver_user_id, start_time, end_time, status')
    .eq('org_id', org_id)
    .gte('start_time', twentyFourAgo);
  if (error) throw error;

  // Group driving intervals by driver
  const byDriverIntervals = new Map<string, HosInterval[]>();
  for (const l of logs ?? []) {
    if (l.status !== 'driving') continue;
    const start = Date.parse(l.start_time);
    const end = Date.parse(l.end_time);
    if (Number.isNaN(start) || Number.isNaN(end) || end <= start) continue; // discard errant
    const arr = byDriverIntervals.get(l.driver_user_id) ?? [];
    arr.push({ start, end });
    byDriverIntervals.set(l.driver_user_id, arr);
  }

  let created = 0;
  for (const [driver_user_id, arr] of byDriverIntervals.entries()) {
    const totalMs = stitchDrivingMs(arr, SNAP_GAP_MINUTES, HOS_ALLOW_CROSS_MIDNIGHT);
    const hours = totalMs / 3_600_000;
    if (hours >= HOS_THRESHOLD_HOURS && hours < 11.0) {
      created += await insertAlertOnce(org_id, 'HOS_NEAR_LIMIT', { driver_user_id, hours: Number(hours.toFixed(2)) });
    }
  }
  return created;
}

async function inspectionWeekAlerts(org_id: string): Promise<number> {
  // TODO: add blitz windows
  const blitzWindows: Array<{ start: string; end: string }> = [
    // { start: '2025-05-05', end: '2025-05-11' },
  ];
  const today = new Date().toISOString().slice(0, 10);
  const inWindow = blitzWindows.some(w => today >= w.start && today <= w.end);
  if (!inWindow) return 0;
  return insertAlertOnce(org_id, 'INSPECTION_WEEK', { date: today });
}

async function insertAlertOnce(org_id: string, code: AlertCode, payload: Record<string, unknown>): Promise<number> {
  const twoHoursAgo = new Date(Date.now() - 2 * 3600 * 1000).toISOString();
  const { data: recent, error: qErr } = await sb
    .from('alerts_events')
    .select('id')
    .eq('org_id', org_id)
    .eq('code', code)
    .gte('triggered_at', twoHoursAgo)
    .limit(1);
  if (qErr) throw qErr;
  if (recent?.length) return 0;

  const { error: insErr } = await sb.from('alerts_events').insert({
    org_id,
    severity: code === 'LATE_ETA' ? 'warning' : code === 'HOS_NEAR_LIMIT' ? 'warning' : 'info',
    code,
    payload,
    triggered_at: new Date().toISOString(),
  });
  if (insErr) throw insErr;
  return 1;
}
