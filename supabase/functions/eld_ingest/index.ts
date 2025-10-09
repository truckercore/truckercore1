import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type EldLog = {
  org_id?: string;
  driver_user_id: string;
  start_time: string; // ISO
  end_time: string;   // ISO
  status: "off" | "sleeper" | "driving" | "on";
  provider?: string | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function getReqId(req: Request) { return req.headers.get('x-request-id') || crypto.randomUUID(); }

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    const body = (await req.json()) as { logs: EldLog[] } | EldLog;
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const logs: EldLog[] = Array.isArray((body as any).logs) ? (body as any).logs : [body as EldLog];
    if (!logs.length) return new Response(JSON.stringify({ error: "no logs" }), { status: 400 });

    const rows = logs.map(l => ({
      org_id: l.org_id ?? null,
      driver_user_id: l.driver_user_id,
      start_time: l.start_time,
      end_time: l.end_time,
      status: l.status,
      source: "eld_certified",
      eld_provider: l.provider ?? null,
    }));

    const { error } = await supabase.from("hos_logs").insert(rows);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

    return new Response(JSON.stringify({ inserted: rows.length, request_id: getReqId(req) }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
