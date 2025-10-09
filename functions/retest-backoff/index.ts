// supabase/functions/retest-backoff/index.ts (Deno)
// Skeleton Edge Function implementing alert retest backoff polling.
// Deploy via Supabase CLI or dashboard; ensure env vars SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !key) {
  console.warn("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
const db = createClient(url ?? "", key ?? "", { auth: { persistSession: false } });

async function runProbe(_alertId: string): Promise<boolean> {
  // TODO: Implement probe; return true if issue is resolved (green)
  return false;
}

Deno.serve(async () => {
  const { data: due, error } = await db
    .from("alert_retest_state")
    .select("alert_id, tries")
    .lte("next_at", new Date().toISOString());
  if (error) {
    return new Response(error.message, { status: 500 });
  }

  for (const row of due ?? []) {
    const ok = await runProbe(row.alert_id as string);
    const tries = (row.tries as number) ?? 0;
    const newTries = ok ? 0 : Math.min(tries + 1, 3);
    const wait = ok ? 0 : (newTries === 1 ? 15 : newTries === 2 ? 60 : 300);

    await db.from("alert_retest_state").upsert({
      alert_id: row.alert_id,
      tries: newTries,
      next_at: ok
        ? new Date().toISOString()
        : new Date(Date.now() + wait * 1000).toISOString(),
    });

    if (!ok && newTries === 3) {
      // optional: notify once at max backoff
      // await notifyPersistentFailure(row.alert_id)
    }
  }

  return new Response("ok");
});
