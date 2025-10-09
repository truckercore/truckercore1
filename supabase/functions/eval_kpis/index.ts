// Supabase Edge Function: eval_kpis
// Evaluates KPI views against thresholds, raises deduped alarms, and auto-recovers the status banner.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Optional: EVAL_SET_BANNER=true|false (default true)

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SET_BANNER = (Deno.env.get("EVAL_SET_BANNER") ?? "true").toLowerCase() !== "false";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

Deno.serve(async () => {
  const t0 = Date.now();
  try {
    // 1) Gather KPI observations
    const { data: lat, error: latErr } = await supabase
      .from("kpi_latency_p95_24h")
      .select("*");
    if (latErr) throw latErr;

    const map: Record<string, number> = {};
    (lat ?? []).forEach((r: any) => {
      // keys must match kpi_thresholds.key, e.g., p95_suggest_ms
      const flow = String(r.flow ?? "");
      if (flow) map[`p95_${flow}_ms`] = Number((r as any).p95_ms ?? 0);
    });

    const { data: conv, error: convErr } = await supabase
      .from("kpi_trial_to_paid_60d")
      .select("*")
      .single();
    if (convErr) throw convErr;
    map["trial_to_paid_pct"] = Number((conv as any)?.pct_trial_to_paid ?? 0);

    const { data: siem, error: siemErr } = await supabase
      .from("kpi_siem_success_24h")
      .select("*")
      .single();
    if (siemErr) throw siemErr;
    map["siem_success_pct"] = Number((siem as any)?.pct_success ?? 0);

    // 2) Evaluate thresholds
    const { data: th, error: thErr } = await supabase
      .from("kpi_thresholds")
      .select("*");
    if (thErr) throw thErr;

    let anyCrit = false;

    for (const t of (th ?? []) as any[]) {
      const key = String(t.key);
      const observed = map[key];
      if (observed == null) continue;

      const higherBetter = !!t.higher_is_better;
      const warn = Number(t.warn);
      const crit = Number(t.crit);

      let level: "none" | "warn" | "crit" = "none";
      if (higherBetter) {
        if (observed < crit) level = "crit";
        else if (observed < warn) level = "warn";
      } else {
        if (observed > crit) level = "crit";
        else if (observed > warn) level = "warn";
      }

      if (level !== "none") {
        // De-dupe identical alarms in the last 10 minutes
        await supabase.rpc("svc_raise_kpi_alarm_once", {
          p_key: key,
          p_observed: observed,
          p_level: level,
          p_dedupe_minutes: 10,
          p_info: { ts: new Date().toISOString() },
        } as any);
        if (level === "crit") anyCrit = true;
      }
    }

    // 3) Banner assist: degrade on CRIT, auto-recover to normal when clear
    if (SET_BANNER) {
      if (anyCrit) {
        await supabase.rpc("set_status_banner", {
          p_mode: "degraded",
          p_message: "Performance degraded. Team notified.",
        } as any);
      } else {
        // Optional auto-recovery to normal if previously degraded/incident
        const { data: current } = await supabase
          .from("status_banner")
          .select("mode")
          .eq("id", 1)
          .maybeSingle();
        const mode = (current as any)?.mode as string | undefined;
        if (mode && mode !== "normal") {
          await supabase.rpc("set_status_banner", {
            p_mode: "normal",
            p_message: null,
          } as any);
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, ms: Date.now() - t0 }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }
});
