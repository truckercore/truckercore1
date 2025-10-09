// Supabase Edge Function: feedback_submit
// Path: supabase/functions/feedback_submit/index.ts
// POST /functions/v1/feedback_submit
// Collects user feedback about AI recommendations with context for training/QA loops.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Payload = {
  org_id: string;
  user_id?: string | null;
  context_id: string; // e.g., recommendation id or message id
  component?: string | null; // e.g., "ai_matchmaker" or "router"
  rationale?: string | null; // what was shown to the user
  thumbs: "up" | "down";
  comment?: string | null;
  meta?: Record<string, unknown> | null;
};

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  try {
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = (await req.json()) as Payload;
    if (!body?.org_id || !body?.context_id || !body?.thumbs) {
      return new Response("bad_request", { status: 400 });
    }

    // Ensure table exists (documented in schema file); fall back to dynamic creation is out-of-scope.
    const row = {
      org_id: body.org_id,
      user_id: body.user_id ?? null,
      context_id: body.context_id,
      component: body.component ?? null,
      rationale: body.rationale ?? null,
      thumbs: body.thumbs,
      comment: body.comment ?? null,
      meta: body.meta ?? null,
      created_at: new Date().toISOString(),
    } as any;

    const { error } = await supa.from("assistant_feedback").insert(row);
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
