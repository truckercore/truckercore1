// Supabase Edge Function: region_router (regional proxy)
// Path: supabase/functions/region_router/index.ts
// Invoke with: POST /functions/v1/region_router
// Proxies payloads to in-region endpoints and forwards X-Org-Id and X-Region headers.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Targets supported by the regional router
// Extend as needed to reflect your regional microservices

type Target = "ranker" | "alerts" | "negotiation";

const REGIONAL: Record<string, Record<Target, string | undefined>> = {
  US: {
    ranker: Deno.env.get("US_RANKER_URL") ?? undefined,
    alerts: Deno.env.get("US_ALERTS_URL") ?? undefined,
    negotiation: Deno.env.get("US_NEG_URL") ?? undefined,
  },
  EU: {
    ranker: Deno.env.get("EU_RANKER_URL") ?? undefined,
    alerts: Deno.env.get("EU_ALERTS_URL") ?? undefined,
    negotiation: Deno.env.get("EU_NEG_URL") ?? undefined,
  },
};

interface RouterReq {
  org_id: string;
  processing_region?: "US" | "EU";
  target: Target;
  payload: unknown;
}

serve(async (req) => {
  const t0 = Date.now();
  try {
    if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

    const { org_id, processing_region, target, payload } = (await req.json()) as RouterReq;
    if (!org_id || !target) return new Response("bad_request", { status: 400 });

    const region = (processing_region ?? "US") as keyof typeof REGIONAL;
    const url = REGIONAL[region]?.[target];
    if (!url) {
      try {
        await fetch(new URL("/functions/v1/slo_emit", req.url), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ route: "region_router", latency_ms: Date.now() - t0, ok: false }),
        });
      } catch {}
      return new Response("no_route", { status: 400 });
    }

    // Proxy the request to the regional service.
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Org-Id": org_id,
        "X-Region": String(region),
      },
      body: JSON.stringify(payload ?? {}),
    });

    const contentType = res.headers.get("Content-Type") ?? "application/json";
    const bodyText = await res.text();

    try {
      await fetch(new URL("/functions/v1/slo_emit", req.url), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "region_router", latency_ms: Date.now() - t0, ok: res.ok }),
      });
    } catch {}

    return new Response(bodyText, { status: res.status, headers: { "Content-Type": contentType } });
  } catch (e) {
    try {
      await fetch(new URL("/functions/v1/slo_emit", (req as any).url ?? ""), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ route: "region_router", latency_ms: Date.now() - t0, ok: false }),
      });
    } catch {}
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
