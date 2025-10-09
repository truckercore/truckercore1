// Supabase Edge Function: Push Digest Flush
// Path: supabase/functions/push_digest_flush/index.ts
// Schedule: every 5 minutes
// Behavior: Sends a single digest notification per user for queued items when outside quiet window.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

async function sendDigestNow(_sb: any, user_id: string, items: any[]) {
  // TODO: integrate with push provider
  // Example payload could include a count and a quick preview
  return { ok: true } as const;
}

function inQuietWindow(localHour: number, start: number | null, end: number | null): boolean {
  if (start == null || end == null || isNaN(start) || isNaN(end)) return false;
  if (start === end) return false; // disabled
  if (start < 0 || start > 23 || end < 0 || end > 23) return false;
  if (start < end) return localHour >= start && localHour < end; // same-day
  return localHour >= start || localHour < end; // overnight
}

function getLocalHour(timezone?: string | null): number {
  try {
    const fmt = new Intl.DateTimeFormat(undefined, { hour: "numeric", hour12: false, timeZone: timezone || undefined });
    const parts = fmt.formatToParts(new Date());
    const h = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
    return isNaN(h) ? new Date().getHours() : h;
  } catch {
    return new Date().getHours();
  }
}

Deno.serve(async (req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  // Find distinct users with pending digests
  const { data: pending, error } = await sb
    .from("push_digest")
    .select("user_id")
    .is("sent_at", null)
    .order("user_id")
    .limit(1000);
  if (error) return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });

  const users = Array.from(new Set((pending ?? []).map((r: any) => r.user_id))).slice(0, 200);

  let sent = 0, skipped = 0;
  for (const user_id of users) {
    // Pull profile
    const { data: profile } = await sb
      .from("profiles")
      .select("quiet_start_hour, quiet_end_hour, timezone")
      .eq("user_id", user_id)
      .maybeSingle();
    const start = (profile as any)?.quiet_start_hour ?? null;
    const end = (profile as any)?.quiet_end_hour ?? null;
    const tz = (profile as any)?.timezone ?? null;
    const hour = getLocalHour(tz);
    if (inQuietWindow(hour, start, end)) { skipped++; continue; }

    // Fetch this user's queued items
    const { data: items } = await sb
      .from("push_digest")
      .select("id, title, body, route, params, meta, created_at")
      .eq("user_id", user_id)
      .is("sent_at", null)
      .order("created_at", { ascending: true });

    if (!items || items.length === 0) { continue; }

    // Send one digest push
    const res = await sendDigestNow(sb, user_id, items);
    if (res.ok) {
      const now = new Date().toISOString();
      const ids = items.map((i: any) => i.id);
      await sb.from("push_digest").update({ sent_at: now }).in("id", ids);
      sent++;
    }
  }

  return new Response(JSON.stringify({ ok: true, sent, skipped, users: users.length }), { status: 200 });
});
