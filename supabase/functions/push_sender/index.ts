// Supabase Edge Function: Push Sender (quiet-hours aware, deep-link payloads)
// Path: supabase/functions/push_sender/index.ts
// Invoke with: POST /functions/v1/push_sender
// Input:
//   {
//     user_ids: string[],
//     notification: { title: string, body: string, route: string, params?: object, ttl_sec?: number },
//     respect_quiet_hours?: boolean // default true
//   }
// Output:
//   { ok: boolean, deliver_now: Array<{ user_id, title, body, route, params }>, enqueued: number }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Types

type SendReq = {
  user_ids: string[];
  notification: {
    title: string;
    body: string;
    route: string; // deep link route, e.g., '/compare', '/loads/:id'
    params?: Record<string, unknown>; // deep link params to restore state
    ttl_sec?: number;
  };
  respect_quiet_hours?: boolean;
};

type DeliverNowPayload = { user_id: string; title: string; body: string; route: string; params: any };

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

async function isInQuietHours(userId: string, authHeader: string | null): Promise<boolean> {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false }, global: { headers: { Authorization: authHeader ?? "" } } },
  );
  const { data, error } = await admin.rpc("fn_user_in_quiet_hours", { p_user: userId as any });
  if (error) throw error;
  return !!data;
}

async function nextQuietEnd(userId: string, authHeader: string | null): Promise<string> {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false }, global: { headers: { Authorization: authHeader ?? "" } } },
  );
  const { data, error } = await admin.rpc("fn_next_quiet_end", { p_user: userId as any });
  if (error) throw error;
  return data as string; // ISO string
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const body = (await req.json()) as SendReq;

    if (!body?.user_ids?.length) {
      return new Response(JSON.stringify({ error: "NO_RECIPIENTS" }), { status: 400 });
    }
    if (!body?.notification?.title || !body?.notification?.body || !body?.notification?.route) {
      return new Response(JSON.stringify({ error: "MISSING_FIELDS" }), { status: 400 });
    }

    const respect = body.respect_quiet_hours ?? true;
    const deliver_now: DeliverNowPayload[] = [];
    let enqueued = 0;

    const authHeader = req.headers.get("Authorization");

    if (!respect) {
      for (const user_id of body.user_ids) {
        deliver_now.push({
          user_id,
          title: body.notification.title,
          body: body.notification.body,
          route: body.notification.route,
          params: body.notification.params ?? {},
        });
      }
      return new Response(JSON.stringify({ ok: true, deliver_now, enqueued }), { status: 200 });
    }

    // Respect quiet hours: evaluate per user
    for (const user_id of body.user_ids) {
      const inQuiet = await isInQuietHours(user_id, authHeader);
      if (inQuiet) {
        const send_after = await nextQuietEnd(user_id, authHeader);
        const ins = await SB.from("notifications_digest").insert({
          user_id,
          title: body.notification.title,
          body: body.notification.body,
          route: body.notification.route,
          params: body.notification.params ?? {},
          send_after,
        });
        if (ins.error) throw ins.error;
        enqueued++;
      } else {
        deliver_now.push({
          user_id,
          title: body.notification.title,
          body: body.notification.body,
          route: body.notification.route,
          params: body.notification.params ?? {},
        });
      }
    }

    return new Response(JSON.stringify({ ok: true, deliver_now, enqueued }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
