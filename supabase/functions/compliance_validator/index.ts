// supabase/functions/compliance_validator/index.ts
// Compliance validator v1
// Input: { candidate: {...}, context: {...} }
// Output: { status: 'pass'|'adjusted'|'blocked', reasons: string[], adjustments: Record<string,string>, trace_id?: string }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

// Simple facility hours mock: assume facilities closed 22:00–06:00 local (naive) for demonstration
function facilityClosedAt(iso: string | undefined | null): string | null {
  if (!iso) return null;
  try {
    const dt = new Date(iso);
    const h = dt.getUTCHours(); // naive UTC hours; real impl should use facility timezone
    if (h < 6) return "06:00";
    if (h >= 22) return "06:00"; // next day 06:00
    return null;
  } catch { return null; }
}

function hrsNeeded(miles: number) {
  // naive conversion: 50 mph average
  return Math.max(0, miles / 50);
}

Deno.serve(async (req) => {
  const traceId = req.headers.get('trace_id') || req.headers.get('x-request-id') || crypto.randomUUID();
  try {
    const body = await req.json();
    const candidate = body?.candidate ?? {};
    const context = body?.context ?? {};
    const strictMode = Boolean(body?.strict_mode ?? false);

    // Extract candidate fields
    const pickupAt: string | undefined = candidate.pickup_at;
    const dropoffAt: string | undefined = candidate.dropoff_at;
    const weightLb = Number(candidate.weight_lb ?? 0);
    const hazmat = Boolean(candidate.hazmat ?? false);
    const equipment = String(candidate.equipment ?? '').toLowerCase();

    // Context
    const hos = context.current_hos ?? {};
    const driveRemHr = Number(hos.drive_rem_hr ?? 11);
    const onDutyRemHr = Number(hos.on_duty_rem_hr ?? 14);

    const reasons: string[] = [];
    const adjustments: Record<string, string> = {};

    // Basic HOS feasibility heuristic: ensure at least 2h buffer
    if (driveRemHr < 2) reasons.push('HOS: insufficient drive hrs');
    if (onDutyRemHr < 2) reasons.push('HOS: insufficient on-duty hrs');

    // Weight limit sanity (80k lb federal; block if over 80k)
    if (weightLb > 80000) reasons.push('Weight over 80,000 lb');

    // Height limit placeholder for flatbed/hazmat (we don’t have height → just example label if hazmat)
    if (hazmat) {
      // simple policy: require equipment not 'van' for hazmat in this demo
      if (equipment.includes('van')) reasons.push('Hazmat requires compliant equipment');
    }

    // Facility closed check (pickup)
    const closedUntil = facilityClosedAt(pickupAt);
    if (closedUntil) {
      reasons.push(`Facility closed until ${closedUntil}`);
      // suggest adjusted pickup +1h to 07:00 if before opening
      try {
        const dt = new Date(pickupAt!);
        const adjusted = new Date(dt.getTime() + 60 * 60 * 1000);
        adjustments['pickup_at'] = adjusted.toISOString();
      } catch {}
    }

    // Determine status
    let status: 'pass'|'adjusted'|'blocked' = 'pass';
    if (reasons.length === 0) {
      status = 'pass';
    } else {
      // If we only have soft issues (like facility closed) and we provided adjustments, mark adjusted
      const hard = reasons.some(r => r.startsWith('HOS') || r.startsWith('Weight') || r.startsWith('Hazmat'));
      if (!hard && Object.keys(adjustments).length > 0 && !strictMode) {
        status = 'adjusted';
      } else {
        status = 'blocked';
      }
    }

    const payload = { status, reasons, adjustments, trace_id: traceId };
    return new Response(JSON.stringify(payload), { headers: { 'content-type': 'application/json', 'trace_id': traceId } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e), trace_id: traceId }), { status: 500, headers: { 'content-type': 'application/json', 'trace_id': traceId } });
  }
});
