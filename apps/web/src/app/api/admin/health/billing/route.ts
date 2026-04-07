import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const supa = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  const iso = new Date(Date.now() - 6 * 3600e3).toISOString();
  const { data: err } = await supa
    .from("webhook_events")
    .select("id")
    .eq("status", "errored")
    .gte("received_at", iso)
    .limit(1);

  let queued: any[] | null = null;
  try {
    const r = await supa
      .from("webhook_retry")
      .select("id")
      .eq("status", "queued")
      .lte("next_run_at", new Date().toISOString())
      .limit(1);
    queued = r.data ?? [];
  } catch {
    queued = [];
  }

  const healthy = !(err?.length) && !(queued?.length);
  return NextResponse.json(
    {
      ok: healthy,
      errors_recent: !!err?.length,
      retries_backlog: !!queued?.length,
    },
    { status: healthy ? 200 : 503 }
  );
}
