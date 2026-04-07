// functions/report_problem/index.ts
// Ingest problem reports with anonymized diagnostics
import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = {
  org_id?: string;
  user_id?: string;
  route?: string;
  trace_id?: string;
  last_errors?: unknown[];
  device?: Record<string, unknown>;
  notes?: string;
};

serve(async (req) => {
  try {
    const body = (await req.json()) as Req;
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { error } = await supa.from("problem_reports").insert({
      org_id: body.org_id ?? null,
      user_id: body.user_id ?? null,
      route: body.route ?? null,
      trace_id: body.trace_id ?? crypto.randomUUID(),
      last_errors: Array.isArray(body.last_errors) ? body.last_errors : [],
      device: body.device ?? {},
      notes: body.notes ?? null
    });
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
