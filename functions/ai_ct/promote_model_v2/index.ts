import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "content-type,x-admin-key,x-idempotency-key",
  "access-control-allow-methods": "POST,OPTIONS"
};
const ok = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "content-type": "application/json" } });

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response("", { headers: CORS });
    if (req.method !== "POST") return ok({ error: "method" }, 405);

    // Governance gate
    if (req.headers.get("x-admin-key") !== Deno.env.get("ADMIN_PROMOTE_KEY")) {
      return ok({ error: "forbidden" }, 403);
    }

    // Idempotency (KV cache; replace with Redis if needed)
    const idemKey = req.headers.get("x-idempotency-key") || "";
    if (idemKey) {
      const hit = await caches.default.match(new Request(`idem:${idemKey}`));
      if (hit) return ok(await hit.json(), 200);
    }

    const payload = await req.json().catch(() => ({}));
    // Tailor these names to your exact JSON contract
    const model_key = payload.model_key;
    const action = payload.action;
    const candidate_version_id = payload.candidate_version_id ?? null;
    const pct = payload.pct ?? null;

    if (!model_key || !action) return ok({ error: "bad-request" }, 422);

    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } }
    );

    const t0 = performance.now();
    const { data, error } = await sb.rpc("ai_promote_tx", {
      p_model_key: model_key,
      p_action: action,
      p_candidate: candidate_version_id,
      p_pct: pct,
      p_actor: "admin-key"
    });

    const body = error
      ? { ok: false, error: error.message }
      : { ok: true, ...data, t_ms: Math.round(performance.now() - t0) };

    // Telemetry for Loki/Grafana
    console.log(JSON.stringify({
      mod: "promoctl",
      action,
      model_key,
      pct,
      ok: !error,
      t_ms: (body as any).t_ms ?? null,
      idem_key: idemKey || null,
      ts: new Date().toISOString()
    }));

    // Cache only successful responses by idempotency key
    if (idemKey && !error) {
      await caches.default.put(
        new Request(`idem:${idemKey}`),
        new Response(JSON.stringify(body), { headers: { "content-type": "application/json" } })
      );
    }

    return ok(body, error ? 409 : 200);
  } catch (e) {
    console.error("promoctl_fatal", e);
    return ok({ error: "internal" }, 500);
  }
});